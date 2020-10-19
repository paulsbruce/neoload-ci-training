def call(Map params) {
  pipeline {
    agent none

    environment {
      docker_label="nljenkinsagent"
      nlw_host="nlweb.shared"
      api_url="http://${env.nlw_host}:8080"

      zone_id = params.get('zone',"${ZONE_ID}")
      full_test_max_vus = params.get('vus',5)
      full_test_duration_mins = params.get('duration',1)
      sanity_scenario_name = params.get('sanity',null)
      load_scenario_name = params.get('scenario',null)
      test_settings_name = params.get('job','example-Jenkins')
      project_yaml_file = params.get('project_yaml',null)
      lg_count = params.get('lgs',1)
      test_dir = params.get('test_dir','.')
    }

    stages {
      stage ('Validate inputs') {
        agent any
        steps {
          sh "printenv"
          script {
            if(env.load_scenario_name == null)
              error "No 'scenario' parameter specified!"
            if(env.lg_count.toInteger() > 2)
              error "You cannot use more than 2 load generators without assistance."
          }
        }
      }
      stage ('Prep workspace') {
        agent any
        steps {
          cleanWs()
          script {
            sh "uname -a"
            env.host_ip = sh(script: "getent hosts ${env.nlw_host} | head -n1 | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])'", returnStdout: true)
            env.agent_name = sh(script: "uname -a | tr -s ' ' | cut -d ' ' -f2", returnStdout: true)
            env.test_settings_name = "${env.agent_name}-${JOB_NAME}"
            if(env.project_yaml_file != null && "${env.project_yaml_file}".trim().length() > 0) {
              print "Adding comma"
              env.project_yaml_file_and_comma = "${env.project_yaml_file},"
              print "${env.project_yaml_file_and_comma}"
            }
          }
        }
      }
      stage ('Check/Build Docker Agent') {
        agent any
        steps {
          script {
            imgCount = sh(script: "docker images -a --filter='label=${env.docker_label}' --format='{{.ID}}' | wc -l", returnStdout: true).toInteger()
            if(imgCount < 1)
              docker.build("${env.docker_label}:latest", "--rm --label '${env.docker_label}' -f ./infra/JenkinsBuildAgent.Dockerfile .")
          }
        }
      }
      stage('Attach Worker') {
        agent {
          docker {
            image "${env.docker_label}:latest"
            args "--add-host ${env.nlw_host}:${env.host_ip} -e HOME=${env.WORKSPACE} -e PYTHONUNBUFFERED=1"
          }
        }
        stages {
          stage('Prepare agent') {
            steps {
              sh 'neoload --version'
              sh 'printenv'
              withCredentials([string(credentialsId: 'NLW_TOKEN', variable: 'NLW_TOKEN')]) {
                sh "neoload login --url ${env.api_url} $NLW_TOKEN"
              }
            }
          }
          stage('Prepare Neoload CLI') {
            steps {
              script {
                def zone_id = env.zone_id
                if(zone_id.trim().toLowerCase().equals("null")) zone_id = ""

                if(zone_id.trim().length() < 1) // dynamically pick a zone
                  zone_id = sh(script: "neoload zones | jq '[.[]|select((.controllers|length>0) and (.loadgenerators|length>0) and (.type==\"STATIC\"))][0] | .id' -r", returnStdout: true).trim()

                if(zone_id == null)
                  error "No zones with available infrastructure were found! Please run 'Start Infra' job."

                sh "neoload test-settings --zone ${zone_id} --lgs ${env.lg_count} --scenario ${env.full_scenario_name} createorpatch '${env.test_settings_name}'"
              }
            }
          }
          stage('Prepare Test Assets') {
            steps {
              writeFile(file: "d.overrides.yaml", text:"""
  scenarios:
  - name: loadTest
    populations:
    - name: popGetsMock
      rampup_load:
        min_users: 1
        max_users: ${env.full_test_max_vus}
        increment_users: 1
        increment_every: 5s
        duration: ${env.full_test_duration_mins}m
              """)
              stash includes: 'd.*.yaml', name: 'dynamics'
            }
          }
          stage('Upload Test Assets') {
            steps {
              dir("${env.test_dir}") {
                unstash 'dynamics'
              }
              sh "neoload project --path ${env.test_dir} upload"
              sh "neoload status"
            }
          }
          stage('Run a sanity scenario') {
            steps {
              script {
                if(env.sanity_scenario_name != null) {
                  sanityCode = 3 // default to something absurd
                  try {
                    wrap([$class: 'BuildUser']) {
                      sanityCode = sh(script: """neoload run \
                            --scenario \"${env.sanity_scenario_name}\" \
                            --name \"sanity-${env.JOB_NAME}-${env.BUILD_NUMBER}-${env.agent_name}\" \
                            --description \"Started by Jenkins user $BUILD_USER on ${env.agent_name}\" \
                            --as-code ${env.project_yaml_file_and_comma}d.overrides.yaml \
                            """, returnStatus: true)
                    }
                  } catch(error) {
                    error "Sanity test kickoff error ${error}"
                  } finally {
                    print "Sanity status code was ${sanityCode}"
                    if(sanityCode > 1)
                      error "Sanity test failed so not proceeding to full test!"
                    else
                      sh "neoload test-results delete cur" // get rid of successful sanity run results
                  }
                } else {
                  print "Skipping sanity scenario"
                }
              }
            }
          }
          stage('Run Test') {
            stages {
              stage('Kick off test async') {
                steps {
                  wrap([$class: 'BuildUser']) {
                    sh """neoload run \
                      --scenario \"${env.load_scenario_name}\" \
                      --name \"fullTest-${env.JOB_NAME}-${env.BUILD_NUMBER}-${env.agent_name}\" \
                      --description \"Started by Jenkins user $BUILD_USER on ${env.agent_name}\" \
                      --detached \
                      --as-code ${env.project_yaml_file_and_comma}d.overrides.yaml
                     """
                  }
                }
              }
              stage('Monitor test') {
                parallel {
                  stage('Monitor SLAs') {
                    steps {
                      script {
                        logs_url = sh(script: "neoload logs-url cur", returnStdout: true).trim()
                        echo "Logs url: ${logs_url}"

                        sh "neoload fastfail --max-failure 25 slas cur"
                      }
                    }
                  }
                  stage('Custom test exit criteria') {
                    steps {
                      script {
                        sleep(time:15,unit:"SECONDS")
                      }
                    }
                  }
                  stage('Wait for test finale') {
                    steps {
                      script {
                        env.exitCode = sh(script: "neoload wait cur", returnStatus: true)
                        print "Final status code was ${env.exitCode}"
                      }
                    }
                  }
                } //end parallel
              }
            } // end stages
            post {
              always {
                sh "neoload test-results junitsla"
                junit testResults: 'junit-sla.xml', allowEmptyResults: true
                archiveArtifacts artifacts: 'd.*.yaml'
              }
            }
          }
        }
      }
    }
  }
}

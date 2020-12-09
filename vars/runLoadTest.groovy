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
      test_settings_name = params.get('job','shared')
      project_yaml_file = params.get('project_yaml',null)
      lg_count = params.get('lgs',1)
      test_dir = params.get('test_dir','.')
      default_scenario_name = 'loadTest'
      reporting_timespan = params.get('reporting_timespan','10%-90%')
    }

    stages {
      stage ('Validate pipline') {
        agent any
        steps {
          cleanWs()
          script {
            if(env.lg_count.toInteger() > 2)
              error "You cannot use more than 2 load generators without assistance."

            sh "uname -a"
            env.host_ip = sh(script: "getent hosts ${env.nlw_host} | head -n1 | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])'", returnStdout: true)
            env.agent_name = "${env.VM_HOST_EXT_IP}" // sh(script: "uname -a | tr -s ' ' | cut -d ' ' -f2", returnStdout: true)
            env.test_settings_name_full = "${env.test_settings_name}-${JOB_NAME}-${env.agent_name}"
            if(!isNullOrEmpty(env.project_yaml_file)) {
              env.project_yaml_file_and_comma = "${env.project_yaml_file},"
            }
            env.actual_scenario_name = env.default_scenario_name
            if(!isNullOrEmpty(env.load_scenario_name)) {
              env.actual_scenario_name = env.load_scenario_name
            }
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
          stage('Prepare Neoload CLI') {
            steps {
              sh 'neoload --version'
              withCredentials([string(credentialsId: 'NLW_TOKEN', variable: 'NLW_TOKEN')]) {
                sh 'neoload login --url $api_url $NLW_TOKEN' // single-quotes to respect proper interpolation
              }
              script {
                def zone_id = env.zone_id
                if(zone_id.trim().toLowerCase().equals("null")) zone_id = ""
                if(zone_id.trim().length() < 1) // dynamically pick a zone
                  zone_id = sh(script: "neoload zones | jq '[.[]|select((.controllers|select(.[].status==\"AVAILABLE\")|length>0) and (.loadgenerators|select(.[].status==\"AVAILABLE\")|length>0) and (.type==\"STATIC\"))][0] | .id' -r", returnStdout: true).trim()

                if(isNullOrEmpty(zone_id))
                  error "No zones with available infrastructure were found! Please run 'Start Infra' job."

                sh "neoload test-settings --zone ${zone_id} --lgs ${env.lg_count} --scenario ${env.full_scenario_name} createorpatch '${env.test_settings_name_full}'"
              }
            }
          }
          stage('Upload Assets to NeoLoad Web') {
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
      stop_after: 30s
sla_profiles:
- name: geo_3rdparty_sla
  description: SLAs for cached queries, error rates
  thresholds:
  - error-rate warn >= 10% fail >= 30% per interval
  - avg-resp-time warn >= 1000ms fail >= 25000ms per interval
  - error-rate fail >= 20% per test
              """)
              stash includes: 'd.*.yaml', name: 'dynamics'

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
                //sh "printenv"
                if(!env.sanity_scenario_name.isEmpty()) {
                  sanityCode = 3 // default to something absurd
                  try {
                    wrap([$class: 'BuildUser']) {
                      sanityCode = sh(script: """neoload run \
                            --scenario \"${env.sanity_scenario_name}\" \
                            --name \"sanity-${env.test_settings_name_full}\" \
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
                  script {
                    wrap([$class: 'BuildUser']) {
                      sh """neoload run \
                        --scenario \"${env.actual_scenario_name}\" \
                        --name \"fullTest-${env.test_settings_name_full}\" \
                        --description \"Started by Jenkins user $BUILD_USER on ${env.agent_name}\" \
                        --detached \
                        --as-code ${env.project_yaml_file_and_comma}d.overrides.yaml
                       """
                    }
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

                        createSummary icon:'graph.png', text: "<a href='$logs_url'>View in NeoLoad Web</a>"

                        sh "neoload fastfail --max-failure 25 slas cur"
                      }
                    }
                  }
                  /*stage('Custom test exit criteria') {
                    steps {
                      script {
                        sleep(time:15,unit:"SECONDS")
                      }
                    }
                  }*/
                  stage('Wait for test finale') {
                    steps {
                      script {
                        try {
                          env.exitCode = sh(script: "neoload wait cur", returnStatus: true)
                          print "Final status code was ${env.exitCode}"
                        } catch(err) {
                          error "Waiting error: ${err}"
                        }
                      }
                      sh "mkdir -p reports"
                      script {
                        sh """neoload report --filter='timespan=${env.reporting_timespan}' \
                              --template builtin:transactions-csv \
                              --out-file reports/neoload-transactions.csv \
                              cur
                         """

                        sh """neoload report --filter='timespan=${env.reporting_timespan}' \
                              --template reporting/jinja/sample-custom-report.html.j2 \
                              --out-file reports/neoload-results.html \
                              cur
                         """
                        publishHTML (target: [
                           allowMissing: false,
                           alwaysLinkToLastBuild: false,
                           keepAll: true,
                           reportDir: 'reports',
                           reportFiles: 'neoload-results.html',
                           reportName: "NeoLoad Test Results"
                        ])

                        sh """neoload report --filter='timespan=${env.reporting_timespan};results=-5' \
                              --template reporting/jinja/sample-trends-report.html.j2 \
                              --out-file reports/neoload-trends.html \
                              --type trends \
                              cur
                         """
                        publishHTML (target: [
                           allowMissing: false,
                           alwaysLinkToLastBuild: false,
                           keepAll: true,
                           reportDir: 'reports',
                           reportFiles: 'neoload-trends.html',
                           reportName: "NeoLoad Trends (Custom)"
                         ])
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
                archiveArtifacts artifacts: 'reports/*.*'
              }
            }
          }
        }
      }
    }
  }
}

def isNullOrEmpty(val) {
  return ("null".equals(val) || !val?.trim())
}

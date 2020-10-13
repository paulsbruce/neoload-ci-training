pipeline {
  agent none

  environment {
    CLI_BRANCH="topic-docker-command"
    zone_id="defaultzone"
    nlw_host="nlweb.shared"
    api_url="http://${env.nlw_host}:8080"
  }

  stages {
    stage ('Prep workspace') {
      agent any
      steps {
        cleanWs()
        script {
          try { sh "docker rmi \$(docker images -a --filter=\"label=${env.CLI_BRANCH}\" --format=\"{{.ID}}\") --force" }
          catch(error) {}
          sh "uname -a"
          env.host_ip = sh(script: "getent hosts ${env.nlw_host} | head -n1 | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])'", returnStdout: true)
        }
      }
    }
    stage('Attach Worker') {
      agent {
        dockerfile {
          filename 'JenkinsBuildAgent.Dockerfile'
          dir 'modules/module1'
          additionalBuildArgs "--rm --label \"${env.CLI_BRANCH}\""
          args "--add-host ${env.nlw_host}:${env.host_ip}"
        }
      }
      stages {
        stage('Prepare docker') {
          steps {
            sh 'neoload --version'
          }
        }
        stage('Prepare Neoload test') {
          steps {
            withEnv(["HOME=${env.WORKSPACE}"]) {
              withCredentials([string(credentialsId: 'NLW_TOKEN', variable: 'NLW_TOKEN')]) {
                sh "neoload login --url ${env.api_url} $NLW_TOKEN"
                sh "neoload test-settings --zone ${env.zone_id} --lgs 2 --scenario sanityScenario createorpatch 'infra-harness'"
                sh "neoload docker attach --addhosts='nlweb.shared=${env.host_ip}'"
                sh "neoload status"
              }
            }
          }
        }
      }
    }
  }
}

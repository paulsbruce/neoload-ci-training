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
          sh "uname -a"
          env.host_ip = sh(script: "getent hosts ${env.nlw_host} | head -n1 | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])'", returnStdout: true)
        }
      }
    }
    stage('Attach Worker') {
      agent {
        dockerfile {
          filename 'JenkinsBuildAgent.Dockerfile'
          dir 'infra'
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
                sh "neoload status"
                sh "neoload docker detach"
                sh "neoload status"
              }
            }
          }
        }
      }
    }
  }
}

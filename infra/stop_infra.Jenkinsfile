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
          env.host_ip = sh(script: "getent hosts ${env.nlw_host} | head -n1 | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])'", returnStdout: true).trim()
        }
      }
    }
    stage('Attach Worker') {
      agent {
        dockerfile {
          filename 'JenkinsBuildAgent-docker.Dockerfile'
          dir 'infra'
          additionalBuildArgs "--rm --label \"${env.CLI_BRANCH}\""
          args "-u root --privileged -v /var/run/docker.sock:/var/run/docker.sock --add-host ${env.nlw_host}:${env.host_ip} -e HOME=${env.WORKSPACE}"
        }
      }
      stages {
        stage('NeoLoad login') {
          steps {
            sh 'neoload --version'
            withCredentials([string(credentialsId: 'NLW_TOKEN', variable: 'NLW_TOKEN')]) {
              sh "neoload login --url ${env.api_url} $NLW_TOKEN"
            }
          }
        }
        stage('Stop docker load infra') {
          steps {
            sh "neoload test-settings --zone ${env.zone_id} --lgs 2 --scenario sanityScenario createoruse 'infra-harness'"
            sh "neoload docker --all detach"
          }
        }
      }
    }
  }
}

pipeline {
  agent none

  environment {
    docker_label="nlclidocker"
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
          try { sh "docker rmi \$(docker images -a --filter=\"label=${env.docker_label}\" --format=\"{{.ID}}\") --force" }
          catch(error) {}
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
          additionalBuildArgs "--rm --label \"${env.docker_label}\""
          args "-u root --privileged -v /var/run/docker.sock:/var/run/docker.sock --add-host ${env.nlw_host}:${env.host_ip} -e HOME=${env.WORKSPACE}"
        }
      }
      stages {
        stage('Prepare docker') {
          steps {
            withCredentials([string(credentialsId: 'NLW_TOKEN', variable: 'NLW_TOKEN')]) {
              sh "neoload login --url ${env.api_url} $NLW_TOKEN"
              sh 'neoload --version'
            }
          }
        }
        stage('Prepare Neoload test') {
          steps {
            sh "neoload test-settings --zone ${env.zone_id} --lgs 2 --scenario sanityScenario createoruse 'infra-harness'"
            sh "neoload docker --addhosts='nlweb.shared=${env.host_ip}' attach"
            sh "neoload status"
          }
        }
      }
    }
  }
}

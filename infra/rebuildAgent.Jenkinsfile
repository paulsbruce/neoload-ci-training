pipeline {
  agent none

  environment {
    docker_label="nljenkinsagent"
  }

  stages {
    stage ('Prep workspace') {
      agent any
      steps {
        cleanWs()
        script {
          sh "uname -a"
          env.agent_geo = "Unknown"
          try {
            env.agent_ip = sh(script: "curl -s -L --insecure https://ipinfo.io/ip", returnStdout: true).trim()
            env.agent_geo = sh(script: "curl -s -L --insecure https://freegeoip.app/json/${env.agent_ip} | jq -r '.time_zone'", returnStdout: true).trim()
          }
          catch(e) {
            sh "echo Geo-lookup error:"
            sh "echo ${e}"
          }
        }
      }
    }
    stage ('Rebuild Docker Agent') {
      agent any
      steps {
        script {
          imgCount = sh(script: "docker images -a --filter='label=${env.docker_label}' --format='{{.ID}}' | wc -l", returnStdout: true).toInteger()
          if(imgCount > 0)
            sh "docker rmi ${env.docker_label}"
          sh "export AGENT_GEO=${env.agent_geo}"
          docker.build("${env.docker_label}:latest", "--no-cache --rm --label '${env.docker_label}' --build-arg AGENT_GEO=$AGENT_GEO -f ./infra/JenkinsBuildAgent.Dockerfile .")
        }
      }
    }
  }
}

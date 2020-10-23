#!/bin/sh
set -e
set +x

source "`dirname $0`"/common.sh

echo "NeoLoad Web Host IP: $NLW_HOST_IP"
#echo "This host IP: $INT_HOST_IP"

docker ps -a -q --filter "label=jenkins" | grep -q . && \
  docker stop $(docker ps -a -q --filter "label=jenkins" --format '{{.ID}}') > /dev/null 2>&1
docker ps -a -q --filter "label=jenkins" | grep -q . && \
  docker rm $(docker ps -a -q --filter "label=jenkins" --format '{{.ID}}') > /dev/null 2>&1
sleep 5

if [ "${RESET}" != "" ]; then
  read -p "Are you sure you want to reset your local jenkins examples? <y/N> " prompt
  if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]
  then
    echo 'Removing prior persistent jenkins-related volumes'
    docker network ls -q --filter "name=jenkins" | grep -q . && docker network rm jenkins
    docker volume ls -q --filter 'label=jenkins' | grep -q . && docker volume rm $(docker volume ls -q --filter 'label=jenkins' --format '{{.Name}}')
    if [ "${RESET}" == "hard-reset" ]; then
      read -p "Are you really sure you also want to reset your local docker-in-docker images volume? <y/N> " prompt
      if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]
      then
        docker volume ls -q --filter 'label=dind' | grep -q . && docker volume rm $(docker volume ls -q --filter 'label=dind' --format '{{.Name}}')
      fi
    fi
    echo 'Continuing with normal jenkins stand-up process'
  else
    exit 0
  fi
fi

if [ -z "$(docker network ls -q --filter 'name=jenkins')" ]; then
  docker network create jenkins
fi

if [ -z "$(docker volume ls -q --filter 'name=jenkins-docker-certs')" ]; then
  docker volume create --label "jenkins" jenkins-docker-certs
fi

if [ -z "$(docker volume ls -q --filter 'name=jenkins-data')" ]; then
  docker volume create --label "jenkins" jenkins-data
fi

if [ -z "$(docker volume ls -q --filter 'name=dind-volumes')" ]; then
  docker volume create --label "dind=yes" dind-volumes
fi
if [ -z "$(docker volume ls -q --filter 'name=dind-overlay2')" ]; then
  docker volume create --label "dind=yes" dind-overlay2
fi
if [ -z "$(docker volume ls -q --filter 'name=dind-image')" ]; then
  docker volume create --label "dind=yes" dind-image
fi
if [ -z "$(docker volume ls -q --filter 'name=dind-containers')" ]; then
  docker volume create --label "dind=yes" dind-containers
fi

if [ "$USE_DIND" == "true" ]; then
  echo "Using Docker-in-Docker"
  docker container run \
    --name jenkins-docker \
    --label 'jenkins' \
    --rm \
    --detach \
    --privileged \
    --network jenkins \
    --network-alias docker \
    --env DOCKER_TLS_CERTDIR=/certs \
    --volume jenkins-docker-certs:/certs/client \
    --volume jenkins-data:/var/jenkins_home \
    --volume dind-volumes:/var/lib/docker/volumes \
    --volume dind-overlay2:/var/lib/docker/overlay2 \
    --volume dind-image:/var/lib/docker/image \
    --volume dind-containers:/var/lib/docker/containers \
    --publish 2376:2376 \
    docker:dind

  docker container run \
    --name jenkins-blueocean \
    --label 'jenkins' \
    --rm \
    --detach \
    --network jenkins \
    --env DOCKER_HOST=$DOCKER_TCP_URI \
    --env DOCKER_CERT_PATH=/certs/client \
    --env DOCKER_TLS_VERIFY=1 \
    --env JAVA_OPTS="-Djava.awt.headless=true -Dhudson.model.DirectoryBrowserSupport.CSP=\"default-src 'self' 'unsafe-inline' 'unsafe-eval'; img-src 'self' 'unsafe-inline' data:;\"" \
    --publish $JENKINS_HTTP_PORT:8080 \
    --publish 50000:50000 \
    --volume jenkins-data:/var/jenkins_home \
    --volume jenkins-docker-certs:/certs/client:ro \
    --add-host nlweb.shared:$NLW_HOST_IP \
    jenkinsci/blueocean
else
  echo "Using Docker at Host"
  docker container run \
    --name jenkins-docker \
    --label 'jenkins' \
    --rm \
    --detach \
    --network jenkins \
    -p 23750:2375 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    alpine/socat tcp-listen:2375,fork,reuseaddr unix-connect:/var/run/docker.sock

  docker container run \
    --name jenkins-blueocean \
    --label 'jenkins' \
    --rm \
    --detach \
    --network jenkins \
    --env DOCKER_HOST=tcp://jenkins-docker:23750 \
    --env DOCKER_CERT_PATH=/certs/client \
    --env DOCKER_TLS_VERIFY=1 \
    --env JAVA_OPTS="-Djava.awt.headless=true -Dhudson.model.DirectoryBrowserSupport.CSP=\"default-src 'self' 'unsafe-inline' 'unsafe-eval'; img-src 'self' 'unsafe-inline' data:;\"" \
    --publish $JENKINS_HTTP_PORT:8080 \
    --publish 50000:50000 \
    --volume jenkins-data:/var/jenkins_home \
    --volume jenkins-docker-certs:/certs/client:ro \
    --add-host nlweb.shared:$NLW_HOST_IP \
    jenkinsci/blueocean
fi
#System.setProperty("hudson.model.DirectoryBrowserSupport.CSP", "")

docker exec -it --user root jenkins-blueocean apk add -q --no-progress --upgrade bind-tools


source "`dirname $0`"/wait_for_jenkins_up.sh
source "`dirname $0`"/start_after.sh

CURL_CONTENTS=$(curl -s -L $LOGIN_URL)
if [[ "$CURL_CONTENTS" == *"initialAdminPassword"* ]];then
  JENKINS_SECRET=$(docker exec -it --user root jenkins-blueocean cat /var/jenkins_home/secrets/initialAdminPassword)
  echo "Please use your Jenkins initial admin password: $JENKINS_SECRET"
else
  echo "Jenkins is already initialized and ready to use."
  echo "Press any key to close this window."
  read -t 15 -n 1
fi

if [ -t 0 ]; then
  open $EXT_JENKINS_URL
fi

docker exec -it --user root jenkins-docker docker pull neotys/neoload-controller:latest
docker exec -it --user root jenkins-docker docker pull neotys/neoload-loadgenerator:latest
#wait

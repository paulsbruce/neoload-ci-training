#!/bin/bash
set -e
set +x

#echo "start got:"
#echo "JENKINS_HTTP_PORT=$JENKINS_HTTP_PORT"
#echo "NLW_HOST=$NLW_HOST"
#echo "git_repo_url=$git_repo_url"
#echo "git_branch=$git_branch"

# use a Neotys public ECR because dockerhub rate-limits suck
# BE SPECIFIC ABOUT VERSION TAGS!!!
DOCKERREPO_ROOT=public.ecr.aws/neotys
DOCKERIMAGE_DIND=$DOCKERREPO_ROOT/docker:dind
DOCKERIMAGE_BLUEOCEAN=$DOCKERREPO_ROOT/blueocean:1.24.4
DOCKERIMAGE_GITBUCKET=$DOCKERREPO_ROOT/gitbucket:4.35.3
DOCKERIMAGE_CONTROLLER=$DOCKERREPO_ROOT/neoload-controller:7.7.0
DOCKERIMAGE_LOADGENERATOR=$DOCKERREPO_ROOT/neoload-loadgenerator:7.7.0

if [ -z "$JENKINS_HTTP_PORT" ]; then
  . "`dirname $0`"/../globals.sh
fi

echo "common using JENKINS_HTTP_PORT=$JENKINS_HTTP_PORT NLW_HOST=$NLW_HOST"

. "`dirname $0`"/common.sh
. "`dirname $0`"/common.sh

echo "NeoLoad Web Host IP: $NLW_HOST_IP"

docker ps -a -q --filter "label=jenkins" | grep -q . && \
  docker stop $(docker ps -a -q --filter "label=jenkins" --format '{{.ID}}') > /dev/null 2>&1
docker ps -a -q --filter "label=jenkins" | grep -q . && \
  docker rm $(docker ps -a -q --filter "label=jenkins" --format '{{.ID}}') > /dev/null 2>&1
wait

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

if [ -z "$(docker volume ls -q --filter 'name=jenkins-home')" ]; then
  docker volume create --label "jenkins" jenkins-home
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

VM_HOST_INT_IP=$(ifconfig eth0 | grep "inet " | awk '{print $2}')
if [ -z "$VM_HOST_INT_IP" ]; then
  VM_HOST_INT_IP=$(ifconfig wlp3s0 | grep "inet " | awk '{print $2}')
fi
echo "VM_HOST_INT_IP: $VM_HOST_INT_IP"

VM_HOST_EXT_IP=$(curl -sS ifconfig.me)
echo "VM_HOST_EXT_IP: $VM_HOST_EXT_IP"

echo "Starting Docker-in-Docker container"
docker pull -q $DOCKERIMAGE_DIND
docker tag $DOCKERIMAGE_DIND docker:dind
docker container run \
  --name jenkins-docker \
  --label 'jenkins' \
  --rm \
  --detach \
  --privileged \
  --network jenkins \
  --network-alias docker \
  --env VM_HOST_INT_IP=$VM_HOST_INT_IP \
  --env VM_HOST_EXT_IP=$VM_HOST_EXT_IP \
  --env DOCKER_TLS_CERTDIR=/certs \
  --volume jenkins-docker-certs:/certs/client \
  --volume jenkins-home:/var/jenkins_home \
  --volume dind-volumes:/var/lib/docker/volumes \
  --volume dind-overlay2:/var/lib/docker/overlay2 \
  --volume dind-image:/var/lib/docker/image \
  --volume dind-containers:/var/lib/docker/containers \
  --publish 2376:2376 \
  --publish 7100-7110:7100-7110 \
  --add-host gitbucket:$VM_HOST_INT_IP \
  docker:dind \
  1>/dev/null

function run_jenkins_container() {
  echo "Starting jenkins container"
  additional_java_opts=$(echo "$1")
  docker container run \
    --name jenkins-blueocean \
    --label 'jenkins' \
    --rm \
    --detach \
    --network jenkins \
    --env VM_HOST_INT_IP=$VM_HOST_INT_IP \
    --env VM_HOST_EXT_IP=$VM_HOST_EXT_IP \
    --env DOCKER_HOST=$DOCKER_TCP_URI \
    --env DOCKER_CERT_PATH=/certs/client \
    --env DOCKER_TLS_VERIFY=1 \
    --env JAVA_OPTS="$additional_java_opts -Djava.awt.headless=true" \
    --publish $JENKINS_HTTP_PORT:8080 \
    --publish 50000:50000 \
    --volume jenkins-home:/var/jenkins_home \
    --volume jenkins-docker-certs:/certs/client:ro \
    --add-host nlweb.shared:$NLW_HOST_IP \
    --add-host gitbucket:$VM_HOST_INT_IP \
    jenkinsci/blueocean:latest \
    1>/dev/null
  # -Dhudson.model.DirectoryBrowserSupport.CSP=\"\"" \
}

docker pull -q $DOCKERIMAGE_BLUEOCEAN
docker tag $DOCKERIMAGE_BLUEOCEAN jenkinsci/blueocean:latest
run_jenkins_container ""

source "`dirname $0`"/wait_for_jenkins_up.sh
docker exec -i jenkins-blueocean bash -c "sed -i 's/<useSecurity>true<\/useSecurity>/<useSecurity>false<\/useSecurity>/g' /var/jenkins_home/config.xml"
docker exec -i jenkins-blueocean cat /var/jenkins_home/config.xml

docker exec -it --user root jenkins-blueocean apk add -q --no-progress --upgrade bind-tools curl &>/dev/null

source "`dirname $0`"/wait_for_jenkins_up.sh
source "`dirname $0`"/print_jenkins_password.sh
source "`dirname $0`"/start_after.sh

docker stop jenkins-blueocean 1>/dev/null
run_jenkins_container "-Djenkins.install.runSetupWizard=false -Djenkins.security.ApiTokenProperty.adminCanGenerateNewTokens=true -Dhudson.model.UpdateCenter.never=true -Djenkins.ui.refresh=true"

source "`dirname $0`"/wait_for_jenkins_up.sh
source "`dirname $0`"/print_jenkins_password.sh


# if [ -t 0 ]; then
#   if [ "$(which open)" ]; then
#     open $EXT_JENKINS_URL
#   elif [ "$(which xdg-open)" ]; then
#     xdg-open $EXT_JENKINS_URL
#   fi
# fi

echo "Pre-loading the latest load generator and controller Docker images"
docker exec -it --user root jenkins-docker docker pull $DOCKERIMAGE_CONTROLLER
docker exec -it --user root jenkins-docker docker tag $DOCKERIMAGE_CONTROLLER neotys/neoload-controller:latest
docker exec -it --user root jenkins-docker docker pull $DOCKERIMAGE_LOADGENERATOR
docker exec -it --user root jenkins-docker docker tag $DOCKERIMAGE_LOADGENERATOR neotys/neoload-loadgenerator:latest

docker exec -it --user root jenkins-docker docker pull $DOCKERIMAGE_GITBUCKET
docker exec -it --user root jenkins-docker docker tag $DOCKERIMAGE_GITBUCKET gitbucket/gitbucket:latest
#wait

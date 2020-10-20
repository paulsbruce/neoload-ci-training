docker ps -q --filter "name=jenkins-docker" | grep -q . && docker stop jenkins-docker && docker rm jenkins-docker
docker ps -q --filter "name=jenkins-blueocean" | grep -q . && docker stop jenkins-blueocean && docker rm jenkins-blueocean
sleep 5

NLW_HOST=nlweb.shared
NLW_HOST_IP=$(host $NLW_HOST | head -n1 | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])')
echo $NLW_HOST_IP

INT_HOST_IP=$(ifconfig | grep '10.0.' | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])' | head -n1)
echo $INT_HOST_IP

docker container run \
  --name jenkins-docker \
  --rm \
  --detach \
  --privileged \
  --network jenkins \
  --network-alias docker \
  --env DOCKER_TLS_CERTDIR=/certs \
  --volume jenkins-docker-certs:/certs/client \
  --volume jenkins-data:/var/jenkins_home \
  --publish 2376:2376 \
  docker:dind

docker container run \
  --name jenkins-blueocean \
  --rm \
  --detach \
  --network jenkins \
  --env DOCKER_HOST=tcp://docker:2376 \
  --env DOCKER_CERT_PATH=/certs/client \
  --env DOCKER_TLS_VERIFY=1 \
  --env JAVA_OPTS="-Dhudson.model.DirectoryBrowserSupport.CSP=\"sandbox allow-scripts\; default-src 'self'\; style-src 'self' 'unsafe-inline'\;\"" \
  --publish 8080:8080 \
  --publish 50000:50000 \
  --volume jenkins-data:/var/jenkins_home \
  --volume jenkins-docker-certs:/certs/client:ro \
  --add-host nlweb.shared:$NLW_HOST_IP \
  --add-host gitbucket:$INT_HOST_IP \
  jenkinsci/blueocean

docker exec -it --user root jenkins-blueocean apk add -q --no-progress --upgrade bind-tools

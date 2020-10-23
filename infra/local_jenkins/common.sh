#!/bin/sh
set -e
if [ "$1" == "debug" ]; then
  $("set -x")
fi
RESET=
if [ "$1" == "reset" ]; then
  RESET=reset
fi
if [ "$1" == "hard-reset" ]; then
  RESET=hard-reset
fi

if [ -z "$(which docker)" ]; then
  echo "Docker tools are not installed!!!"
  exit 1
fi

NLW_TOKEN=$(cat "`dirname $0`"/nlw_token| tr -d '\r' | tr -d '\n' | tr -d ' ')

JENKINS_HTTP_PORT=80

NLW_HOST=nlweb.shared
NLW_HOST_IP=$(ping -c 1 -t 1 $NLW_HOST | head -n1 | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])')

if [ -z "$NLW_HOST_IP" ]; then
  echo "Could not find the IP address for a server/hostname called $NLW_HOST"
  exit 2
fi

EXT_JENKINS_URL=http://localhost:$JENKINS_HTTP_PORT
INT_JENKINS_URL=http://localhost:8080 # this is always the case from inside blueocean container
STATIC_JENKINS_URL=http://127.0.0.1

DOCKER_TCP_URI=tcp://docker:2376
USE_DIND=true
# if [ -z "$(which socat)" ]; then
#   echo "Attempting to socat for host docker tcp"
#   if [ "$(which brew)" ]; then
#     brew install socat
#   elif [ "$(which apt-get)" ]; then
#     apt-get install socat
#   elif [ "$(which apt-get)" ]; then
#     apk add socat
#   fi
# fi
# if [ "$(which socat)" ]; then
#   if [ -z "$(lsof -i :2375 | grep LISTEN)" ]; then
#     socat TCP-LISTEN:2375,reuseaddr,fork UNIX-CONNECT:/var/run/docker.sock &
#     sleep 5
#   fi
# fi
# if [ "$(lsof -i :2375 | grep LISTEN)" ]; then
#   DOCKER_TCP_URI=tcp://host.docker.internal:2375
#   USE_DIND=false
# else
#   echo "Please expose Docker on this host over TCP if you don't want to use Docker-in-Docker (caching images, etc.)"
#   echo "If you are using Docker Desktop, you should add a hosts value of 'tcp://0.0.0.0:2375'"
# fi

echo "$NLW_HOST => $NLW_HOST_IP"
echo "DOCKER_TCP_URI => $DOCKER_TCP_URI"

if [ "$1" == "debug" ]; then
  echo "In debug mode"
fi

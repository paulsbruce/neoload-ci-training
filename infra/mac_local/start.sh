#!/bin/sh
set -e

repo="$(pwd)/infra/local_jenkins/start.sh"
if [ ! -f "$repo" ]; then
  echo "You should run this at the root of the training repo."
  exit 1
fi
HOME_DIR=$(pwd)

git_branch=$(git branch | awk '/\*/ { print $2; }')
export git_branch=$git_branch

. "`dirname $0`"/../globals.sh

if [ ! "$(which git)" ]; then
  echo "You need to have git installed locally."
  exit 1
fi

JENKINS_HTTP_PORT=80
NLW_HOST=nlweb.shared
NLW_HOST_API_BASE=http://$NLW_HOST:8080

NLW_HOST_IP=$(ping -c1 -t1 -W1 $NLW_HOST 2>/dev/null | head -n1 | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])')
if [ -z "$NLW_HOST_IP" ]; then
  echo "Cannot resolve the IP address for $NLW_HOST. As an instructor, please add the training shared server first in your local etc/hosts file."
  exit 3
else
  sleep 3
fi

export JENKINS_HTTP_PORT=$JENKINS_HTTP_PORT
export NLW_HOST=$NLW_HOST
export NLW_HOST_IP=$NLW_HOST_IP
# every time this VM is booted, run the initial Jenkins setup (persists data between sessions)

infra/local_jenkins/start.sh ${@:1}

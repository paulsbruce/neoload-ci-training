#!/bin/bash
set -e

DOCKER_HOST_NAME=host.docker.internal
if ! ping -c1 -t1 -W1 $DOCKER_HOST_NAME &>/dev/null ; then
  echo "Writing explicit host.docker.internal to /etc/hosts"
  echo -e "`/sbin/ip route|awk '/default/ { print $3 }'`\thost.docker.internal" | tee -a /etc/hosts
  sleep 3
fi

if ! ping -c1 -t1 -W1 $DOCKER_HOST_NAME &>/dev/null ; then
  echo "Could not resolve host.docker.internal from inside the Docker host"
  exit 1
fi

echo 'Adding gitbucket to hosts'
if ! ping -c1 -t1 -W1 gitbucket &>/dev/null ; then
  echo "Writing gitbucket to /etc/hosts"
  GITBUCKET_IP=$(ping -c 1 -t 1 host.docker.internal | head -n1 | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])')
  echo -e "$GITBUCKET_IP\tgitbucket" | tee -a /etc/hosts
fi

#echo "Contents of /etc/hosts"
#cat /etc/hosts

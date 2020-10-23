#!/bin/sh
set -e

source "`dirname $0`"/common.sh

echo "Waiting a bit for Jenkins to start up..."
NUM_OF_TRIES=0
MAX_TRIES=5
LOGIN_URL=$EXT_JENKINS_URL/login?from=%2F
while [ $NUM_OF_TRIES -le $MAX_TRIES ]; do
  echo "Waiting for Jenkins to start up..."
  CURL_CONTENTS=$(curl -s -L $LOGIN_URL || true)
  #echo $CURL_CONTENTS
  if [[ $CURL_CONTENTS == *"Starting"* ]];then
    echo "Jenkins is starting up..."
  elif [[ $CURL_CONTENTS == *"Sign in"* ]];then
    echo "Please use default credentials admin:password (or token) to log in to Jenkins"
    break
  elif [[ $CURL_CONTENTS == *"initialAdminPassword"* ]];then
    echo "Found a need for the initial admin password"
    break
  else
    if [ $NUM_OF_TRIES -eq $MAX_TRIES ]; then
      echo "Failed to connect to Jenkins after $NUM_OF_TRIES of tries"
      exit 4
    fi
  fi

  NUM_OF_TRIES=`expr $NUM_OF_TRIES + 1`
  sleep 5
done

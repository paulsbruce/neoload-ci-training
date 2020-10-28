#!/bin/bash
set -e

source "`dirname $0`"/common.sh

echo "Waiting a bit for Jenkins to start up..."
NUM_OF_TRIES=0
MAX_TRIES=24 # x5 = 2m
LOGIN_URL=$EXT_JENKINS_URL/login?from=%2F
AFTER_MSG="Jenkins has started"
while [ $NUM_OF_TRIES -le $MAX_TRIES ]; do
  echo "Waiting for Jenkins to start up..."
  CURL_CONTENTS=$(curl -s -L $LOGIN_URL || true)
  #echo $CURL_CONTENTS
  if [[ $CURL_CONTENTS == *"Starting"* ]];then
    echo "Jenkins is starting up..."
  elif [[ $CURL_CONTENTS == *"Sign in"* ]];then
    AFTER_MSG="Please use default credentials admin:password (or token) to log in to Jenkins"
    break
  elif [[ $CURL_CONTENTS == *"initialAdminPassword"* ]];then
    AFTER_MSG="Found a need for the initial admin password"
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

source "`dirname $0`"/require_jenkins_secret.sh
echo "JENKINS_SECRET: $JENKINS_SECRET"
echo $AFTER_MSG

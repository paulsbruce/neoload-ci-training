#!/bin/bash
set -e

source "`dirname $0`"/common.sh

printf "Waiting a bit for Jenkins to start up..."
NUM_OF_TRIES=0
MAX_TRIES=24 # x5 = 2m
LOGIN_URL=$EXT_JENKINS_URL/login?from=%2F
JENKINS_AFTER_MSG="Jenkins has started"
while [ $NUM_OF_TRIES -le $MAX_TRIES ]; do
  printf "."
  CURL_CONTENTS=$(curl -s -L $LOGIN_URL || true)
  #echo $CURL_CONTENTS
  if [[ $CURL_CONTENTS == *"Starting"* ]];then
    printf "."
  elif [[ $CURL_CONTENTS == *"Sign in"* ]];then
    JENKINS_AFTER_MSG="Please use default credentials admin:password (or token above) to log in to Jenkins"
    break
  elif [[ $CURL_CONTENTS == *"initialAdminPassword"* ]];then
    JENKINS_AFTER_MSG="Found a need for the initial admin password"
    break
  else
    if [ $NUM_OF_TRIES -eq $MAX_TRIES ]; then
      printf "\nFailed to connect to Jenkins after $NUM_OF_TRIES of tries\n"
      exit 4
    fi
  fi

  NUM_OF_TRIES=`expr $NUM_OF_TRIES + 1`
  sleep 5
done
printf "\n"

source "`dirname $0`"/require_jenkins_secret.sh
export JENKINS_SECRET=$JENKINS_SECRET
export JENKINS_AFTER_MSG=$JENKINS_AFTER_MSG

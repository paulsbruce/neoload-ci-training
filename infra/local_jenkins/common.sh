#!/bin/bash
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
if [ -z "$(which curl)" ]; then
  echo "Curl is not installed!!!"
  exit 1
fi

token_file="`dirname $0`"/nlw_token
if [ ! -f "$token_file" ]; then
  token_file=~/nlw_token
fi
if [ -f "$token_file" ]; then
  NLW_TOKEN=$(cat $token_file | tr -d '\r' | tr -d '\n' | tr -d ' ')
fi

mask() {
        local n=$2                   # number of chars to leave
        local a="${1:0:${#1}-n}"     # take all but the last n chars
        local b="${1:${#1}-n}"       # take the final n chars
        printf "%s%s\n" "${a//?/*}" "$b"   # substitute a with asterisks
}

if [ -z "$NLW_TOKEN" ]; then
  echo "No NLW_TOKEN found! Please either set this variable first, or provide a file ~/nlw_token"
  exit 1
else
  masked=$(mask "$NLW_TOKEN" 5)
  echo "NLW_TOKEN: $masked"
fi

JENKINS_HTTP_PORT=80

NLW_HOST=nlweb.shared
NLW_HOST_API_BASE=http://$NLW_HOST:8080
NLW_HOST_IP=$(ping -c 1 -t 1 $NLW_HOST | head -n1 | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])')

if [ -z "$NLW_HOST_IP" ]; then
  echo "Could not find the IP address for a server/hostname called $NLW_HOST"
  exit 2
fi

NLW_INFO=$(curl -s -L GET "$NLW_HOST_API_BASE/v2/information" -H "accept: application/json" -H "accountToken: $NLW_TOKEN")
echo $NLW_INFO
if [[ "$NLW_INFO" == *"front_url"* ]];then
  echo "NLW_TOKEN WORKED!"
else
  echo "NLW_TOKEN FAILED TO INTERACT WITH $NLW_HOST_API_BASE !"
  exit 3
fi

EXT_JENKINS_URL=http://localhost:$JENKINS_HTTP_PORT
INT_JENKINS_URL=http://localhost:8080 # this is always the case from inside blueocean container
STATIC_JENKINS_URL=http://127.0.0.1/
DOCKER_TCP_URI=tcp://docker:2376

echo "$NLW_HOST => $NLW_HOST_IP"
echo "DOCKER_TCP_URI => $DOCKER_TCP_URI"

if [ "$1" == "debug" ]; then
  echo "In debug mode"
fi

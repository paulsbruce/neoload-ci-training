#!/bin/bash
set -e

should_echo_infos=0
if [ "$has_common_been_run" == "" ]; then
  should_echo_infos=1
fi

if [ -z "$has_common_been_run" ]; then
  has_common_been_run=1
  export has_common_been_run=$has_common_been_run
fi

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
  eval homedir=~
  token_file=$homedir/nlw_token
fi
if [ -f "$token_file" ]; then
  if [ "$should_echo_infos" == "1" ]; then
    echo "Found a token in the file $token_file"
  fi
  NLW_TOKEN=$(cat $token_file | tr -d '\r' | tr -d '\n' | tr -d ' ')
fi

dt_config="`dirname $0`"/dt_config
if [ ! -f "$dt_config" ]; then
  eval homedir=~
  dt_config=$homedir/dt_config
fi
if [ -f "$dt_config" ]; then
  if [ "$should_echo_infos" == "1" ]; then
    echo "Found Dynatrace config"
  fi
  DYNATRACE_URL=$(cat $dt_config | head -1 | tr -d '\r' | tr -d '\n' | tr -d ' ')
  DYNATRACE_API_TOKEN=$(cat $dt_config | sed 1,1d | head -1 | tr -d '\r' | tr -d '\n' | tr -d ' ')
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
  if [ "$should_echo_infos" == "1" ]; then
    masked=$(mask "$NLW_TOKEN" 5)
    echo "NLW_TOKEN: $masked"
  fi
fi

NLW_HOST=nlweb.shared
NLW_HOST_API_BASE=http://$NLW_HOST:8080
NLW_HOST_IP=$(ping -c1 -t1 -W1 $NLW_HOST 2>/dev/null | head -n1 | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])')

if [ -z "$NLW_HOST_IP" ]; then
  echo "Could not find the IP address for a server/hostname called $NLW_HOST"
  exit 2
fi

NLW_INFO=$(curl -s -L "$NLW_HOST_API_BASE/v2/resources/zones" -H "accept: application/json" -H "accountToken: $NLW_TOKEN")
if [[ "$NLW_INFO" == *"defaultzone"* ]];then
  if [ "$should_echo_infos" == "1" ]; then
    NLW_INFO=$NLW_INFO
    #echo "NLW_TOKEN WORKED!"
  fi
else
  echo "NLW_TOKEN FAILED TO INTERACT WITH $NLW_HOST_API_BASE !"
  exit 3
fi

LOCAL_HOST_NAME=$(uname -n)
EXT_JENKINS_URL=http://$LOCAL_HOST_NAME:$JENKINS_HTTP_PORT
INT_JENKINS_URL=http://localhost:8080 # this is always the case from inside blueocean container
STATIC_JENKINS_URL=http://127.0.0.1/
DOCKER_TCP_URI=tcp://docker:2376

if [ "$should_echo_infos" == "1" ]; then
  echo "$NLW_HOST => $NLW_HOST_IP"
  #echo "DOCKER_TCP_URI => $DOCKER_TCP_URI"
  echo "LOCAL_HOST_NAME => $LOCAL_HOST_NAME"
fi

if [ "$1" == "debug" ]; then
  echo "In debug mode"
fi

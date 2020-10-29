#!/bin/sh
set -e

. "`dirname $0`"/../globals.sh

if [ ! "$(which git)" ]; then
  sudo apt-get install -y -q git
fi

HOME=/home/orasilabs

# create a separate directory for latest examples repo (includes startup config)
if [ ! -d "$HOME/startup" ]; then
  mkdir -p $HOME/startup/
fi

# clone or pull latest example repo
if [ ! -d "$HOME/startup/neoload-ci-training" ]; then
  cd $HOME/startup/ && git clone $git_repo_url
else
  cd $HOME/startup/neoload-ci-training && git pull
fi

cd $HOME/startup/neoload-ci-training && git checkout $git_branch


JENKINS_HTTP_PORT=80
NLW_HOST=nlweb.shared
NLW_HOST_API_BASE=http://$NLW_HOST:8080

NLW_HOST_IP=$(sudo ping -c1 -t1 -W1 $NLW_HOST 2>/dev/null | head -n1 | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])')
if [ -z "$NLW_HOST_IP" ]; then
  echo "Cannot resolve the IP address for $NLW_HOST. Please discuss with your workshop instructor."
  exit 3
else
  sleep 3
fi

echo "Exiting"
exit 50


# every time this VM is booted, run the initial Jenkins setup (persists data between sessions)
sudo $HOME/startup/neoload-ci-training/infra/local_jenkins/start.sh

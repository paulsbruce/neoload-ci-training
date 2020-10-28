#!/bin/sh
set -e

if [ ! "$(which git)" ]; then
  sudo apt-get install -y -q git
fi

HOME=/home/orasilabs

if [ ! -d "$HOME/startup" ]; then
  mkdir -p $HOME/startup/
fi

if [ ! -d "$HOME/startup/neoload-ci-training" ]; then
  cd $HOME/startup/ && git clone https://github.com/paulsbruce/neoload-ci-training.git
else
  cd $HOME/startup/neoload-ci-training && git pull
fi

sudo $HOME/startup/neoload-ci-training/infra/local_jenkins/start.sh

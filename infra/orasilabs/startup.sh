#!/bin/sh
set -e
sudo apt-get install git
HOME=/home/orasilabs
mkdir -p $HOME/startup/
if [ ! -d "$HOME/startup/neoload-ci-training" ]; then
  cd $HOME/startup/ && git clone https://github.com/paulsbruce/neoload-ci-training.git
else
  cd $HOME/startup/neoload-ci-training && git pull
fi
$HOME/startup/neoload-ci-training/infra/local_jenkins/start.sh

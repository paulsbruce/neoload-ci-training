#!/bin/sh
set -e
sudo apt-get install git
HOME=/home/orasilabs
mkdir -p $HOME/startup/
cd $HOME/startup/ && git clone https://github.com/paulsbruce/neoload-ci-training.git
$HOME/startup/neoload-ci-training/infra/local_jenkins/start.sh

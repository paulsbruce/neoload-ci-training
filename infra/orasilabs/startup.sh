#!/bin/sh
set -e
sudo apt-get install git
mkdir -p /orasilabs/startup/
cd /orasilabs/startup/ && git clone https://github.com/paulsbruce/neoload-ci-training.git
/orasilabs/startup/neoload-ci-training/infra/local_jenkins/start.sh

#!/bin/bash
set -e

git_repo_url=https://github.com/paulsbruce/neoload-ci-training.git
git_branch=master

# safe defaults, can be overridden in environment-specific config (like orasilabs/startup.sh)
JENKINS_HTTP_PORT=8081
NLW_HOST=neoload-rest.saas.neotys.com
NLW_HOST_API_BASE=https://$NLW_HOST

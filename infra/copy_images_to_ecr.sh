#!/bin/bash

AWS_REGION=us-east-1
AWS_PUBLIC_REPO_ROOT=public.ecr.aws/t5c5t1o4

aws ecr-public get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_PUBLIC_REPO_ROOT

IMAGE_SPECS="jenkinsci/blueocean:1.24.4 docker:dind gitbucket/gitbucket:4.35.3 neotys/neoload-controller:7.7.0 neotys/neoload-loadgenerator:7.7.0"
#IMAGE_SPECS="docker:dind"

for spec in $IMAGE_SPECS; do
    arrIN=(${spec//\// })
    dockerhub_repo=${arrIN[0]}
    image_and_ver=${arrIN[1]}
    if [ -z "$image_and_ver" ]; then
      image_and_ver=${arrIN[0]}
      dockerhub_repo=""
    fi

    target=$AWS_PUBLIC_REPO_ROOT/$image_and_ver

    echo $spec
    echo $target
    echo "dockerhub_repo: $dockerhub_repo"
    echo "image_and_ver: $image_and_ver"

    docker pull $spec
    docker tag $spec $target
    docker push $target

done

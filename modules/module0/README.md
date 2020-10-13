# NeoLoad CI/Jenkins Training, Module 0: Prerequisites

## Assumptions

*Internet access to:*
 - Github
 - Dockerhub
 - Pypi and Python.org

*NeoLoad Web*
 - If SaaS NeoLoad Web, internet access to *.neotys.com
 - If on-prem, connectivity line-of-site to the NLW server (web and API ports)
 - Enterprise license installed and activated in your NeoLoad Web instance or NTS server*
 - Each person has created their own unique Access Token (called ‘CLI’)

*Infrastructure*
 - Using the ‘defaultzone’

## Prerequisites

*Local installation*
 - Git command line tools
 - If Windows, Chocolatey package manager
 - Docker (desktop editions)
 - Python 3.6+
 - pip3
 - NeoLoad (Java / GUI) * for diagnostic purposes only
 - Administrative install permissions for the above

CLI documentation and other links: [https://github.com/Neotys-Labs/neoload-cli#prerequisites](https://github.com/Neotys-Labs/neoload-cli#prerequisites)

## Supporting Elements

To get the latest version of these resources:
```
cd ~/Desktop/neoload-ci-training
git pull
```

*For these examples, we will be using Jenkins pipeline(s) to:*
 - Start local infrastructure and attach to a NLW zone
 - Run a sample test
 - Monitor the real-time test status
 - Provide outcome details, success/failure

*For infrastructure, you can configure NeoLoad Web zone to be:*
 - A “drop-in” static zone (for above local containers)
 - An “always-on” zone containing VMs/containers always running and attached to NLW
 - An elastic zone backed by a Kubernetes control plane such as OpenShift, PKS, AKS, GKE...

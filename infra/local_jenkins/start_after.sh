#!/bin/bash
set -e

source "`dirname $0`"/common.sh
source "`dirname $0`"/require_jenkins_secret.sh

echo 'Applying initial configurations to Jenkins container'

INSIDE_JENKINS_HOME=/var/jenkins_home
PIPELINE_TEMPLATE_FILE=pipeline.job.template.xml
CREDENTIALS_TEMPLATE_FILE=credentials.secret.template.xml

docker cp "`dirname $0`"/$PIPELINE_TEMPLATE_FILE jenkins-blueocean:$INSIDE_JENKINS_HOME/$PIPELINE_TEMPLATE_FILE
docker cp "`dirname $0`"/$CREDENTIALS_TEMPLATE_FILE jenkins-blueocean:$INSIDE_JENKINS_HOME/$CREDENTIALS_TEMPLATE_FILE

function mkf_copy() {
  contents=$(echo "$1")
  filename=$2
  inside_path=$3
  inside_full_path=$INSIDE_JENKINS_HOME/$filename

  echo "${contents}" > ~/tmp.$filename
  docker cp ~/tmp.$filename jenkins-blueocean:$inside_full_path
  $(chown_j "$inside_full_path")
  rm ~/tmp.$filename
  echo $inside_full_path
}
function chown_j() {
  full_path=$1
  docker exec -it --user root jenkins-blueocean chown jenkins:jenkins $full_path
}
function chmod_x() {
  full_path=$1
  $(chown_j "$full_path")
  docker exec -it --user root jenkins-blueocean chmod +x $full_path
}
function uuid() {
  echo $(docker exec -it --user root jenkins-blueocean cat /proc/sys/kernel/random/uuid)
}

rdc_xml="<?xml version='1.1' encoding='UTF-8'?>
<jenkins.security.ResourceDomainConfiguration>
 <url>$STATIC_JENKINS_URL</url>
</jenkins.security.ResourceDomainConfiguration>"
rdc_xml_fp=$(mkf_copy "$rdc_xml" 'jenkins.security.ResourceDomainConfiguration.xml')

jlc_xml="<?xml version='1.1' encoding='UTF-8'?>
<jenkins.model.JenkinsLocationConfiguration>
  <adminAddress>address not configured yet &lt;nobody@nowhere&gt;</adminAddress>
  <jenkinsUrl>$EXT_JENKINS_URL</jenkinsUrl>
</jenkins.model.JenkinsLocationConfiguration>"
jlc_xml_fp=$(mkf_copy "$jlc_xml" 'jenkins.model.JenkinsLocationConfiguration.xml')


shared_libs_xml="<?xml version='1.1' encoding='UTF-8'?>
<org.jenkinsci.plugins.workflow.libs.GlobalLibraries plugin=\"workflow-cps-global-lib@2.17\">
  <libraries>
    <org.jenkinsci.plugins.workflow.libs.LibraryConfiguration>
      <name>neoload-shared</name>
      <retriever class=\"org.jenkinsci.plugins.workflow.libs.SCMSourceRetriever\">
        <scm class=\"jenkins.plugins.git.GitSCMSource\" plugin=\"git@4.4.4\">
          <id>$(uuid)</id>
          <remote>$git_repo_url</remote>
          <credentialsId></credentialsId>
          <traits>
            <jenkins.plugins.git.traits.BranchDiscoveryTrait/>
          </traits>
        </scm>
      </retriever>
      <defaultVersion>$git_branch</defaultVersion>
      <implicit>false</implicit>
      <allowVersionOverride>true</allowVersionOverride>
      <includeInChangesets>true</includeInChangesets>
    </org.jenkinsci.plugins.workflow.libs.LibraryConfiguration>
  </libraries>
</org.jenkinsci.plugins.workflow.libs.GlobalLibraries>"
shared_libs_xml_fp=$(mkf_copy "$shared_libs_xml" 'org.jenkinsci.plugins.workflow.libs.GlobalLibraries.xml')

docker cp "`dirname $0`"/hosts.add.sh jenkins-blueocean:$INSIDE_JENKINS_HOME/hosts.add.sh
chmod_x "$INSIDE_JENKINS_HOME/hosts.add.sh"
docker exec -it --user root jenkins-blueocean $INSIDE_JENKINS_HOME/hosts.add.sh

cli_prep="
set -e

export JENKINS_URL=$INT_JENKINS_URL JENKINS_USER_ID=$JENKINS_USER_ID JENKINS_API_TOKEN=$JENKINS_SECRET
#echo JENKINS_URL: $INT_JENKINS_URL
#echo JENKINS_USER_ID: $JENKINS_USER_ID
#echo JENKINS_API_TOKEN: $JENKINS_SECRET

curl -s -L $INT_JENKINS_URL/jnlpJars/jenkins-cli.jar -o /var/jenkins_home/jenkins-cli.jar
function jcli() {
  java -jar /var/jenkins_home/jenkins-cli.jar \"\$@\"
}

function cp_pipeline_job() {
  job_name=\$1
  file_name=\$2
  git_jenkinsfile_path=\$3
  echo \"Checking job \$job_name\"
  cp $INSIDE_JENKINS_HOME/$PIPELINE_TEMPLATE_FILE $INSIDE_JENKINS_HOME/\$file_name
  sed -i \"s|{{git_repo_url}}|$git_repo_url|g\" $INSIDE_JENKINS_HOME/\$file_name
  sed -i \"s|{{git_branch}}|$git_branch|g\" $INSIDE_JENKINS_HOME/\$file_name
  sed -i \"s|{{git_jenkinsfile_path}}|\$git_jenkinsfile_path|g\" $INSIDE_JENKINS_HOME/\$file_name
  if jcli get-job \"\$job_name\" > /dev/null 2>&1 ; then
    echo \"Job '\$job_name' already exists; not overwriting\"
  else
    cat $INSIDE_JENKINS_HOME/\$file_name | jcli create-job \"\$job_name\"
    echo \"Created job '\$job_name'\"
  fi
}
function cp_credentials() {
  secret_name=\$1
  secret_value=\$2
  file_name=\$1.xml
  echo \"Creating Jenkins secret \$secret_name\"
  cp $INSIDE_JENKINS_HOME/$CREDENTIALS_TEMPLATE_FILE $INSIDE_JENKINS_HOME/secrets/\$file_name
  sed -i \"s|{{SECRET_NAME}}|\$secret_name|g\" $INSIDE_JENKINS_HOME/secrets/\$file_name
  sed -i \"s|{{SECRET_VALUE}}|\$secret_value|g\" $INSIDE_JENKINS_HOME/secrets/\$file_name
  cat $INSIDE_JENKINS_HOME/secrets/\$file_name | jcli create-credentials-by-xml system::system::jenkins \"(global)\"
  echo \$file_name
}
"
cli_prep_fp=$(mkf_copy "$cli_prep" 'jenkins.cli.prep.sh')
chmod_x $cli_prep_fp


docker cp "`dirname $0`"/jenkins.cli.plugin.steps.sh jenkins-blueocean:$INSIDE_JENKINS_HOME/jenkins.cli.plugin.steps.sh
chmod_x "$INSIDE_JENKINS_HOME/jenkins.cli.plugin.steps.sh"

docker cp "`dirname $0`"/jenkins.cli.job.steps.sh jenkins-blueocean:$INSIDE_JENKINS_HOME/jenkins.cli.job.steps.sh
chmod_x "$INSIDE_JENKINS_HOME/jenkins.cli.job.steps.sh"

docker cp "`dirname $0`"/jenkins.cli.secrets.steps.sh jenkins-blueocean:$INSIDE_JENKINS_HOME/jenkins.cli.secrets.steps.sh
chmod_x "$INSIDE_JENKINS_HOME/jenkins.cli.secrets.steps.sh"


credentials_steps="
#!/bin/sh

source $cli_prep_fp

export NLW_TOKEN=$NLW_TOKEN
export DYNATRACE_URL=$DYNATRACE_URL
export DYNATRACE_API_TOKEN=$DYNATRACE_API_TOKEN

source $INSIDE_JENKINS_HOME/jenkins.cli.secrets.steps.sh
"
credentials_steps_fp=$(mkf_copy "$credentials_steps" 'jenkins.credentials_steps.sh')
chmod_x $credentials_steps_fp
docker exec -it jenkins-blueocean sh $credentials_steps_fp


plugin_steps="
#!/bin/sh

source $cli_prep_fp

source $INSIDE_JENKINS_HOME/jenkins.cli.plugin.steps.sh
"
plugin_steps_fp=$(mkf_copy "$plugin_steps" 'jenkins.plugin_steps.sh')
chmod_x $plugin_steps_fp
docker exec -it jenkins-blueocean sh $plugin_steps_fp


source "`dirname $0`"/wait_for_jenkins_up.sh


job_steps="
#!/bin/sh

source $cli_prep_fp

source $INSIDE_JENKINS_HOME/jenkins.cli.job.steps.sh
"
job_steps_fp=$(mkf_copy "$job_steps" 'jenkins.job_steps.sh')
chmod_x $job_steps_fp
docker exec -it jenkins-blueocean sh $job_steps_fp


#echo "Jenkins secret: $JENKINS_SECRET"

source "`dirname $0`"/wait_for_jenkins_up.sh

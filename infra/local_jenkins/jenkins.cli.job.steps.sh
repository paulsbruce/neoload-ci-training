echo $(cp_pipeline_job 'Start Infra' 'start_infra.xml' 'infra/start_infra.Jenkinsfile')
echo $(cp_pipeline_job 'Stop Infra' 'stop_infra.xml' 'infra/stop_infra.Jenkinsfile')
echo $(cp_pipeline_job 'Rebuild CLI Agent' 'rebuild_agent.xml' 'infra/rebuildAgent.Jenkinsfile')

echo $(cp_pipeline_job 'module1' 'module_1.xml' 'modules/module1/Jenkinsfile')
# do not do all the modules, that's for the students to go through
echo $(cp_pipeline_job 'moduleX' 'module_X.xml' 'modules/moduleX/Jenkinsfile')

sleep 10
jcli build 'Rebuild CLI Agent' -s

#echo 'Restarting Jenkins after applying initial configurations'
#jcli safe-restart
sleep 5

set +e

echo 'Applying secrets to credential store'

echo $(cp_credentials 'NLW_TOKEN' $NLW_TOKEN)

if [ "$DYNATRACE_URL" ]; then
  echo $(cp_credentials 'DYNATRACE_URL' $DYNATRACE_URL)
fi
if [ "$DYNATRACE_API_TOKEN" ]; then
  echo $(cp_credentials 'DYNATRACE_API_TOKEN' $DYNATRACE_API_TOKEN)
fi

set -e

sleep 5

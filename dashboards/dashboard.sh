#!/bin/bash

set -e

IMAGE=${IMAGE:-docker.io/grafana/grafana:7.1.5}
ENGINE=${ENGINE:-podman}
PORT=$((($RANDOM%64000)+1024))
DASHBOARD=kube-burner-latest.json

add_dashboard(){
  echo "Adding dashboard ${1}"
  local dashboard='{"dashboard": '$(cat ${1})', "overwrite": false}'
  url=$(echo "${dashboard}" | curl -sS http://localhost:${PORT}/api/dashboards/db -H "Content-type: application/json" -u admin:admin  -d@- | jq -r .url)
}


add_datasource(){
  esds='{
    "name": "'${1}'",
    "type": "elasticsearch",
    "access": "proxy",
    "url": "'${2}'",
    "database": "'${3}'",
    "jsonData": {
      "esVersion": 70,
      "maxConcurrentShardRequests": 5,
      "timeField": "timestamp"
    }
  }'
  echo ${esds} | curl -sS http://localhost:${PORT}/api/datasources -H "Content-type: application/json" -u admin:admin -d@- -o /dev/null
}


usage(){
  cat << EOF
Usage: $0 -e http://es.com:9200 [-i index]

Options:
  -e ElasticSearch instance, i.e. myelastic.com:9200
  -i ElasticSearch index name. Default: "kube-burner"
EOF
exit 0
}


index="kube-burner"
while getopts "e:i:h" opt; do
  case ${opt} in
    e )
      datasource=$OPTARG
      ;;
    i )
      index=$OPTARG
      ;;
    h )
      usage 
      ;;
    \? )
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      exit 1
      ;;
  esac
done

${ENGINE} run -d --rm -p ${PORT}:3000 -e GF_AUTH_ANONYMOUS_ENABLED=true ${IMAGE}
while [[ $(curl -s -o /dev/null -w '%{http_code}' http://localhost:${PORT}/api/health) != "200" ]]; do 
  sleep 1
done

add_datasource "kube-burner" ${datasource} ${index}
add_dashboard ${DASHBOARD}
echo -e "Kube-burner dashboard available at:\nhttp://localhost:${PORT}${url}?from=now-3h&to=now"

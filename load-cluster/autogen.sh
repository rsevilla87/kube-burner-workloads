#!/bin/bash

BASE_CONFIG=load-cluster-template.yml
CONFIG=kube-burner-resources/load-cluster.yml
NAMESPACE=kube-burner

export UUID=$(uuidgen)
export CLIENT_IMAGE=quay.io/rsevilla/perfapp:latest
export SERVER_IMAGE=registry.redhat.io/rhscl/postgresql-10-rhel7:latest
KUBE_BURNER_COMMAND="kube-burner init -c /mnt/load-cluster.yml --uuid=${UUID}"

printf "Calculating number of iterations...\n"
NPROC=$(oc get node -l node-role.kubernetes.io/worker,node-role.kubernetes.io/infra!=,node-role.kubernetes.io/workload!= -o go-template --template '{{ range .items }}{{ .status.capacity.cpu }}{{"\n"}}{{ end }}' | awk '{cores+=$1}END{print cores}')

printf "The worker nodes of the cluster have a capacity of: ${NPROC} CPU cores\n"
printf "Hence, we'll run ${NPROC} iterations of the workload\n"
export JOB_ITERATIONS=${NPROC}
read -p "Enable ES indexing? yes/[no]: " INDEXING
if [[ ${INDEXING} =~ ^(y|yeah|yes|si|yup)$ ]]; then
  export INDEXING=true
  read -p "Elasticsearch instance [https://search-perfscale-dev-chmf5l4sh66lvxbnadi4bznl3a.us-west-2.es.amazonaws.com:443]: " ES_INSTANCE
  export ES_SERVER=${ES_INSTANCE:-https://search-perfscale-dev-chmf5l4sh66lvxbnadi4bznl3a.us-west-2.es.amazonaws.com:443}
  read -p "Elasticsearch index name [ripsaw-kube-burner]: " ES_INDEX
  export ES_INDEX=${ES_INDEX:-ripsaw-kube-burner}
  printf "Obtaining a valid prometheus token...\n"
  PROMETHEUS_TOKEN=$(oc sa get-token -n openshift-monitoring prometheus-k8s)
  read -p "Metric profile, metrics.yaml or metrics-aggregated.yaml (recommended for big clusters) [metrics.yaml]: " METRIC_PROFILE
  METRIC_PROFILE=${METRIC_PROFILE:-metrics.yaml}
  KUBE_BURNER_COMMAND+=" --prometheus-url=https://prometheus-k8s.openshift-monitoring.svc.cluster.local:9091 --token=${PROMETHEUS_TOKEN} -m=${METRIC_PROFILE}"
else
  export INDEXING=false
fi
read -p "QPS [20]: " QPS
export QPS=${QPS:-20}
read -p "Burst [20]: " BURST
export BURST=${BURST:-20}
export KUBE_BURNER_COMMAND

envsubst <<< $(cat ${BASE_CONFIG}) > ${CONFIG}
envsubst <<< $(cat resources.yml) | kubectl apply -f -
# kubectl does not follow symlinks if those files are not specified explicitly
if [[ ${METRIC_PROFILE} != "" ]]; then
  kubectl create configmap kube-burner-config-${UUID} --from-file=kube-burner-resources --from-file=kube-burner-resources/${METRIC_PROFILE} -n ${NAMESPACE}
else
  kubectl create configmap kube-burner-config-${UUID} --from-file=kube-burner-resources -n ${NAMESPACE}
fi
printf "Workload deployed in the ${NAMESPACE} namespace\n"

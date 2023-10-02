#!/usr/bin/env bash

if [[ -z $STORAGE_PERF_NAMESPACE ]] && [[ $# -eq 0 ]]; then
  echo "usage: $0 <storage-perf-namespace>  # OR export ENV variable STORAGE_PERF_NAMESPACE"
  exit  1
fi

if [[ $# -ge 1 ]]; then
  STORAGE_PERF_NAMESPACE=$1
else
  STORAGE_PERF_NAMESPACE=${STORAGE_PERF_NAMESPACE:-$1}
fi

echo "*** stotage perf namespace to be deleted: $STORAGE_PERF_NAMESPACE"

oc delete job $(oc get jobs -n ${STORAGE_PERF_NAMESPACE} | grep -Ev NAME | awk '{ print $1 }') -n ${STORAGE_PERF_NAMESPACE}
oc delete pvc $(oc get pvc -n ${STORAGE_PERF_NAMESPACE} | grep -Ev NAME | awk '{ print $1 }') -n ${STORAGE_PERF_NAMESPACE}
# optionally
oc delete project ${STORAGE_PERF_NAMESPACE}
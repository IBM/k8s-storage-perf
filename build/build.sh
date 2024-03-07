#!/bin/bash
set -ex

scriptdir=`dirname $0`
docker_file_name=${scriptdir}/dockerfile
docker_registry=${DOCKER_REGISTRY:-"localhost:5000"}
docker_image=${DOCKER_IMAGE:-"${docker_registry}/k8s-storage-perf"}
docker_tag=${TAG_ID:-"latest"}
arch_type=${ARC_TYPE:-`uname -m`}

dockerexe=${DOCKER_EXE:-podman}
nocache=${DEV_NOCACHE:-"--pull"}
${dockerexe} build ${nocache} -f ${docker_file_name} -t ${docker_image}:${docker_tag}-${arch_type} .
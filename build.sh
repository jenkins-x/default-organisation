#!/bin/bash

set -euo pipefail

SA=~/.gke_sa.json
HELM_VERSION=2.11.0
HELM=helm

function init() {
    mkdir -p ~/.jx/bin
    export PATH=$PATH:~/.jx/bin
}

function install_dependencies() {
    wget https://github.com/jenkins-x/jx/releases/download/v${JX_VERSION}/jx-linux-amd64.tar.gz
    tar xvf jx-linux-amd64.tar.gz
    rm jx-linux-amd64.tar.gz
    mv jx ~/.jx/bin

    if [ "true" == "${HELM3}" ]; then
        echo "Installing helm3"
        wget https://github.com/jstrachan/helm/releases/download/untagged-93375777c6644a452a64/helm-linux-amd64.tar.gz
        tar xvf helm-linux-amd64.tar.gz
        rm helm-linux-amd64.tar.gz
        mv helm3 ~/.jx/bin/
        ln -s ~/.jx/bin/helm3 ~/.jx/bin/helm
        ${HELM} init
    else
        echo "Installing ${HELM_VERSION}"
        wget https://storage.googleapis.com/kubernetes-helm/helm-v${HELM_VERSION}-linux-amd64.tar.gz
        tar xvf helm-v${HELM_VERSION}-linux-amd64.tar.gz
        rm helm-v${HELM_VERSION}-linux-amd64.tar.gz
        mv linux-amd64/helm ~/.jx/bin
        rm -fr linux-amd64
        ${HELM} init --client-only
    fi
}

function configure_environment() {
	echo ${GKE_SA_JSON} > ${SA}
	git config --global --add user.name "${GIT_USER}"
	git config --global --add user.email "${GIT_EMAIL}"
}

function apply() {
	OLDIFS=$IFS
	CLUSTER_COMMAND=""
	IFS=$','
	for ENVIRONMENT in $ENVIRONMENTS; do
		CLUSTER_COMMAND="${CLUSTER_COMMAND} -c ${ENVIRONMENT}"
	done
	IFS=$OLDIFS

	git status
	which jx
	
	if [[ "${CI_BRANCH}" == "master" ]]; then
		echo "Running master build"
		jx create terraform --verbose ${CLUSTER_COMMAND} \
		    -b --install-dependencies -o ${ORG} \
		    --gke-service-account ${SA}
	else
		echo "Running PR build for ${CI_BRANCH}"
		jx create terraform --verbose ${CLUSTER_COMMAND} \
		     -b --install-dependencies -o ${ORG} \
		     --gke-service-account ${SA} \
		     --skip-terraform-apply \ 
		     --local-organisation-repository .
	fi
}

init
install_dependencies
configure_environment
apply

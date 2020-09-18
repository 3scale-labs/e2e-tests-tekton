TEKTON_RELEASE_FILE := tekton/pipeline-release_0.15.2_notags.yaml
TEKTON_TRIGGERS_RELEASE_FILE := tekton/triggers-release_0.7.0_notags.yaml

K8S_API_SERVER_URL := https://api.dev-eng-ocp4-3.dev.3sca.net:6443
PIPELINE_NAMESPACE := 3scale-qe-tests-pipeline
DEPLOY_NAMESPACE := 3scale-qe-tests
SERVICEACCOUNT_NAME_FOR_QE_TESTSUITE_ACCESS_TO_K8S := qe-testsuite-access
CLUSTER_ADMIN_SERVICEACCOUNT := provisioning-sa
WILDCARD_DOMAIN := apps.dev-eng-ocp4-3.dev.3sca.net
OPERATOR_INDEX_IMAGE := quay.io/3scale/rh-3scale-operator-index:3scale-amp-2.9-rhel-7-containers-candidate-16844-20200909095849
DEPLOY_REPO_URL := https://github.com/gsaslis/3scale-deployment.git
DEPLOY_REPO_BRANCH := main

run: bin/tkn
	tkn pipeline start e2e-tests-pipeline \
		--task-serviceaccount=test=robot-quay-git-ssh \
		--serviceaccount=$(CLUSTER_ADMIN_SERVICEACCOUNT) \
		--param wildcard-domain=$(WILDCARD_DOMAIN) \
		--param openshift-server-url=$(K8S_API_SERVER_URL) \
		--param openshift-project-name=$(DEPLOY_NAMESPACE) \
		--param openshift-pipeline-project-name=$(PIPELINE_NAMESPACE) \
		--param openshift-service-account-name=$(SERVICEACCOUNT_NAME_FOR_QE_TESTSUITE_ACCESS_TO_K8S) \
		--param 3scale-operator-index-image=$(OPERATOR_INDEX_IMAGE) \
		--param deploy-repo-url=$(DEPLOY_REPO_URL) \
		--param deploy-repo-branch=$(DEPLOY_REPO_BRANCH) \
		--param e2e-tests-image=quay.io/integreatly/3scale-py-testsuite:2.9 \
		--workspace name=e2e-tests-pipeline,volumeClaimTemplateFile=./pipelineWorkspace_VolumeClaimTemplate.yaml

install: private-quay-repo pipeline trigger

pipeline:
	oc new-project $(PIPELINE_NAMESPACE)
	oc apply -f qe-e2e-tests/secrets/
	oc apply -f qe-e2e-tests
	oc apply -f https://raw.githubusercontent.com/tektoncd/catalog/master/task/git-clone/0.2/git-clone.yaml
#	oc create serviceaccount $(CLUSTER_ADMIN_SERVICEACCOUNT)
#	oc adm policy add-cluster-role-to-user self-provisioner system:serviceaccount:$(PIPELINE_NAMESPACE):$(CLUSTER_ADMIN_SERVICEACCOUNT)
	oc apply --filename qe-e2e-tests/provisioning/

trigger:
	oc project $(PIPELINE_NAMESPACE)
	oc apply --filename tekton/triggers/

private-quay-repo:
	oc project openshift-marketplace
	oc apply -f qe-e2e-tests/secrets/threescale-registry-auth.yaml
	oc secret link default threescale-registry-auth --for=pull


install-tekton:
	oc new-project tekton-pipelines
	oc adm policy add-scc-to-user anyuid -z tekton-pipelines-controller
	oc apply --filename $(TEKTON_RELEASE_FILE)
	oc apply --filename $(TEKTON_TRIGGERS_RELEASE_FILE)

uninstall-tekton:
	oc delete --filename $(TEKTON_RELEASE_FILE) || true
	oc delete --filename $(TEKTON_TRIGGERS_RELEASE_FILE) || true
	oc delete project tekton-pipelines

bin/tkn: bin
	#curl -LO https://github.com/tektoncd/cli/releases/download/v0.9.0/tkn_0.9.0_Darwin_x86_64.tar.gz
	#tar xzvf tkn_0.9.0_Darwin_x86_64.tar.gz -C bin/
	#chmod +x bin/tkn

bin:
	mkdir -p bin/

clean:
	oc project $(PIPELINE_NAMESPACE)
	oc delete -f qe-e2e-tests/secrets/ || true
	oc delete -f qe-e2e-tests/ || true
	oc delete project $(PIPELINE_NAMESPACE)
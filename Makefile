K8S_API_SERVER_URL := https://api.dev-eng-ocp4-3.dev.3sca.net:6443
PIPELINE_NAMESPACE := 3scale-qe-tests-pipeline
DEPLOY_NAMESPACE := 3scale-qe-tests
SERVICEACCOUNT_NAME_FOR_QE_TESTSUITE_ACCESS_TO_K8S := qe-testsuite-access
CLUSTER_ADMIN_SERVICEACCOUNT := 3scale-deployer
WILDCARD_DOMAIN := apps.dev-eng-ocp4-3.dev.3sca.net

run: bin/tkn
	tkn pipeline start e2e-tests-pipeline \
		--task-serviceaccount=provision=$(CLUSTER_ADMIN_SERVICEACCOUNT) \
		--task-serviceaccount=deploy=$(CLUSTER_ADMIN_SERVICEACCOUNT) \
		--task-serviceaccount=test=robot-quay-git-ssh \
		--task-serviceaccount=teardown=$(CLUSTER_ADMIN_SERVICEACCOUNT) \
		--param wildcard-domain=$(WILDCARD_DOMAIN) \
		--param openshift-server-url=$(K8S_API_SERVER_URL) \
		--param openshift-project-name=$(DEPLOY_NAMESPACE) \
		--param openshift-service-account-name=$(SERVICEACCOUNT_NAME_FOR_QE_TESTSUITE_ACCESS_TO_K8S) \
		--resource app-image=e2e-tests-image \
		--resource deploy-source=3scale-deployment-git

install:
	oc new-project $(PIPELINE_NAMESPACE)
	oc create -f qe-e2e-tests/secrets/
	oc create -f qe-e2e-tests
#	oc create serviceaccount $(SERVICEACCOUNT_NAME_FOR_QE_TESTSUITE_ACCESS_TO_K8S)
#	oc policy add-role-to-user admin --serviceaccount=qe-testsuite-access
	oc create serviceaccount $(CLUSTER_ADMIN_SERVICEACCOUNT)
#	oc policy add-role-to-user admin --serviceaccount=$(CLUSTER_ADMIN_SERVICEACCOUNT)
	oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:$(PIPELINE_NAMESPACE):$(CLUSTER_ADMIN_SERVICEACCOUNT)
	oc adm policy add-cluster-role-to-user self-provisioner system:serviceaccount:$(PIPELINE_NAMESPACE):$(CLUSTER_ADMIN_SERVICEACCOUNT)


bin/tkn: bin
	#curl -LO https://github.com/tektoncd/cli/releases/download/v0.8.0/tkn_0.8.0_Darwin_x86_64.tar.gz
	#tar xzvf tkn_0.8.0_Darwin_x86_64.tar.gz -C bin/
	#chmod +x bin/tkn

bin:
	mkdir -p bin/

clean:
	oc delete -f qe-e2e-tests/secrets/ || true
	oc delete -f qe-e2e-tests/ || true
	oc delete project $(PIPELINE_NAMESPACE)
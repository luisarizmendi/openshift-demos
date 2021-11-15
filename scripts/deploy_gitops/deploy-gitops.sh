#!/bin/bash



if ! command -v oc &> /dev/null
then
    echo "oc command could not be found, you must install it"
    exit
fi

if ! oc project &> /dev/null; then
  echo "You must login into the OpenShift cluster first"
  exit
fi



oc apply -k resources/openshift-gitops-operator/overlays/stable

RESOURCE="ArgoCD"

while [[ $(oc api-resources | grep $RESOURCE  > /dev/null ; echo $?) != "0" ]]; do echo "Waiting for $RESOURCE object..." && sleep 10; done



# Wait for ArgoCD CRD is ready
NUMBER_COMPONENTS="5"
NAMESPACE="openshift-gitops"
while [[ $(oc describe argocd -n $NAMESPACE | grep Running | wc -l) != $NUMBER_COMPONENTS ]]; do echo "Waiting ArgoCD deployment..." && sleep 10; done


#oc apply -k resources/crds/gitops
oc apply -f resources/crds/gitops/application-controller-cluster-admin.yaml
oc apply -f resources/crds/gitops/argocd.yaml 


# Wait for ArgoCD CRD is ready
NUMBER_COMPONENTS="5"
NAMESPACE="openshift-gitops"
while [[ $(oc describe argocd -n $NAMESPACE | grep Running | wc -l) != $NUMBER_COMPONENTS ]]; do echo "Waiting ArgoCD deployment..." && sleep 10; done



# //////////////////////
# Enable sealed secret operator
oc new-project sealed-secrets
oc apply -k resources/sealed-secrets-operator/overlays/default


# Wait for the resource
RESOURCE="SealedSecret"
while [[ $(oc api-resources | grep $RESOURCE  > /dev/null ; echo $?) != "0" ]]; do echo "Waiting for $RESOURCE object..." && sleep 10; done



# install client-side bin
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.16.0/kubeseal-linux-amd64 -O /tmp/kubeseal
chmod +x /tmp/kubeseal
sudo cp /tmp/kubeseal /usr/local/bin/kubeseal


# Get cert and include it in the repo
sleep 30 

kubeseal  \
  --controller-namespace sealed-secrets \
  --fetch-cert > kubeseal-cert.pem

chmod 600 kubeseal-cert.pem



# //////////////////////



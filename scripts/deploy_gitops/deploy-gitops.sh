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



# //////////////////////
# Create namespace argocd and give admin role to groups manuela-team and manuela-dev and view role to manuela-ops
# Create OperatorGroup applied to argocd namespace
# Create an installplan-approver job (Operator will be deployed in "Manual" mode) using installplan-approver service account with a dedicated role
# Deploy ArgoCD operator (create Subscription)
# Give ArgoCD clusteradmin Role

# Create Role to access all api endpoints and give it to argocd-redis-ha Service Account

oc apply -k resources/operators/gitops-operator


# Wait for the resource ArgoCD and create one and wait until it is ready

RESOURCE="ArgoCD"

while [[ $(oc api-resources | grep $RESOURCE  > /dev/null ; echo $?) != "0" ]]; do echo "Waiting for $RESOURCE object..." && sleep 10; done

#oc apply -k resources/crds/gitops
oc apply -f resources/crds/gitops/argocd.yaml 

# Wait for ArgoCD CRD is ready
NUMBER_COMPONENTS="5"
NAMESPACE="openshift-gitops"
while [[ $(oc describe argocd -n $NAMESPACE | grep Running | wc -l) != $NUMBER_COMPONENTS ]]; do echo "Waiting ArgoCD deployment..." && sleep 10; done





# //////////////////////
# Enable sealed secret operator

oc apply -k resources/operators/sealed-secrets-operator


# Wait for the resource
RESOURCE="SealedSecretController"
while [[ $(oc api-resources | grep $RESOURCE  > /dev/null ; echo $?) != "0" ]]; do echo "Waiting for $RESOURCE object..." && sleep 10; done

oc apply -k resources/crds/sealed-secrets



# Wait for CRD is ready
NUMBER_COMPONENTS="2"
while [[ $(oc get pod -n sealed-secrets | grep Running | wc -l) != $NUMBER_COMPONENTS ]]; do echo "Waiting CRD deployment..." && sleep 10; done



# install client-side bin
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.16.0/kubeseal-linux-amd64 -O /tmp/kubeseal
chmod +x /tmp/kubeseal
sudo cp /tmp/kubeseal /usr/local/bin/kubeseal


# Get cert and include it in the repo
sleep 15 

kubeseal  \
  --controller-name sealed-secret-controller-sealed-secrets \
  --controller-namespace sealed-secrets \
  --fetch-cert > kubeseal-cert.pem

chmod 600 kubeseal-cert.pem



# //////////////////////

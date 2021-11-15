#!/bin/bash


if ! command -v kubeseal &> /dev/null
then
    echo "kubeseal command could not be found, you must install it"
    exit
fi


if ! command -v oc &> /dev/null
then
    echo "oc command could not be found, you must install it"
    exit
fi

if ! oc project &> /dev/null; then
  echo "You must login into the OpenShift cluster first"
  exit
fi




source env_secrets


echo ""
echo ""
echo "###########################################"
echo "Check that your ENV variables are correct:"
echo ""
echo "   GITHUB_PERSONAL_ACCESS_TOKEN: ${GITHUB_PERSONAL_ACCESS_TOKEN}"
echo ""
echo "   GITHUB_USER: ${GITHUB_USER}"
echo ""
echo "   QUAY_BUILD_SECRET: "
echo ""
echo "${QUAY_BUILD_SECRET}" | base64 -d
echo ""
echo "###########################################"
echo ""
echo ""
while true; do
    read -p "Do you wish to continue?  " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done




# Create secret files

GITHUB_PERSONAL_ACCESS_TOKEN_base64=$(echo -n $GITHUB_PERSONAL_ACCESS_TOKEN|base64)
GITHUB_USER_base64=$(echo -n $GITHUB_USER|base64)

cat <<EOF > /tmp/github-secret.yaml
kind: Secret
apiVersion: v1
metadata:
  name: github
  namespace: manuela-cicd
data:
  token: $GITHUB_PERSONAL_ACCESS_TOKEN_base64
  user: $GITHUB_USER_base64
type: Opaque
EOF




ARGOCD_PASSWORD=$(oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.*}')

cat <<EOF > /tmp/argocd-env-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-env
  namespace: manuela-cicd
data:
  ARGOCD_USERNAME: YWRtaW4=
  ARGOCD_PASSWORD: $ARGOCD_PASSWORD
EOF



cat <<EOF > /tmp/quay-secret.yaml
kind: Secret
apiVersion: v1
metadata:
  name: quay-build-secret
  namespace: manuela-cicd
data:
  .dockerconfigjson: ${QUAY_BUILD_SECRET}
type: kubernetes.io/dockerconfigjson
EOF





# Get cert and include it in the repo
sleep 15 

kubeseal  \
  --controller-namespace sealed-secrets \
  --fetch-cert > kubeseal-cert.pem

chmod 600 kubeseal-cert.pem







# Create the sealed secrets

cat /tmp/github-secret.yaml | kubeseal --format yaml --cert kubeseal-cert.pem >  /tmp/github-sealed-secret.yaml
sed -i '/creationTimestamp/d' /tmp/github-sealed-secret.yaml


cat /tmp/argocd-env-secret.yaml | kubeseal --format yaml --cert kubeseal-cert.pem >  /tmp/argocd-env-sealed-secret.yaml
sed -i '/creationTimestamp/d' /tmp/argocd-env-sealed-secret.yaml


cat /tmp/quay-secret.yaml | kubeseal --format yaml --cert kubeseal-cert.pem >  /tmp/quay-sealed-secret.yaml
sed -i '/creationTimestamp/d' /tmp/quay-sealed-secret.yaml




# Update secrets

path_to_clusters="../../clusters"



echo ""
echo ""
echo ""
echo ""
echo "###########################################"
echo "CLUSTERS IN GITOPS REPO:"
echo ""
ls $path_to_clusters
echo ""
echo ""
echo "Which cluster are you using to host Tekton Pipelines?  "
echo ""
read clustername
echo ""


    cp /tmp/github-sealed-secret.yaml ${path_to_clusters}/${clustername}/base/cicd/
    cp /tmp/argocd-env-sealed-secret.yaml ${path_to_clusters}/${clustername}/base/cicd/
    cp /tmp/quay-sealed-secret.yaml ${path_to_clusters}/${clustername}/base/cicd/


echo ""
echo ""
echo ""
echo "Secret files created in directories under ${path_to_clusters}/${clustername}/base/cicd/ "
echo ""
echo "*******************************************************************"
echo ""
echo "       REMEMBER TO PUSH CHANGES TO YOUR GITOPS REPOSITORY"
echo ""
echo "*******************************************************************"
echo ""
echo ""
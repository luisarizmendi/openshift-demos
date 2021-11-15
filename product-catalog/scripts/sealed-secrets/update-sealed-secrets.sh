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
echo "   GITHUB_USER: ${GITHUB_USER}"
echo ""
echo "   SLACK_WEBHOOK: ${SLACK_WEBHOOK}"
echo ""
echo "   REGISTRY_SECRET: "
echo ""
echo "${REGISTRY_SECRET}" | base64 -d
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
GITHUB_EMAIL_base64=$(echo -n $GITHUB_EMAIL|base64)

cat <<EOF > /tmp/github-secret.yaml
kind: Secret
apiVersion: v1
metadata:
  name: github
  namespace: product-catalog-cicd
data:
  token: $GITHUB_PERSONAL_ACCESS_TOKEN_base64
  user: $GITHUB_USER_base64
  email: $GITHUB_EMAIL_base64
type: Opaque
EOF



SLACK_WEBHOOK_base64=$(echo -n $SLACK_WEBHOOK|base64 -w0)


cat <<EOF > /tmp/slack-deployments-webhook-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: slack-deployments-webhook
  namespace: product-catalog-cicd
data:
  url: ${SLACK_WEBHOOK_base64}
EOF



cat <<EOF > /tmp/dest-docker-config-secret.yaml
kind: Secret
apiVersion: v1
metadata:
  name: dest-docker-config
  namespace: product-catalog-cicd
data:
  .dockerconfigjson: ${REGISTRY_SECRET}
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


cat /tmp/slack-deployments-webhook-secret.yaml | kubeseal --format yaml --cert kubeseal-cert.pem >  /tmp/slack-deployments-webhook-sealed-secret.yaml
sed -i '/creationTimestamp/d' /tmp/slack-deployments-webhook-sealed-secret.yaml


cat /tmp/dest-docker-config-secret.yaml | kubeseal --format yaml --cert kubeseal-cert.pem >  /tmp/docker-sealed-secret.yaml
sed -i '/creationTimestamp/d' /tmp/docker-sealed-secret.yaml




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
    cp /tmp/slack-deployments-webhook-sealed-secret.yaml ${path_to_clusters}/${clustername}/base/cicd/
    cp /tmp/docker-sealed-secret.yaml ${path_to_clusters}/${clustername}/base/cicd/


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
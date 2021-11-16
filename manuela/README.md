# MANUela APP

Both app and GitOps repos are based on the ones that you can find in https://github.com/sa-mw-dach with changes in GitOps repo organization, changes in CICD Pipelines and splitting the app code repos.

Note: Tekton Pipelines for this application needs shared PVs, so you will need to have access to RWX storage. The PVCs are not specifying a Storage Class, so they will be using the default one (be sure that it provices RWX)

## How to prepare the DEMO ?

### 0) Fork APPs and GitOps repos and copy images to your repository

You will need to introduce changes into the repos and accept Pull Requests, so you need to fork them:

GitOps repo:

https://github.com/luisarizmendi/openshift-demos


APPs repos:

- https://github.com/luisarizmendi/manuela-iot-frontend
- https://github.com/luisarizmendi/manuela-iot-consumer
- https://github.com/luisarizmendi/manuela-iot-software-sensor
- https://github.com/luisarizmendi/manuela-iot-anomaly-detection


The pipelines will push and create tags in your repository, so you will need to copy the images into your own repository:

- https://quay.io/repository/luisarizmendi/iot-frontend
- https://quay.io/repository/luisarizmendi/iot-consumer
- https://quay.io/repository/luisarizmendi/iot-software-sensor
- https://quay.io/repository/luisarizmendi/iot-anomaly-detection

There are also a couple of base images used to build the app and for the pipeline tasks:

- https://quay.io/repository/luisarizmendi/httpd-ionic
- https://quay.io/repository/luisarizmendi/bumpversiontask 


Since I'm using my own repos (https://github.com/luisarizmendi/xxxx) in the descriptors, you will need to change the references to the gitops repo in:

- Application and ApplicationSet files under directory manuela/bootstrap/argocd/
- Pipeline config in file manuela/components/tekton/shared-workspaces/pipeline-config.yaml

You will also need to change references to app code repositories in the Pipeline config file.


Regaring the impage repository, same kind of changes (I'm using quay.io/luisarizmendi), you will need to include references to your own registry

- In kustomization.yaml files under manuela/environments/overlays/
- Pipeline config in file manuela/components/tekton/shared-workspaces/pipeline-config.yaml
- In pipelineruns objects in manuela/components/tekton/pipelineruns
- In triggertemplate objects in manuela/components/tekton/triggers



### 1) Deploy ArgoCD and Bitnami Sealed Secrets

If you don't have them deployed, you can find a script that can help with this: 

https://github.com/luisarizmendi/openshift-demos/blob/master/scripts/deploy_argo/deploy-argocd.sh


### 2) Update your secrets and configure the "Cluster parameters"

There is a directory (manuela/clusters) where the Cluster specific manifests should be configured (You might want to copy-paste one of the already configured directories and customize those files).

For this APP you just need to:
- Update Sealed Secrets in the cicd folder
- Configure the right domain in prod and test folders (file "iot-frontend-configmap.yaml")

First, update the SealedSecrets. You have a script which helps with updating the secrets (remember to be logged in into the OpenShift cluster with "oc login"):

https://github.com/luisarizmendi/openshift-demos/blob/master/manuela/scripts/sealed-secrets/update-sealed-secrets.sh

Note: Remember also to create first a file "env_secrets" with the right values. You will need to provide a GitHub token and the credentials for your image repository.

You can create the GitHub under Settings > Developer Settings > Personal access tokens (give it just permissions for repos)

For the repository, you could create a Robot/ServiceAccount Token instead of giving your credentials (so you can specify which images could be accessed easily). If you use Quay.io you can do it under Account Settings > Robot Accounts (remember to give write access to the APP images). In the env_secrets file you will need to provide the docker conf.json that is created in your desktop after login into the registry. You can find an example of that file here:

https://github.com/luisarizmendi/openshift-demos/blob/master/manuela/scripts/sealed-secrets/env_secrets-EXAMPLE


Finally, you might need to change the domain part of the url inside the "iot-frontend-configmap.yaml" files (in "prod" and "test" folders), otherwise the temperature and vibration information won't be shown in the app dashboard...

<b>Remember to push the changes to your GitOps repo before continuing</b>


### 3) Deploy the APP

In the bootstrap directory you will find the Application and ApplicationSet manifest to deploy the DEMO. You will need to copy-paste one of the already created directories and make changes in the files to point to the right gitops repositories and cluster directory (created in the previous step)


<b>It's better to create an App project in ArgoCD for each demo, so create one named manuela in this case.</b> You can do it just creating this manifest into OpenShift (you could just click the "+" button on the top right corner to create the new object): 

https://github.com/luisarizmendi/openshift-demos/blob/master/manuela/bootstrap/argocd/appproject.yaml

Once done, you just need to copy paste either the ApplicationSet or all the Application manifests (same "+" button).

Check in ArgoCD how the deployment progress...if nothing appears double check that you created the App Project as explained before (if you don't want to configure any App project, you can just change the project name from "manuela" to "default" in the AppliationSet and Appliation manifests).


Once you deployed CICD, Test and Prod environments, you will find that test environment is in "Degraded" state, that's because the container images that the gitops repo is referencing have not been created yet.

You can create the internal images used by the test environment by running the "Seed" pipeline. You can use the Pipeline run yaml found here:

https://github.com/luisarizmendi/openshift-demos/blob/master/manuela/components/tekton/pipelineruns/seed/base/seed.yaml


Note: Sometimes, if you dont' have enough resources in your cluster, the s2i tasks fail. You just need to stop the pipeline and re-launch it again (you can do it in the actions menu on top right corner)

You can check that the application was deployed opening the app frontend dashboard (I detected that, if you are low in resources, sometimes you need to reload the page a couple of times the first time that you access).

To test the anomaly detection service you can use a query similar to this one:

```
curl -k -X POST -H 'Content-Type: application/json' -d '{"data": { "ndarray": [[16.1,  15.40,  15.32,  13.47,  17.70]]}}' http://$(oc get route anomaly-detection -o jsonpath='{.spec.host}' -n manuela-test)/api/v1.0/predictions
```


### 4) Configure webhook in GitHub

Open forked application repos and create a Webhook (Go to Settings > Webhook, Add Webhook > Add)

In each repo (where you want a webhook to start the build pipeline), you will need to perform the following steps:

1) Payload URL: you can get the payload URLs by running this command (choose the right one for the repo that you are configuring):

```
for i in frontend consumer software-sensor anomaly
do
  echo $(oc get -n manuela-cicd route build-and-test-${i}-webhook --template='http://{{.spec.host}}')
done
```


Note: I've found that nip.io URLs sometimes are not working with GitHub webhooks.

2) Content type: application/json

3) Secret: leave it blank (Since we didn't configure any Secret for this listener)

4) Which events would you like to trigger this webhook?: "Just the push event"

5) Click on Add Webhook

Note: Remember to not running multiple builds at once, cloning and making changes in the gitops repository on each run, which may conflict with other pipelinerun


### 4) Deploy a CodeReady Workspaces workspace

1) Open CodeReady Workspaces: It will be running in the namespace openshift-workspaces, with a route similar to: http://codeready-openshift-workspaces.apps.<cluster name>.<domain>

2) Create a new workspace copy-pasting this devfile:

https://raw.githubusercontent.com/luisarizmendi/openshift-demos/master/manuela/components/global-operators/codeready-workspaces/base/devfile.yaml







## About the APP

You can find more information about the application in https://github.com/sa-mw-dach/manuela
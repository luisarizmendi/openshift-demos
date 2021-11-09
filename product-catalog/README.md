# Product-catalog APP

Both app and GitOps repos are a snapshot of the ones found in https://github.com/gnunn-gitops with several small changes in the CICD Pipelines and GitOps org.


## How to prepare the DEMO ?

### 0) Fork APPs and GitOps repos and copy images to your repository

You will need to introduce changes into the repos and accept Pull Requests, so you need to fork them:

GitOps repo:

- https://github.com/luisarizmendi/openshift-demos


APPs repos:

- https://github.com/luisarizmendi/product-catalog-client
- https://github.com/luisarizmendi/product-catalog-server


The pipelines will push and create tags in your repository, so you will need to copy the images into your own repository:

- https://quay.io/repository/luisarizmendi/product-catalog-client
- https://quay.io/repository/luisarizmendi/product-catalog-server


Since I'm using my own repos (https://github.com/luisarizmendi/xxxx) in the descriptors, you will need to change the references to the gitops repo in:

- Application and ApplicationSet files under directory manuela/bootstrap/argocd/
- In pipelineruns (if you want to use them) under product-catalog/components/tekton/pipelineruns/
- In triggertemplate objects (if you want to use them) under product-catalog/components/tekton/triggers/ 

You will also need to change references to app code repositories in pipelineruns and triggertemplate objects

Regaring the impage repository, same kind of changes (I'm using quay.io/luisarizmendi), you will need to include references to your own registry

- In kustomization.yaml files under product-catalog/environments/overlays/
- In pipelineruns objects
- In triggertemplate objects


### 1) Deploy ArgoCD and Bitnami Sealed Secrets

If you don't have them deployed, you can find a script that can help with this: 

https://github.com/luisarizmendi/openshift-demos/blob/master/scripts/deploy_argo/deploy-argocd.sh


### 2) Update your secrets and configure the "Cluster parameters"

There is a directory (product-catalog/clusters) where the Cluster specific manifests should be configured (You might want to copy-paste one of the already configured directories and customize those files).

For this APP you just need to prepare manifest for CICD  environment. 

First change the default StorageClass (Pipelines uses RWX volumes) in file clusters/"your cluster"/overlays/cicd/patch-pvc-block.yaml

Second, update the SealedSecrets. You have a script which helps with updating the secrets (remember to be logged in into the OpenShift cluster with "oc login"):

https://github.com/luisarizmendi/openshift-demos/blob/master/product-catalog/scripts/sealed-secrets/update-sealed-secrets.sh

Note: Remember also to create first a file "env_secrets" with the right values. You will need to provide a GitHub token, a Slack Webhook (if you want to receive messages from Pipeline) and the credentials for your image repository.

You can create the GitHub under Settings > Developer Settings > Personal access tokens (give it just permissions for repos)

The steps to create a Slack webhook can be found here: https://api.slack.com/messaging/webhooks

For the repository, you could create a Robot/ServiceAccount Token instead of giving your credentials (so you can specify which images could be accessed easily). If you use Quay.io you can do it under Account Settings > Robot Accounts (remember to give write access to the APP images). In the env_secrets file you will need to provide the docker conf.json that is created in your desktop after login into the registry. You can find an example of that file here:

https://github.com/luisarizmendi/openshift-demos/blob/master/product-catalog/scripts/sealed-secrets/env_secrets-EXAMPLE


Finally, you might want to change the domain part of the url inside the kustomization.yaml (in "patches" section), it's just for a message in the Pull Request but it's nice to have it pointing to the right URL...

<b>Remember to push the changes to your GitOps repo before continuing</b>


### 3) Deploy the APP

In the bootstrap directory you will find the Application and ApplicationSet manifest to deploy the DEMO. You will need to copy-paste one of the already created directories and make changes in the files to point to the right gitops repositories and cluster directory (created in the previous step)


<b>It's better to create an App project in ArgoCD for each demo, so create one named product-catalog in this case.</b> You can do it just creating this manifest into OpenShift (you could just click the "+" button on the top right corner to create the new object): 

https://github.com/luisarizmendi/openshift-demos/blob/master/product-catalog/bootstrap/argocd/appproject.yaml

Once done, you just need to copy paste either the ApplicationSet or all the Application manifests (same "+" button).

Check in ArgoCD how the deployment progress...if nothing appears double check that you created the App Project as explained before (if you don't want to configure any App project, you can just change the project name from "product-catalog" to "default" in the AppliationSet and Appliation manifests).


### 4) Configure webhook in GitHub

Open forked product-catalog-server and product-catalog-client github repos (Go to Settings > Webhook) click on Add Webhook > Add


1) Payload URL: In the client repo you need to configure this route:

```
echo $(oc get -n product-catalog-cicd route client-webhook --template='http://{{.spec.host}}')
```

In the server repo you need to configure this route:

```
echo $(oc get -n product-catalog-cicd route server-webhook --template='http://{{.spec.host}}')
```

Note: I've found that nip.io URLs sometimes are not working with GitHub webhooks.

2) Content type: application/json

3) Secret: leave it blank (Since we didn't configure any Secret for this listener)

4) Which events would you like to trigger this webhook?: "Just the push event"

5) Click on Add Webhook




## About the repos 
(copy from https://github.com/gnunn-gitops)

### Introduction

This is an OpenShift demo showing how to do GitOps in a kubernetes way using tools like [ArgoCD](https://argoproj.github.io/argo-cd/) and [Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/). The demo application is a three tier application using React for the front-end with Quarkus providing APIs as the back-end. The back-end was originally written in PHP and then ported to Quarkus. The application itself is a simple product catalog:

![alt text](https://raw.githubusercontent.com/gnunn-gitops/product-catalog/master/docs/img/screenshot.png)

The topology view in OpenShift shows the three tiers of the application:

![alt text](https://raw.githubusercontent.com/gnunn-gitops/product-catalog/master/docs/img/topology.png)

### Running demo locally

To run the demo locally on your laptop, you will need to have a MySQL or MariaDB database available. You will need to create a product database using the SQL in this repo and then update the quarkus application.properties file to reflect the location of the database.

The following repos will need to be cloned:

* [product-catalog-client](https://github.com/luisarizmendi/product-catalog-client)
* [product-catalog-server](https://github.com/luisarizmendi/product-catalog-server)


To run the quarkus application, execute ```mvn quarkus:dev``` from the root directory.

To run the client application, go into the client directory and run ```npm run start```.

### Install on OpenShift

This application makes heavy use of Kustomize and ArgoCD to deploy the application in a GitOps manner. I had originally thought to make this demo
consumeable for others but as I've extended it to more and more infrastructure (github/slack/etc) it's becoming challenging. At this point this repo
is more of a reference example then a demo someone else can run.

If you really want to to deploy this application into your own cluster,
you will need to create a new repo and setup Kustomize overlays that point to this repo. Since Kustomize supports referencing remote resources you do not need
to fork this repo, a new one will suffice.

This project requires Nexus and SonarQube be available, this project used to deploy them directly but I have opted to move these as a separate deployment so it can be shared amongst multiple projects. To see how I deploy them visit the [dev-tools](https://github.com/gnunn-gitops/dev-tools) repository.

*Deprecated* In order to make this easier, I had created a [product-catalog-template](https://github.com/gnunn-gitops/product-catalog-template) . It includes detailed instructions with regards to pre-requisities and what needs to be modified to deploy the demo in your own cluster.

Once deployed in your cluster under ArgoCD it should appear as follows:

![alt text](https://raw.githubusercontent.com/gnunn-gitops/product-catalog/master/docs/img/argocd.png)

### Test CI/CD Pipelines

The demo uses OpenShift Pipelines to build the client and server images for the application. The demo does not install PipelineRun objects via ArgoCD since these objects are transitory and not meant to be managed by a GitOps tool. To load the initial PipelineRun objects, use the following command:

```
oc apply -k manifests/tekton/pipelineruns/client/base
oc apply -k manifests/tekton/pipelineruns/server/base
```

To test the pipelines are actually taking changes, you can add a logo to the product catalog. The code to do this is commented out and can be found in the [nav.jsx](https://github.com/gnunn1/quarkus-product-catalog/blob/master/client/src/js/components/layouts/nav.jsx#L45) file.

Once you make the code change, start the client pipeline. Note that in OpenShift Pipelines the GUI does not support creating a new PipelineRunTask with a workspace, if you want to drive it from a GUI go into the PipelineRuns and simple rerun an existing one.

![alt text](https://raw.githubusercontent.com/gnunn-gitops/product-catalog/master/docs/img/tekton-rerun.png)

### Test Prod Pipeline

The demo uses a pipeline called ```push-prod-pr``` that creates a pull request in github. When the pull request is merged ArgoCD will see the change in git and automatically deploy the updated image for you. The client and server pipelines can run the push-prod-pr automatically if you set the ```push-to-prod``` parameter to true to have it trigger the pipeline automatically. The default for this parameter is false.

For the server pipeline the process has been enhanced so that a post-sync hook in ArgoCD will trigger a pipeline to run an integration test after the deployment and send a notification of the status to a slack channel. This process is depicted in the diagram below.

![alt text](https://raw.githubusercontent.com/gnunn-gitops/product-catalog/master/docs/img/cicd-flow.png)

To execute the pipelines you will need to create pipelinerun objects, base versions are available in ```manifests/tekton/pipelineruns```. A script is also available at ```scripts/apply-pipelineruns.sh``` to load the client and server pipelineruns however you will need to modify the pipelineruns to reflect your cluster and enterprise registry.

### Enterprise Registry

The demo is used and tested primarily with an enterprise registry, in my case I use quay.io. See the [product-catalog-template](https://github.com/gnunn-gitops/product-catalog-template) for more information on this.

The demo uses the git commit hash to tag the client and server images in the registry, when using quay.io it is highly recommended to deploy the Container Security Operator so that quay vulnerability scans are shown. From a demo perspective, I find showing how older images have more vulnerabilities highlights the benefits of using Red Hat base images.

### Monitoring

A basic monitoring system is installed as part of the demo, as a pre-requisite it requires [monitoring for user-defined projects](https://docs.openshift.com/container-platform/4.6/monitoring/enabling-monitoring-for-user-defined-projects.html) to be enabled in OpenShift.

This demo deploys grafana into the ```product-catalog-monitor``` namespace along with a simple dashboard for the server application. The dashboard tracks JVM metrics as well as API calls to the server, with no load the API call metrics will be flat and that is normal:

![alt text](https://raw.githubusercontent.com/gnunn-gitops/product-catalog/master/docs/img/monitoring.png)

There's a sample siege script that can be used to drive some load if desired under scripts, you will need to update the script to reflect the endpoints in your cluster.
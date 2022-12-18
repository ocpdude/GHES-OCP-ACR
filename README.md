## GHES - OCP - ARC (Azure) Setup

The following outlines the steps used in the YouTube video PART 1 (https://youtu.be/Is_pT4vre-s)
to install GitHub Entperise Server (GHES) via CLI on Azure, along with installing the OpenShift Container Platform (OCP) within
the same vNET, and then configuring the Actions Runner Controller (ARC) for running automation, CICD jobs from GHES via OCP.

-------------
### **GHES Azure Setup**
##### Environment variables used, replace <> with your settings.
    export SUBID=<SUBID>
    export STORAGESA=<STORAGESA>
    export SVC_PRINCIPAL=<SVCPRINCIPAL>
    export LOCATION=<LOCATION>
    export VM_NAME=<VMNAME>
    export DNS_ZONE=<DNSZONE>
    export DNS_GITHUB=<GITHUBHOSTNAME>
    export DNS_RESOURCE_GROUP=<DNSRESGROUP>
    export RESOURCE_GROUP=<GITHUBRESGROUP>
    export OPENSHIFT_RG=<OPENSHIFT_RESOURCE_GROUP>
##### note: To search for available GHES installable versions `az vm image list --all -f GitHub-Enterprise | grep '"urn":' | sort -V`
##### optional: preconfigure your DNS Zone (steps not included in this tutorial)
-------------
1. Create your GHES Resource Group \
    az group create --resource-group `${RESOURCE_GROUP}` --location `${LOCATION}`
    
2. Deploy GHES \
    az vm create -n `${VM_NAME}`  -g `${RESOURCE_GROUP}` --size Standard_E8s_v3 -l `${LOCATION}` \
    --image GitHub:GitHub-Enterprise:GitHub-Enterprise:3.7.2 --storage-sku Premium_LRS --public-ip-sku Standard

3. Add the _required_ second drive for the data disk \
    az vm disk attach --vm-name `${VM_NAME}` -g `${RESOURCE_GROUP}` --sku Premium_LRS --new -z 1024 --name ghe-data.vhd --caching ReadWrite
4. Once completed, you should note the IP address or retrieve it \
    az vm list -d -g `${RESOURCE_GROUP}` -o table
5. Add DNS records for GHES _(optional)_ \
    az network dns record-set a add-record --ttl 600 --resource-group `${DNS_RESOURCE_GROUP}` --zone-name `${DNS_ZONE}` \
    --record-set-name `${DNS_GITHUB}` --ipv4-address <IP_ADRESS>

     az network dns record-set a add-record --ttl 600 --resource-group `${DNS_RESOURCE_GROUP}` --zone-name `*.${DNS_ZONE}` \
    --record-set-name `${DNS_GITHUB}` --ipv4-address <IP_ADRESS>

6. Insert the firewall rules for GHES \
    az network nsg rule create --resource-group `${RESOURCE_GROUP}` --nsg-name `${VM_NAME}NSG` --name HTTPS-Management_console \
    --priority 1010 --destination-address-prefixes '*' --destination-port-ranges 8443 --protocol Tcp

    az network nsg rule create --resource-group `${RESOURCE_GROUP}` --nsg-name `${VM_NAME}NSG` --name SSH-Management_console \
    --priority 1020 --destination-address-prefixes '*' --destination-port-ranges 122 --protocol Tcp

    az network nsg rule create --resource-group `${RESOURCE_GROUP}` --nsg-name `${VM_NAME}NSG` --name HTTPS-End_user \
    --priority 1030 --destination-address-prefixes '*' --destination-port-ranges 443 --protocol Tcp

    az network nsg rule create --resource-group `${RESOURCE_GROUP}` --nsg-name `${VM_NAME}NSG` --name SSH-End_user \
    --priority 1040 --destination-address-prefixes '*' --destination-port-ranges 22 --protocol Tcp

    az network nsg rule create --resource-group `${RESOURCE_GROUP}` --nsg-name `${VM_NAME}NSG` --name SMTP_user \
    --priority 1050 --destination-address-prefixes '*' --destination-port-ranges 25 --protocol Tcp

    az network nsg rule create --resource-group `${RESOURCE_GROUP}` --nsg-name `${VM_NAME}NSG` --name Git-End_user \
    --priority 1060 --destination-address-prefixes '*' --destination-port-ranges 9418 --protocol Tcp

    az network nsg rule create --resource-group `${RESOURCE_GROUP}` --nsg-name `${VM_NAME}NSG` --name HTTP_redirect \
    --priority 1070 --destination-address-prefixes '*' --destination-port-ranges 80 --protocol Tcp

    az network nsg rule create --resource-group `${RESOURCE_GROUP}` --nsg-name `${VM_NAME}NSG` --name High-Availability_tunnel \
    --priority 1080 --destination-address-prefixes '*' --destination-port-ranges 1194 --protocol Udp

7. Add Blob (S3) Storage Container for GitHub Actions _required_ \
    az storage account create --name `${STORAGESA}` --resource-group `${RESOURCE_GROUP}` --location `${LOCATION}` \
    --sku Standard_LRS --encryption-services blob

    az ad signed-in-user show --query id -o tsv | az role assignment create --role "Storage Blob Data Contributor"
    --assignee-object-id @- --assignee-principal-type User --scope "/subscriptions/`${SUBID}`/resourceGroups/`${RESOURCE_GROUP}`/providers/Microsoft.Storage/storageAccounts/`${STORAGESA}`"

    az storage container create --account-name `${STORAGESA}` --resource-group `${RESOURCE_GROUP}` --name ghactions --auth-mode login

8. ~~Pull your Storage Container access key~~ \
    ~~az storage account keys list --resource-group `${RESOURCE_GROUP}` --account-name `${STORAGESA}`~~

### **OpenShift Azure Setup**
The following outlines the steps used in the YouTube video PART 2 ()
### Prereqs
    1. macOS OpenShift Installer : https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-install-mac.tar.gz
    2. macOS OpenShift CLI (oc) : https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-mac.tar.gz
    3. Quota Request for >40 vCPU : https://docs.openshift.com/container-platform/4.11/installing/installing_azure/installing-azure-account.html
    4. Pull-secret from `cloud.redhat.com` : https://console.redhat.com/openshift/install/azure/installer-provisioned 

### Network Considerations
During the demo, I manually created subnets for the OpenShift master and worker nodes to share the same vNET with GitHub Enterprise Server. If you don't do this, you will have to modify the _networking_ section of the install-config.yaml so there is no CIDR conflicts.

## INSTALLATION PROCESS (_installer-provisioned infrastructure_)
1. Create a Service Principal Account \
    az ad sp create-for-rbac --role Contributor --name `${SVC_PRINCIPAL}` --scopes /subscriptions/`${SUBID}`

2. Set permissions for your Service Principal Account \
    az role assignment create --role "User Access Administrator" --assignee-object-id `$(az ad sp list --display-name `${SVC_PRINCIPAL}` | grep id | awk -F\" '{print $4}')`

3. Create your OpenShift Install Config \
    ./openshift-install create cluster --dir=<installation_directory> # accept all defaults \
    ./openshift-install create install-config --dir=<installation_directory> # generate the file only for modification

4. Login with your SPN : _fill in `<PASSWORD>`_ \
    az login --service-principal --username `$(az ad sp list --display-name `${SVC_PRINCIPAL}` | grep appId | awk -F\" '{print $4}')` --password `<PASSWORD>` --tenant `$(az ad sp list --display-name `${SVC_PRINCIPAL}` | grep id | awk -F\" '{print $4}')`

5. Add the NSG rules for OpenShift to GHES vNET _optional_ \
    az network nsg rule create --resource-group `${RESOURCE_GROUP}` --nsg-name `${VM_NAME}NSG` --name OpenShift-API \
    --priority 100 --destination-address-prefixes '*' --destination-port-ranges 6443 --protocol Tcp

    az network nsg rule create --resource-group `${RESOURCE_GROUP}` --nsg-name `${VM_NAME}NSG` --name OpenShift-HTTPS \
    --priority 101 --destination-address-prefixes '*' --destination-port-ranges 443 --protocol Tcp

    az network nsg rule create --resource-group `${RESOURCE_GROUP}` --nsg-name `${VM_NAME}NSG` --name OpenShift-Bootstrap \
    --priority 110 --destination-address-prefixes '*' --destination-port-ranges 22623 --protocol Tcp

6. Associate the OpenShift subnets (ocp-masters & ocp-workers) to NSG \
    az network vnet subnet create -g `${RESOURCE_GROUP}` --vnet-name `${VM_NAME}VNET` -n ocp-masters \
    --address-prefixes 10.0.10.0/24 --network-security-group `${VM_NAME}NSG` 

    az network vnet subnet create -g `${RESOURCE_GROUP}` --vnet-name `${VM_NAME}VNET` -n ocp-workers \
    --address-prefixes 10.0.100.0/24 --network-security-group `${VM_NAME}NSG` 

7. Create your OpenShift Resource Group \
    az group create --resource-group `${OPENSHIFT_RG}` --location `${LOCATION}`

8. Deploy OpenShift on Azure \
    _optional_ - copy your modified install-config.yaml into --dir= \
    ./openshift-install create cluster --dir=<installation_directory>
    
### **OpenShift Actions Runner Controller Setup**
_Multitenancy on OpenShift via GitHub Apps_

 With a few changes we can leverage a single ARC controller-manager across multiple orgazations. A quick prereq is that the controller must be on 
 version 0.26.0+. The initial advantage of this is no having the overhead of multiple controllers and crd's that need to be managed, being our of 
 sync with multiple deployments causes issues with your runner deployments.

 ### Cert-Manager Installation
 Prior to installing ARC, you will need to install and configure cert-manager, this can be done by installing the `cert-manager` operator from the Operator Hub. Once the operator is installed (using the defaults), we will need to setup the private CA cert & key.

 1. Copy your ca.crt & ca.key files locally

 2. Create a SECRET with these files in the openshift-operators namespace \
   `oc create secret tls ca-key-pair --cert=ca.crt --key=ca.key`

 3. I chose to provide acces to the cluster by creating a kind ClusterIssuer
   ```
     kind: ClusterIssuer
     apiVersion: cert-manager.io/v1
     metadata:
       name: redcloud-clusterissuer
     spec:
       selfSigned:
         ca:
           secretName: ca-key-pair
 ```

 #### Actions Runner Controller Install
 1. If this is your initial deployment just instal 0.26.0 \
 `kubectl replace --force -f https://github.com/actions/actions-runner-controller/releases/download/v0.26.0/actions-runner-controller.yam` \

     [Notes](#Troubleshooting) - If you are upgrading to multitenancy, you must remove all of your runnerdeployments and horizontalrunnerautoscale 
     deployments prior to upgrading. Not doing this could cause your reinstall to hang and fail. Additionaly, we use the "replace --force" to install the 
     controller on OCP or it'll complain _"metadata.annotations: Too long: must have at most 262144 bytes"


 2. When deploying the solution for a GHES environment you need to provide an additional environment variable as part of the controller deployment \
 `kubectl set env deploy controller-manager -c manager GITHUB_ENTERPRISE_URL=https://${YOUR_GHES_SERVER} --namespace actions-runner-system`

 3. Set _privileged_ access \
 `oc adm policy add-scc-to-user privileged -z default -n actions-runner-system`

 4. Create a PAT using an Admin that has access to the orgs you'll be deploying ARC into. \
     admin:org, admin:org_hook, notifications, read:public_key, read:repo_hook, repo, workflow

 5. Set the controller-manager secret using this PAT \
     `oc create secret generic controller-manager  --from-literal=github_token=${GITHUB_TOKEN}`

 6. Each Organzation will require it's own GitHub App \
     Replace the ${PARTS} of the following URL with your GHES address & org name before opening it. 
     Then enter any unique name in the "GitHub App name" field, and hit the "Create GitHub App" button at the bottom of the page to create a GitHub App.

     `https://${YOUR_GHES_SERVER}/organizations/${YOUR_ORG}/settings/apps/new?url=http://github.com/actions/actions-runner-controller&webhook_active=false&public=false&administration=write&organization_self_hosted_runners=write&actions=read&checks=read`

     You will see an App ID on the page of the GitHub App you created as follows, the value of this App ID will be used later.

 7. Download the private key file by pushing the "Generate a private key" button at the bottom of the GitHub App page. This file will also be used later.

 8. Go to the "Install App" tab on the left side of the page and install the GitHub App that you created for your account or organization.

 9. Register the App ID `${APP_ID}`, Installation ID `${INSTALLATION_ID}`, and the downloaded private key file `${PRIVATE_KEY_FILE_PATH}` to OpenShift as a secret.
     ```
     $ kubectl create secret generic org1-github-app \
         -n actions-runner-system \
         --from-literal=github_app_id=${APP_ID} \
         --from-literal=github_app_installation_id=${INSTALLATION_ID} \
         --from-file=github_app_private_key=${PRIVATE_KEY_FILE_PATH}
     ```
 10. You'll now call out org1-github-app in your manifests for RunnerDeployment and HorizonalRunnerAutoscaler
       ```
       Example:
       ---
       kind: RunnerDeployment
       metadata:
         namespace: org1-runners
       spec:
         template:
           spec:
             githubAPICredentialsFrom:
               secretRef:
                 name: org1-github-app
       ---
       kind: HorizontalRunnerAutoscaler
       metadata:
         namespace: org1-runners
       spec:
         githubAPICredentialsFrom:
           secretRef:
             name: org1-github-app
       ```
  👉 Repeat for each Org GitHub App (RunnerDeployment/HorizontalRunnerAutoscaler)

 --------

 #### Troubleshooting
 1. You upgraded to 0.26.0 without removing your deployments beforehand and the removal has hung.
     If your pods are in a 'Terminating' state, select the pod, switch to YAML and then remove finalizsers, save and move to the next pod. This should
     remove them one-by-one.
 2. During the replace phase, your upgrade stops deleting CRD's.
     Search your CRD's for runners \
     `oc get crd | grep runner`
     Edit the CRD and remove the finalizers, when you save/exit the CRD will be removed and the install should complete.
 3. Images used in this demo:
    * docker.io/shaker242/podman-runner:1206.1
    * docker.io/shaker242/default-runner:1203.2


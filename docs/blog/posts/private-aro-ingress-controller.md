---
draft: false
title: Setup public Ingress Controller to private ARO cluster
summary: On this exercise, we will deploy an additional Ingress Controller to make application ingress available to the internet.
authors:
    - Hevellyn
date:
  created: 2024-06-16
  updated: 2024-12-02
categories:
  - ARO
slug: public-ingresscontroller-aro-private
tags:
  - aro, azure, ingresscontroller, openshift
---
On this exercise, we will deploy an additional Ingress Controller to make application ingress available to the internet.
<!-- more -->

## Environment

- Private ARO cluster (v4.12), with both `apiserver-visibility` and `ingress-visibility` set to **Private**.
```
az aro create --resource-group $RESOURCEGROUP --name $CLUSTER --vnet aro-vnet --master-subnet master-subnet --worker-subnet worker-subnet --apiserver-visibility Private --ingress-visibility Private --pull-secret @pull-secret.txt
```

- A "jumphost" VM  inside same cluster resource group.

- A DNS domain with hosting.

#### If Ingress is Public

If Ingress visibility is Public, then make sure to add the proper sharding to the **default** IngressController, otherwise, all requests will be routed to it.
- About shards, [here](https://docs.redhat.com/en/documentation/openshift_container_platform/4.16/html-single/networking/index#nw-ingress-sharding-concept_configuring-ingress-cluster-traffic-ingress-controller)

## Setup 

### The jumphost
1.  Create a virtual machine:
```
az vm create --resource-group $RESOURCEGROUP --zone 1 --name 'hevs-jumphost' --image 'RedHat:RHEL:8-lvm-gen2:latest' --admin-username 'azureuser' --generate-ssh-keys --size 'Standard_D2s_v3'
``` 
2. Access the virtual machine via Azure Portal:
- Either using  the web feature **SSH using Azure CLI** which, quickly connect via the browser; Or any preferred method.
- OR habilitate the 22 Port via the UI, and using the Public IP provided, access using your private key.
```
ssh -i ~/.ssh/id_rsa azureuser@<publicIP>
```
???+ note
    Make sure to assign permission 400 to the key. `chmod 400 ~/.ssh/id_rsa`

3. Once inside the vm, download the `oc` client and add to path; **oc** client mirror, to download, [here](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/).
```
$ wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/<path>.tar.gz
$ tar -xf <file>.tar.gz
$ sudo cp oc /usr/bin/oc
```

4. From the Azure Portal, in the `Azure Red Hat OpenShift` service, select the cluster, and in **Connect** to get the **kubeadmin** and password, as well the Cluster API. Then from the vm:
```
$ oc login -u kubeadmin -p $PASSWORD --server $APIserverURL
```

### Creating the application
- For `hostname`, use the domain that you want to be used by the application.
```
oc new-project demo-application
oc new-app --docker-image=docker.io/openshift/hello-openshift
oc expose svc hello-openshift --hostname example.hevshow.dns-dynamic.net
```

???+ note
    Got a free DNS domain and hosting in [Cloudns.net](https://www.cloudns.net/) : `hevshow.dns-dynamic.net`

### Creating the Ingress Controller

Created a `Ingress Controller` named `public-ingress`, setting as the domain the same as what was my route, and added a `routerSelector` for my application, and the `loadBalancer.scope: External`
```
spec:
  domain: example.hevshow.dns-dynamic.net
  routeSelector:
    matchLabels:
      app: hello-openshift
  endpointPublishingStrategy:
    loadBalancer:
      scope: External
    type: LoadBalancerService
```

- Once the IC is created, pods and services in the project `openshift-ingress` will be created.
```
oc get svc,pod -n openshift-ingress

NAME                                  READY   STATUS    RESTARTS   AGE
pod/router-public-ingress-979d5c5bb-dpx59     1/1     Running   0          66m
pod/router-public-ingress-979d5c5bb-vzjfg     1/1     Running   0          66m

NAME                                        TYPE           CLUSTER-IP       EXTERNAL-IP       PORT(S)                      AGE
service/router-public-ingress             LoadBalancer   172.30.35.87     108.141.255.176   80:32484/TCP,443:31682/TCP   66m
service/router-internal-public-ingress    ClusterIP      172.30.131.160   <none>            80/TCP,443/TCP,1936/TCP      66m
```

???+ note
    Take note of the `EXTERNAL-IP` for the SVC of Load Balancer type, and set as the IP for the A record in the DNS provider. `*.hevshow.dns-dynamic.net A 172.30.35.87`

## Test the Application 🚀

And voila, application is reachable for the internet!
```
$ curl example.hevshow.dns-dynamic.net  
Hello OpenShift!
```

## Extra - Troubleshooting 🕵🏻

Check IP source
```
nslookup example.hevshow.dns-dynamic.net
```

Resolves the domain using the Public IP from IC. (Use port 80 if 'http', 443 if 'https')
```
curl --resolve example.hevshow.dns-dynamic.net:80:$IP http://example.hevshow.dns-dynamic.net --verbose
```


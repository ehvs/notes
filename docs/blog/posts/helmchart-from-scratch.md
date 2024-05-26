---
draft: false
title: Helmchart from scratch using OpenShift local
summary: On this exercise, we will deploy from scratch an application using Helm Chart.
authors:
    - Hevellyn
date:
  created: 2024-05-25
  updated: 2024-05-25
categories:
  - Labs
slug: helmchart-from-scratch
tags:
  - crc, helmchart, openshift
---
On this exercise, we will deploy an application from scratch using Helm Chart.
<!-- more -->

## Environment & Pre-requisites

- Helm Chart [docs](https://helm.sh/docs/)

### Used binaries
```
CRC version: 2.36.0+27c493
OpenShift version: 4.15.12
Podman version: 4.4.4
helm version:
version.BuildInfo{Version:"v3.13.2+35.el9", GitCommit:"fa6e939d7984e1be0d6fbc2dc920b6bbcf395932", GitTreeState:"clean", GoVersion:"go1.20.12"}
```

### Setup registry authentication 
If using OpenShift, it is necessary to update the pullsecret in the cluster with the necessary registry authentication.
To verify:
```
❯ oc get secret/pull-secret -n openshift-config --template='{{index .data ".dockerconfigjson" | base64decode}}'
```

##  Starting with helm

1. With `helm create` generate the directory with the required structure to start using Helm.
```
❯ helm create mynginx
❯ tree mynginx
mynginx
├── charts -> empty by default. Used for adding dependent charts
├── Chart.yaml
├── templates -> Configuration files that deploys in the cluster
│   ├── deployment.yaml
│   ├── _helpers.tpl
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── NOTES.txt
│   ├── serviceaccount.yaml
│   ├── service.yaml
│   └── tests
│       └── test-connection.yaml
└── values.yaml

4 directories, 10 files
``` 

2. Modify the `values.yaml` to contain the deployment definitions like image, serviceaccount, service port.
```
repository: nginx

service:
  type: ClusterIP
  port: 80

serviceAccount:
  name: "sa-nginx"
```

3. Deploy the application with `helm install`.
```
❯ helm install mynginx-chart mynginx/ --values mynginx/values.yaml
NAME: mynginx-chart
LAST DEPLOYED: Sat May 25 12:56:37 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=mynginx,app.kubernetes.io/instance=mynginx-chart" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod --namespace default $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace default port-forward $POD_NAME 8080:$CONTAINER_PORT
```

4. Verify that the pod is running 
    ```
    ❯ oc get pods
    NAME                                       READY   STATUS    RESTARTS   AGE
    mynginx-chart-mynginx-664dfbb4b4-r7xqq   1/1     Running   0          13s
    ```

5. Expose the application service, and `curl` the route to verify if is up and running.
    ```
    ❯ oc expose svc mynginx-chart-mynginx
    route.route.openshift.io/mynginx-chart-mynginx exposed
    ❯ oc get route
    NAME                      HOST/PORT                                          PATH   SERVICES                  PORT   TERMINATION   WILDCARD
    mynginx-chart-mynginx   mynginx-chart-mynginx-default.apps-crc.testing          mynginx-chart-mynginx   http                 None

    ❯ curl -s -o /dev/null -w "remote_ip: %{remote_ip}\nremote_port: %{remote_port}\nresponse_code: %{response_code}\n" http://$ROUTE_NAME
    remote_ip: 192.168.130.11
    remote_port: 80
    response_code: 200
    ```

## Updating the deployment
To update a current deployment from helmchart it is used `helm upgrade`, using that command there are some different ways ([documented here](#)), for this example we will modify the `service.type` to use `NodePort` by modifying the `values.yaml`


1. After modified, list the current releases (**must be ran inside the project context**)
???+ note
    Release is an instance of a chart running in a Kubernetes cluster

    ```
    ❯ helm list
    NAME         	NAMESPACE	REVISION	UPDATED                                 	STATUS  	CHART          	APP VERSION
    mynginx-chart	default  	1       	2024-05-25 12:56:37.733458796 +0200 CEST	deployed	mynginx-0.1.0	1.16.0 
    ```

2. Apply the modification.
```
❯ helm upgrade -f mynginx/values.yaml mynginx-chart mynginx/
Release "mynginx-chart" has been upgraded. Happy Helming!
NAME: mynginx-chart
LAST DEPLOYED: Sat May 25 13:57:55 2024
NAMESPACE: default
STATUS: deployed
REVISION: 2
NOTES:
1. Get the application URL by running these commands:
  export NODE_PORT=$(kubectl get --namespace default -o jsonpath="{.spec.ports[0].nodePort}" services mynginx-chart-mynginx)
  export NODE_IP=$(kubectl get nodes --namespace default -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
```

3. Inspect the release list and history of each release.
```
❯ helm list
NAME         	NAMESPACE	REVISION	UPDATED                                 	STATUS  	CHART          	APP VERSION
mynginx-chart	default  	2       	2024-05-25 13:57:55.817936502 +0200 CEST	deployed	mynginx-0.1.0	1.16.0 

❯ helm history mynginx-chart
REVISION	UPDATED                 	STATUS    	CHART          	APP VERSION	DESCRIPTION     
1       	Sat May 25 12:56:37 2024	superseded	mynginx-0.1.0	1.16.0     	Install complete
2       	Sat May 25 13:57:55 2024	deployed  	mynginx-0.1.0	1.16.0     	Upgrade complete
```

4. Validate that the pod is running, and because we are using nodePort using *CRC/OpenShift local*, due to limitations, we can only access via `port-forward`. Open a new terminal, or access via browser `127.0.0.1:32362`.
```
❯ oc port-forward svc/mynginx-chart-mynginx 32362:80
Forwarding from 127.0.0.1:32362 -> 80
Forwarding from [::1]:32362 -> 80
Handling connection for 32362
```
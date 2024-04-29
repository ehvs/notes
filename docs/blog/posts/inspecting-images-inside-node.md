---
title: Application using images from the internal registry
summary: On this exercise, we will deploy an application, tag and push a new version of the image to the Internal Registry, find where the image is hosted and patch the deployment to use the new image.
authors:
    - Hevellyn
date:
  created: 2024-04-29
  updated: 2024-04-29
categories:
  - Labs
slug: images
tags:
  - podman, images, internal registry
---
On this exercise[^1], we will deploy an application, tag and push a new version of the image to the Internal Registry, find where the image is hosted and patch the deployment to use the new image.
<!-- more -->

[^1]: This exercise was particularly interesting because it was how I was able to test and reproduce a bug once. 

### Steps
- Exposing the registry
- Application deployment
- Finding image inside the node
- Tagging and pushing an image to the internal registry
- Patching deployment image

#### 1. Exposing the registry
- Patch the Image Registry
```
 oc patch config.imageregistry.operator.openshift.io/cluster --patch='{"spec":{"defaultRoute":true}}' --type=merge
 oc patch config.imageregistry.operator.openshift.io/cluster --patch='[{"op": "add", "path": "/spec/disableRedirect", "value": true}]' --type=json
```

- Take note of the registry route:
```
 oc get route -n openshift-image-registry default-route --template='{{ .spec.host }}'
```

#### 2. Application deployment
- This example will use an image that assumes authentication to Red Hat registry, but any other image can be used.
```
oc apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: new-default-deploy
    app.kubernetes.io/component: new-default-deploy
    app.kubernetes.io/instance: new-default-deploy
    app.kubernetes.io/part-of: new-default-deploy
    app.openshift.io/runtime: redhat
  name: new-default-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: new-default-deploy
    type: Recreate
  template:
    metadata:
      labels:
        app: new-default-deploy
        deploymentconfig: new-default-deploy
    spec:
      containers:
      - image: registry.access.redhat.com/ubi8/ubi:latest
        imagePullPolicy: Always
        name: new-default-deploy
        command:
        - /bin/sh
        - -c
        - |
          sleep infinity
        resources: {}
EOF
```

#### 3. Finding image inside the node
- Inspect in which node the pod is hosted
```
$ oc get pods -o wide
NAME                                  READY   STATUS    RESTARTS   AGE    IP           NODE                                                NOMINATED NODE   READINESS GATES
new-default-deploy-786d477969-thcqt   1/1     Running   0          5m8s   10.128.2.6   hgomes-default-lab-grxh8-worker-westeurope3-xqdss   <none>           <none>
```

- Inspect the node where the image is hosted.
```
$ oc debug node/hgomes-default-lab-grxh8-worker-westeurope3-xqdss
sh-4.4# chroot /host
sh-5.1# podman images | grep ubi
registry.access.redhat.com/ubi8/ubi             latest              179275e28757  3 days ago    213 MB
sh-5.1# crictl images | grep ubi
registry.access.redhat.com/ubi8/ubi              latest               179275e28757e       213MB
```

#### 4. Tagging and pushing an image to the internal registry
- Take note of your user token
```
oc whoami -t
```

- Tagging and pushing image to the internal registry.
> Use the exposed route to tag and push
```
sh-5.1# podman login -u myuser -p <token>
Login Succeeded!
sh-5.1# podman tag registry.access.redhat.com/ubi8/ubi:latest default-route-openshift-image-registry.apps.hhmkrp84.westeurope.aroapp.io/new-default-app/ubi8:latest
sh-5.1# podman push default-route-openshift-image-registry.apps.hhmkrp84.westeurope.aroapp.io/new-default-app/ubi8:latest --remove-signatures
```
#### 5. Patching the deployment to use a new image
- Patch command to add the image recently pushed to the internal registry.
```
oc patch deployment new-default-deploy -p '{"spec":{"template":{"spec":{"containers":[{"name":"new-default-deploy","image":"default-route-openshift-image-registry.apps.hhmkrp84.westeurope.aroapp.io/new-default-app/ubi8:latest"}]}}}}
```

- New pod running in the same node with the new image:
```
oc get deployment -o wide
NAME                 READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS           IMAGES                                                                                                  SELECTOR
new-default-deploy   1/1     1            1           14m   new-default-deploy   default-route-openshift-image-registry.apps.hhmkrp84.westeurope.aroapp.io/new-default-app/ubi8:latest   app=new-default-deploy
```
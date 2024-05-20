---
draft: false
title: Building the memcached-operator with podman and OCP
summary: Known issues when building the example operator with podman in OpenShift
authors:
    - Hevellyn
date:
  created: 2024-05-20
  updated: 2024-05-20
categories:
  - Labs
slug: operator-sdk
tags:
  - operator-sdk,podman,ocp
---
On this exercise we will go through the issues that I found while trying the example mem-cached operator.
<!-- more -->
On this exercise we will go through the issues that I found while trying the example mem-cached operator.
I used the steps from [Operator-SDK page](https://sdk.operatorframework.io/docs/building-operators/golang/tutorial) and hit issues caused by myself. 🙂
This post is not a step by step from the Tutorial, but how I fixed the issues that I hit.

## Pre-requisites
Original instructions for installations => [here](https://sdk.operatorframework.io/docs/installation/). But from my testing, at this time of writing were:
- Binaries
```
$ go version
go version go1.21.10 linux/amd64

$ operator-sdk version
operator-sdk version: "v1.34.2", commit: "81dd3cb24b8744de03d312c1ba23bfc617044005", kubernetes version: "1.28.0", go version: "go1.21.10", GOOS: "linux", GOARCH: "amd64"

$ oc version
Client Version: 4.13.18

$ podman version
Client:       Podman Engine
Version:      4.9.4
API Version:  4.9.4
Go Version:   go1.21.8
Built:        Tue Mar 26 10:41:56 2024
OS/Arch:      linux/amd64
```

- Environment
```
OpenShift 4.14.X
Fedora 38
```

### Issue: "Working with personal/private registries"
- Do podman login to docker.io
```
podman login -u $USER -p "$PASSW" docker.io
```
- Update secret from the cluster with the docker.io credentials
``` 
oc get secret/pull-secret -n openshift-config --template='{{index .data ".dockerconfigjson" | base64decode}}' > ocp-pullsecret.json
oc registry login --registry=docker.io --auth-basic="$USER:$PASSW" --to=ocp-pullsecret.json
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=ocp-pullsecret.json
```

### Issue: `Back-off pulling image "controller:latest"`
Hit back-off pulling image issues, because I mistakenly skipped the [step](https://sdk.operatorframework.io/docs/building-operators/golang/tutorial/#configure-the-operators-image-registry) to **Setup the Operator Registry**
```
pod/memcached-operator-controller-manager-6d57548c9f-fdh67    Back-off pulling image "controller:latest"
Failed to pull image "controller:latest": rpc error: code = Unknown desc = reading manifest latest in docker.io/library/controller: requested access to the resource is denied
```
- Solution:
In the file `Makefile`, set your own registry so the image can be built and pushed automatically to your registry, and then pulled inside the cluster. Eg:
```
IMG = docker.io/songbird159/controller:latest
```

### Issue: `docker: command not found`
Podman have all the equivalent functions as docker, simply use podman to run :)
```
make podman-build podman-push
```

### Issue: `No rule to make target 'podman-build'`
This happens because in the `Makefile` it is still pointing to be used docker-* commands, not podman.
```
make podman-build podman-push Makefile
make: *** No rule to make target 'podman-build'.  Stop.
```
- Solution: Replace all docker references to **podman**. There are about 11 references.
```
CONTAINER_TOOL ?= podman
.PHONY: podman-build
podman-build: ## Build docker image with the manager.

.PHONY: podman-push
podman-push: ## Push docker image with the manager.

.PHONY: podman-buildx
podman-buildx:

.PHONY: bundle-build
bundle-build: ## Build the bundle image.
	podman build -f bundle.Dockerfile -t $(BUNDLE_IMG) .

.PHONY: bundle-push
bundle-push: ## Push the bundle image.
	$(MAKE) podman-push IMG=$(BUNDLE_IMG)

catalog-build: opm ## Build a catalog image.
	$(OPM) index add --container-tool podman --mode semver --tag $(CATALOG_IMG) --bundles $(BUNDLE_IMGS) $(FROM_INDEX_OPT)

.PHONY: catalog-push
catalog-push: ## Push a catalog image.
	$(MAKE) podman-push IMG=$(CATALOG_IMG)
```

## Voila!

```
❯ oc get events --sort-by='{.lastTimestamp}'
Successfully pulled image "docker.io/songbird159/controller:latest" in 3.862300324s (3.86231446s including waiting)

❯ oc get pods -n memcached-operator-system
NAME                                                     READY   STATUS    RESTARTS   AGE
memcached-operator-controller-manager-6d889bb7dd-j4d8q   2/2     Running   0          30m

❯ podman images
REPOSITORY                                      TAG         IMAGE ID      CREATED         SIZE
docker.io/songbird159/controller                latest      4676737e0f28  51 minutes ago  55.4 MB
```
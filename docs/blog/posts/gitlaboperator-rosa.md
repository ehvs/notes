---
draft: false
title: Setup Gitlab Operator in ROSA
summary: On this exercise, we will deploy the Operator and setup the instance.
authors:
    - Hevellyn
date:
  created: 2024-05-26
  updated: 2024-05-26
categories:
  - Labs
slug: gitlab-operator-in-tosa
tags:
  - gitlab, operators, aws, openshift
---
On this exercise, we will deploy the Operator and setup the Gitlab instance. 
<!-- more -->

This setup took me a while to figure out the missing pieces, but it was fun to go through and make it minimally working (It is using self-signed certificates).

## Environment
```
Red Hat OpenShift in AWS version: 4.14.25
Community cert-manager operator version: 1.14.2 
Gitlab Operator version 1.0.0
Gitlab chart version: 8.0.0
```

## Install the Operator and setup the CR

0. Create the Ingress Class for Nginx.
``` { .yaml .annotate }
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  # Ensure this value matches `spec.chart.values.global.ingress.class`
  # in the GitLab CR on the next step.
  name: gitlab-nginx
spec:
  controller: k8s.io/ingress-nginx
```
1. Install the Gitlab Operator **Certified** version from Operator Hub.
2. The custom resource (CR) for Gitlab.
``` { .yaml .annotate }
apiVersion: apps.gitlab.com/v1beta1
kind: GitLab
metadata:
  name: gitlab
  namespace: gitlab-system
spec:
  chart:
    values:
      certmanager:
        install: false
      global:
        hosts:
          domain: apps.$BASEDOMAIN
          hostSuffix: null
        ingress:
          class: gitlab-nginx
          configureCertmanager: false
          tls:
            secretName: wildcard-gitlab-tls
    version: 8.0.0
```

???+ note
    Once the Gitlab instance is created, all deployments/Ingress/services will be deployed, but the Ingress Controllers will be missing.
    To fix that, apply the RBAC and SCC required and provided by Gitlab repository.
    `oc apply -f https://gitlab.com/api/v4/projects/18899486/packages/generic/gitlab-operator/1.0.0/gitlab-operator-kubernetes-1.0.0.yaml`

Wait some minutes so the operator can reconcile.

4. In AWS  Route 53, in both Private and Public Hosted Zones, create the record:
    - Record name: gitlab.apps.$BASEDOMAIN
    - Value: The $EXTERNAL_IP from the service `gitlab-nginx-ingress-controller`
    - Type: CNAME

5. Voila! 🚀 Our self-served Gitlab instance is up and running!
Login to the UI. Username `root`, and the password can be fetched in the secret `gitlab-gitlab-initial-root-password`:
```
oc get secret/gitlab-gitlab-initial-root-password -n gitlab-system --template='{{index .data "password" | base64decode}}'
```


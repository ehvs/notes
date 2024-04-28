---
title: PromQL expressions for K8S
summary: PromQL expressions to find out specific informaiton
authors:
    - Hevellyn
date: 2024-04-28
categories:
  - Monitoring
slug: promql,monitoring,prometheus
tags:
  - promql
  - monitoring
  - prometheus
---

 A set of PROMQL expressions that has been the most useful for me.

<!-- more -->

- What node got into *Not Ready* status?
```
kube_node_status_condition{condition="Ready",status!="true"}
```

- How many containers runs in a pod? The `~` works as a `*` wildcard/regex.
```
kube_pod_container_info{cluster="", namespace="<project-name>",pod=~"<pod-name>"}
```


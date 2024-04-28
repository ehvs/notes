---
title: JQ Oneliners
summary: A document with oneliners using JQ
authors:
    - Hevellyn
date: 2024-04-02
categories:
  - Cheatsheet
slug: jq-oneliner
tags:
  - JQ
---

 A set of oneliners that has been the most useful for me.

<!-- more -->

# JQ

[jq](https://jqlang.github.io/jq/manual/) is like sed for JSON data.

- ### Listing an array of AWS instances from `providerID` + node name + labels

=== "Oneliner"

    ``` sh
    for i in {i-001,i-002}; do jq -r --arg i "$i" '.items[] | select(.spec.providerID | contains($i)) | {node: $i, hostname: .metadata.labels."kubernetes.io/hostname", roles: .metadata.labels | with_entries(select(.key | test("^node-role.kubernetes.io")))}' my-nodes.json ; done
    ```

=== "Idented"

    ``` sh
    for i in {i-001,i-002}; do
    jq -r --arg i "$i" '
        .items[] |
        select(.spec.providerID | contains($i)) |
        {
            node: $i,
            hostname: .metadata.labels."kubernetes.io/hostname",
            roles: .metadata.labels | with_entries(select(.key | test("^node-role.kubernetes.io")))
        }
    ' my-nodes.json
    done
    ```

Output:
```
{
  "node": "i-001",
  "hostname": "ip-10-001-002-34.eu-west-1.compute.internal",
  "roles": {
    "node-role.kubernetes.io": "infra",
    "node-role.kubernetes.io/infra": "",
    "node-role.kubernetes.io/worker": ""
  }
```

- Breakdown explanation

    - `test`: This is a jq function that tests if a string matches a regular expression pattern.
    - `"^node-role.kubernetes.io"`: This is the regular expression pattern that specifies the string to match. In this case, ^ matches the start of the string, and node-role.kubernetes.io is the pattern we want to match.

When applied to each key in the labels object, `test("^node-role.kubernetes.io")` returns true if the key matches the pattern `"^node-role.kubernetes.io"` (i.e., if the key starts with "node-role.kubernetes.io"), and false otherwise.

This filter function is used to select only the keys in the labels object that start with `node-role.kubernetes.io`, effectively filtering out other keys. This allows us to extract only the labels related to node roles from the labels object.





- ### Get specific fields values from multiple containers inside a pod
=== "Oneliner"
    ``` sh
    oc get pods -o json | jq ".items[] | { pod_name: .metadata.name, containers: ( .spec.containers[].resources | { requests } ) }"
    ```
=== "Idented"

    ``` sh
    oc get pods -o json | jq '
    .items[] |
    {
        pod_name: .metadata.name,
        containers: (
            .spec.containers[].resources |
            {
                requests
                }
            )
        }
    '
    ```

Output:
```
{
  "pod_name": "logging-loki-gateway-68d8b7744b-qvlw6",
  "containers": {
    "requests": {
      "cpu": "500m",
      "memory": "500Mi"
    }
  }
}
{
  "pod_name": "logging-loki-gateway-68d8b7744b-qvlw6",
  "containers": {
    "requests": null
```

- ### Extract all unique "usernames" from a json file.
``` 
cat data.json | jq .user.username -r | sort | uniq -c | sort -n
```
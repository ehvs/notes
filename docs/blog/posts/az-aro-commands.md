---
title: The AZ show
summary: Helpful az commands
authors:
    - Hevellyn
date: 2024-09-12
updated: 2024-10-31
categories:
  - ARO
slug: az-aro-commands
tags:
  - az, aro, cli, cheatsheet
---

Some helpful `az` commands to inspect the cluster information.
<!-- more -->

###  Resource Groups
There are two resource group for ARO:

- CLUSTER Resource Group: Can be any name, and it is created by the user.

- MANAGED Resource Group: The name has the following convention `aro-xxx`, and hosts resources like:
    - The storageaccount, disks, load balancers, virtual machines.
    - It is protected with `Deny Assignment`, to ensure that won't be tampered by the user.

#### How to find out the ARO 'managed' resource group.

##### Method 1

```
MANAGED_RG="aro-$(az aro show -n $CLUSTERNAME -g $CLUSTER_RESOURCEGROUP --query 'clusterProfile.domain' -o tsv)"; echo $MANAGED_RG
```

##### Method 2

1. Get the ARO cluster `RESOURCEID`, exporting as variable:
```
RESOURCEID=$(az aro show -n $CLUSTERNAME -g $CLUSTER_RESOURCEGROUP --query 'id' -o tsv) ; echo $RESOURCEID
```

2. Get the **Managed** Resource Group, exporting in a variable
```
MANAGED_RG=$(az group list --query "[?managedBy=='$RESOURCEID'].name" -o tsv) ; echo $MANAGED_RG
```

##### Method 3
Alternatively, the full JSON response:
```
az group list --query "[?managedBy=='$RESOURCEID']"
```

### Storage Accounts
#### Storage Lockdown
Check if Storage Lockdown is enabled for Storage Account Cluster and Image Registry (this is set by default). `AllowBlobPublicAccess` must be set to **false**. This is a default Azure [feature](https://azure.microsoft.com/en-us/updates/choose-to-allow-or-disallow-blob-public-access-on-azure-storage-accounts/).

```
az storage account list -g $MANAGED_RG --query "[].{NAME:name, AllowBlobPublicAccess:allowBlobPublicAccess,MinimumTlsVersion:minimumTlsVersion}" -o table
```

### Networking
#### Public or Private?

- API and Ingress
```
az aro show -n $CLUSTERNAME -g $CLUSTER_RESOURCEGROUP --query='{api:apiserverProfile.visibility,ingress:ingressProfiles[*].{name: name,visibility: visibility}}'
```

- Did I set UDR (UserDefinedRouting)?
```
az aro show -n $CLUSTERNAME -g $CLUSTER_RESOURCEGROUP --query 'networkProfile.outboundType'
```

### Service Principal

- What is the ServicePrincipal attached to my cluster?
```
az aro show -n $CLUSTERNAME -g CLUSTER_RESOURCEGROUP --query 'servicePrincipalProfile.clientId' -o tsv
```
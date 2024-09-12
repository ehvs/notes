---
title: AZ commands to help with ARO investigation
summary: Helpful az commands
authors:
    - Hevellyn
date: 2024-09-12
categories:
  - ARO
slug: az-aro-commands
tags:
  - az, aro, cli, cheatsheet
---

ARO (Azure Red Hat OpenShift) is a managed offer based on Azure as infrastructure, therfore from time to time some debugging on the infrastructure is needed.

<!-- more -->



###  **Resource Groups**
#### How to find out the ARO managed resource group.
ARO requires a user-created `resourcegroup` and for the managed side, it will create the reserved `aro-xxxx` resource group which will contain deny-assignments to ensure that configurations are not tampered.

1. Get the ARO cluster ResourceID, exporting as variable (Replace `CLUSTERNAME` and `RESOURCEGROUP` accordingly):
```
RESOURCEID=$(az aro show -n $CLUSTERNAME -g $RESOURCEGROUP --query 'id' -o tsv) ; echo $RESOURCEID
```

2. Get the **Managed** Resource Group, exporting as in a variable
```
MANAGED_RG=$(az group list --query "[?managedBy=='$RESOURCEID'].name" -o tsv) ; echo $MANAGED_RG
```

or the full JSON response
```
az group list --query "[?managedBy=='$RESOURCEID']"
```

### **Storage Accounts**
#### Storage Lockdown
Check if Storage Lockdown is enabled for Storage Account Cluster and Image Registry (this is set by default). `AllowBlobPublicAccess` must be set to **false**. This is a default Azure [feature](https://azure.microsoft.com/en-us/updates/choose-to-allow-or-disallow-blob-public-access-on-azure-storage-accounts/).

```
az storage account list -g $MANAGED_RG --query "[].{NAME:name, AllowBlobPublicAccess:allowBlobPublicAccess,MinimumTlsVersion:minimumTlsVersion}" -o table
```

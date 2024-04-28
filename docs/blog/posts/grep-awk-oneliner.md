---
title: Parsing messages with grep and awk
summary: Filters with grep and awk
authors:
    - Hevellyn
date: 2024-04-02
categories:
  - Cheatsheet
slug: grep-awk-filters
tags:
  - grep, awk
---

When handlind hundreds of log files for inspection, knowing how to use grep to parse and find the relevant errors saves a lot of time. I usually use grep for that, and in this note, I've saved some awk notes.

<!-- more -->


## GREP

- Returns all the directories that "message" appears.
```
egrep "message" -rc * 2>/dev/null | grep -v :0
```

- Grep by time and "message".
```
cat journalblah.txt | grep 'Sep 20 23:' | grep 'message' | tail -n 1
cat journalblah.txt | grep 'Sep 20' | grep 'message' | wc -l
```

## AWK

```
'{}' = Action Block
NR = Number of Records (built-in variable) ---> Used to specify the line number of a set of text
```

### Examples
- Assign variable to awk capture of word
```
adjetivo=`awk -v number=$number 'NR==number{ print $1 }' $file_adjetivos`
```
- FOR loop to interact with 2 columns of values as variables
```
count=$(wc -l list-audit.log)
for i in {1..$count}; do node=`awk -v i=$i 'NR==i { print $1}' list-audit.log` ; file=`awk -v i...audit.log`; oc adm node-logs $node --path=oauth-apiserver\/$file > $node_$file.txt ; done
```
- Arrays + awk
```
declare -a arr=() ; for i in $(oc get nodes --no-headers | awk '{print $1}'); do arr+=( "$i"); echo $i ; done
declare -a arr=() ; for i in $(oc get nodes --no-headers | awk '{print $1}'); do arr+=( "$i"); oc get nodes $i -o custom-columns=NAME:.metadata.name ; done
```
- Filtering by field
```
$ awk -F "|" '$5 < 4000 ' file.txt
OR
$ awk -F "|" -v low_salary="4000" '$5 < low_salary ' file.txt
$ awk -F "|" -v low_salary="4000" '$5 < low_salary { print $4 } ' file.txt
OR
awk -F "|" -v low_salary="4000" -v high_salary=4500 -v header="------my header-------" 'BEGIN { print header } $5 >= high_salary || $5 <= low_salary { print $2, $5}' pipe_example.txt

08|garca|branca|branca_a_garca@gmail.com|1000
09|micael|o gato|micael@gmail.com|2000

/// file.txt
06|amazonia|mosquiteira|am_mosquiteira@gmail.com|4500
07|jacare|pantanoso|pantanoso@gmail.com|4000
08|garca|branca|branca_a_garca@gmail.com|1000
09|micael|o gato|micael@gmail.com|2000
```
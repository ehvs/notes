---
title: Git rebase and amend
summary: Using commands git rebase and amend
authors:
    - Hevellyn
date: 2024-07-23
categories:
  - Cheatsheet
slug: git-rebase-amend
tags:
  - git, branches, rebase, amend
---

When handling dozens of different branches in a Git repo, doing a rebase and all the right commands to make a clean push can be a bit challenging.
Here are my notes on how rebase and push it with more confidence.

<!-- more -->


#  Git real life operations
## Scenario
- Main as default branch
- Branch named `feature1` and `feature2` , both created from the same head of `main`.
- Branch `feature2` is already **merged** and I am still working on `feature-1`.
- Branch `feature1` already has a **saved** commit. Eg: `1a2bc3d4`

### Purpose
The purpose here, is to add **new** changes to an existing commit from my branch `feature1`.
The outcome of it, would be to not have 2 commits, in the same PR (Pull Request). 

### What to do?

1. Pull latest changes to my local `main` branch. 
```
git checkout main
git pull
```

2. Rebase the new branch (`feature2`) from `main`.
Assuming that the latest changes does not affect my own changes, rebasing now from `main` should **Succeed**.
```
git checkout feature2
git rebase main
```
???+ note
    Running `git rebase` modifies the commit SHA. Meaning, that SHA `1a2bc3d4` will change to another hash.
3. Do the additional necessary changes. Once done, stage it them:
```
git add .
```
???+ note
    Running `git add .` adds all new and modified files to stage. It differs from `git add -u` and `git add -A`.
    To check what changes were added to stage. Run `git status`.

4. Let's now ADD these new changes to our current existing commit. The flag `--no-edit` means that I will not change my original commit message.
```
git commit --amend --no-edit
```

5. Push the changes of my local branch (origin) to my remote branch. The flag `-f` is because I am changing the history of commits.
```
git push origin feature2 -f
```
!!! warning "Disclaimer"
    Running `git push origin` without adding the branch as parameter, will add all commits to the push.

Voila! Once this is done, I should be able to see the new commit SHA, with my new changes in my PR that is already open.
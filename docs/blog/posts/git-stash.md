---
title: The safe world of Git stash
summary: Using commands git stasg
authors:
    - Hevellyn
date: 2025-01-15
categories:
  - Cheatsheet
slug: git-stash
tags:
  - git, stash, commit
---
On this exercise, we will go through the "hidden" and safe world of using `git stash`. 
<!-- more -->

# Context
As we start with git, we are often hammered with commands like, git commit/git diff/git push/git pull.
But when it comes to real life usage in a big repository and hundreds branches, there is a whole more that kicks in.
Eg. `git rebase` and `git amend`, as we covered in a previous post, [click HERE to go to it](./git-operations.md).

**But what if Im still working in my changes and not ready to commit them, but still need to be saved to make tests or to resume work after something ???**

Introducing ... `git stash`.

## git stash
This is meant to save your local changes temporarely. For every "stashed" saved, a new index will be created that can be applied or dropped.

| command | Description | 
|---|---|
| git stash push -u -m "message"| Stash untracked files and current changes |
| git stash list | List the stash **index** |
| git stash pop | The stash index is applied AND removed from the list |
| git stash apply | The stash index is applied AND **kept** in the list |
| git stash drop | The stash index is discarded |
| git stash show -p stash@{index-number} |  shows detailed diff |

I definetely learned this in the hard way, but it is practical and makes things safer while work is still in progress. 😁

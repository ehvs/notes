---
draft: false
title: Mnemosyne Cheatsheet
summary: Commands that fails to memory from time to time.
authors:
    - Hevellyn
date: 2024-10-10
categories:
  - Cheatsheet
slug: mnemosyne-cheatsheet
tags:
  - cheatsheet, linux, podman
---

The greek god Mnemosyne hint me to write this collection of commands that from time to time slips my memory.
<!-- more -->

## Podman

| Command | Purpose |
|---|---|
|podman exec $podname $command | Running specific command to active container |
|podman attach $podname | Enter container |

## System commands
|Fav | Command | Purpose |
|---|---|---|
| | journalctl --since "30min ago"|Tracing logs in minutes |
| | find . -name filename.txt | Looking for a file from current dir |
|⭐| egrep "string" -rc * 2>/dev/null \| grep -v :0 | Listing all dir and files that contains certain string |
|⭐| stat -c%a $file | Show the numerical permission values |

## Gnome
| Command | Purpose | Notes |
|---|---|---|
|ALT + F8 | Resize windows Shortcut| ESC to cancel / Enter to Accept |
|ALT + F7 | Move windows Shortcut | ESC to cancel / Enter to Accept |

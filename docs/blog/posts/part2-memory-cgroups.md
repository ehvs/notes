---
title: The Wall You Build, and the Note the Kernel Can Ignore
summary: "Part 2: cgroups, OOM, and memory.low, tested with real numbers"
authors:
    - Hevellyn
date: 2026-08-17
updated: 2026-08-17
categories:
  - AI
slug: llm-models-memory-cgroups
tags:
  - ai, memory, llm, kubernetes, cgroups
---

# The Wall You Build, and the Note the Kernel Can Ignore

In [Part 1](part1-memory-the-host.md), I mmap'd a large file on a bare VM and watched the kernel recycle page cache for free, no matter how tight the pressure got, as long as nothing ever got written to those pages. This time, I add the piece that actually matters for anyone running workloads on Kubernetes: a **cgroup**. It's the same desk-and-archive story from Part 1, except now there's a wall inside the room, and I get to decide where to put it.

## What a cgroup actually is, in one sentence

Every time you write `resources.limits.memory` in a pod spec, Kubernetes doesn't invent anything new. It writes that number into a Linux cgroup file. A cgroup is just a folder on disk (under `/sys/fs/cgroup/...`) with a handful of files in it: `memory.max` (the hard wall), `memory.current` (how full the room is right now), `memory.low`/`memory.min` (protection notes, more on that below), and `memory.events` (a scoreboard of what happened). Podman and Kubernetes both just write numbers into these files. Everything below, I read and wrote by hand.

## Experiment 1: pressure without ever hitting your own wall

First surprise: I gave a container a 10GB wall (`memory.max=10g`), comfortably more than this 7.8GB VM could ever hand it, and let it mmap the weights file. The wall was never touched: the cache topped out around 7GB, capped by the host's own RAM long before the limit mattered, and `memory.events.max` stayed at **0** throughout. And yet the kernel still reclaimed **~5GB** of that cache (`pgsteal`: 0 → 1,312,301 pages), because the *host* was short on RAM.

The lesson: being under your own container limit doesn't mean you're safe from reclaim. The room can be roomy and you can still lose furniture, if the house outside is full.

## Experiment 2: hitting the wall for real

Same setup, but now the wall is at 5GB, well below the size of the file being mapped. This time `memory.current` plateaued at **99.96% of the limit**, and `memory.events.max` climbed to **3,317**: the container hit its own ceiling three thousand times. Still zero OOM kills. But something interesting flipped: in Experiment 1, 99.45% of reclaim happened quietly in the background (`kswapd`). Here, **100% of it was synchronous** (`pgscan_direct`), happening right inside the process's own read path. Hitting your *own* wall forces the kernel to clear space immediately, on the spot, because background cleanup doesn't have time to help.

## Experiment 3: what happens if you write on the photocopy

Everything above worked because the pages were read-only, clean photocopies the kernel could toss for free. To show the contrast, I ran `stress-ng`, allocating and actually **writing to** 3GB of memory inside a 2GB wall. No swap configured. Result: **387 kills** (`oom_kill`: 0 → 387). The kernel log doesn't leave room for doubt:

```
Memory cgroup out of memory: Killed process 6375 (stress-ng-vm)
anon-rss:2058580kB file-rss:904kB oom_score_adj:1000
```

Compare the reclaim attempt: in Experiments 1 and 2, the kernel scanned and freed **millions** of pages before ever considering a kill. Here, it barely tried (`pgscan`: 12, `pgsteal`: 9) before going straight to the OOM killer, because there was nothing cheap to reclaim. Written memory needs somewhere to go before it can be freed; with no swap, there's nowhere.

One gotcha worth knowing: `podman inspect --format '{{.State.OOMKilled}}'` reported **`false`** the entire time, despite 387 real kills. That flag only tracks the container's main process (in my case, an idle `sleep infinity`), not whatever you `exec` into it. The kernel log and `memory.events` are the only numbers you can trust here.

## Experiment 4: the sticky note that isn't always obeyed

`memory.low` is usually described as "protect this workload's hot memory." Think of it as a *please don't take this chair* note on a seat: everyone would rather respect it, but when the room is full and there is genuinely nowhere else to sit, the note loses.

The desk has two piles, and the kernel knows the difference. `active_file` is what's stacked at your elbow, touched recently. `inactive_file` is what got shoved to the far corner. When space is needed, the far corner goes first. I tested the note two ways.

**Control, no protection:** a neighbor asking for 1GB. Result: `active_file` was **completely untouched**: the kernel took the full 1GB from the far corner and never needed to reach any further.

**With `memory.low=6GB`, and a hungrier neighbor asking for 3GB:** the protection didn't hold. `memory.current` fell to **~3.75GB, well below the 6GB "protected" floor**, and `active_file` was wiped from 4.8GB down to essentially zero.

This isn't a bug, and I confirmed it against the kernel's own documentation:

> "If the memory usage of a cgroup is within its effective low boundary, the cgroup's memory won't be reclaimed **unless there is no reclaimable memory available in unprotected cgroups**."

On this VM, my container's cache was the *only* reclaimable memory anywhere. There was no weaker neighbor for the kernel to sacrifice instead, so the documented exception kicked in, and protection was overridden exactly as designed. `memory.low` doesn't guarantee your memory stays put; it only tells the kernel who to sacrifice *first*, when there's a choice.

Two caveats, so this doesn't claim more than it earned: the protected run also faced 3× the pressure, and the demand (~3.5GB) already exceeded the far-corner pile available (~2.4GB), so the hot pages were going to be taken either way. This demonstrates the documented escape hatch, not how much `memory.low` is worth.

## What this means if you're running this on Kubernetes

The cgroup files I poked by hand aren't a simulation of what Kubernetes does. They're literally the files Kubernetes writes to. Your pod's `limits.memory` already lands in `memory.max` today; that's baseline kubelet behavior, no feature flags involved. It is the wall from Experiment 2, and `memory.events.max` on a real pod counts how often it got hit.

The protection side is newer, and comes from **Memory QoS** ([KEP-2570](https://github.com/kubernetes/enhancements/blob/master/keps/sig-node/2570-memory-qos/README.md)). It adds two things to the wall you already have. Enabling the `MemoryQoS` feature gate turns on `memory.high`, a speed bump placed just before the wall, computed by the kubelet as `requests + 0.9 × (limits − requests)`, so a container slows down instead of slamming into the limit at full speed. Reserved seating is a separate opt-in: as of Kubernetes 1.36 the kubelet writes tiered protection by QoS class through a dedicated config field (`TieredReservation`), giving Guaranteed pods hard protection via `memory.min`. Turning on the gate alone does not get you the seat.

That distinction matters for an LLM-serving pod. What I tested was `memory.low`, the polite note, silently overridden when there's no alternative victim. `memory.min` is the same seat bolted to the floor with your name on it: the kernel won't take it, and if that leaves someone with nowhere to sit, the bouncer removes them instead. The bouncer is the OOM killer. Same protection, much louder failure. Worth knowing which one you're actually standing on.

And either way, protection is relative. On a node running one large model-serving pod with nothing smaller nearby to sacrifice, there is nowhere for the kernel to push pressure, exactly what happened in Experiment 4. A reserved seat only helps in a room with other people in it.

Next up: the same file, mmapped inside a KVM guest, where it turns out you can cache the same weights twice without realizing it.

Sources: [Control Group v2 kernel docs](https://docs.kernel.org/admin-guide/cgroup-v2.html), [KEP-2570: Memory QoS](https://github.com/kubernetes/enhancements/blob/master/keps/sig-node/2570-memory-qos/README.md), [Kubernetes v1.36: Tiered Memory Protection with Memory QoS](https://kubernetes.io/blog/2026/04/29/kubernetes-v1-36-memory-qos-tiered-protection/)

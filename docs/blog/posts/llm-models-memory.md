---
title: The three walls of memory, in the context of AI Models (3 part series)
summary: A mmap experiment
authors:
    - Hevellyn
date: 2026-08-16
updated: 2026-08-16
categories:
  - AI
slug: the-three-walls-of-memory-ai
tags:
  - ai, memory, llm, models, artificial inteligence, rss, pss, kernel
---

# The three walls of memory, in the context of AI Models (Part 1)

## Part 1: Inside the host, going deeper than container_memory_working_set_bytes

I've been working with Kubernetes and OpenShift for years now, and sizing the memory for the workload is a novel that it is never old enough. Because Prometheus makes super easy, perhaps too easy, with the expressions, it is easy to get mislead about what they actually mean underneath and what is the impact.  On this blog post you will find some analogies that helped me to understand and visualise (I'm a visual learner).

Per example `container_memory_working_set_bytes` it is the one used by K8S, for decisions of evicion and OOM. Why? I would arqgue because it is safe enough, which is ok for most workload. But for AI workloads, you will need more details and deeper understand of how reading that 70GB of data and still be responsive without crashing, and spoiler alert, that metric will not work.

Most inference serving stacks don't load model weights with a `read()` into a heap buffer anymore. `llama.cpp` mmaps GGUF files. HuggingFace's `safetensors` mmaps by default on Linux. vLLM and PyTorch's newer loaders do the same. The reason is practical: a `read()` copies gigabytes of weights twice, at first in the page cache, another in your buffer, and it's proportional to file size, so a 70GB checkpoint means minutes of cold-start latency before the first token. `mmap` skips the copy entirely: the mapping *is* the page cache entry, pages fault in lazily as layers are actually touched, and startup is near-instant regardless of file size. It's also what makes sparse-activation architectures — mixture-of-experts models that only touch a handful of experts per request — practical: unused experts simply never get paged in.

The catch is that this makes a model server's memory footprint look like something it isn't. A dashboard reporting `container_memory_working_set_bytes` in the tens of gigabytes for a model-serving pod is mostly reporting *page cache, not memory that needs to be reserved** — and most schedulers, autoscalers, and OOM policies don't draw that distinction. So instead of instrumenting a full serving stack, I isolated the mechanism itself: a tiny C harness, no framework, no model, just the raw behavior every one of these loaders depends on.

## The setup

`mmaptouch` maps a file with `mmap()` and reads one byte per 4KB page. It pauses at two checkpoints so I could inspect memory from another terminal — right after mapping (nothing touched), and right after touching every page of a 20GB file, on a VM with less RAM than that.

## RSS: what's on the desk, not what's in the archive

Picture a desk and a basement archive holding everything — here, the 20GB file. RSS (Resident Set Size) is how many folders are physically on the desk *right now*, not the archive's size. Before touching anything, RSS was near zero. Page by page, folders piled up and RSS climbed.

## The plateau, and the precondition that makes it safe

RSS never got near 20GB. It plateaued around 7.5GB (roughly what the VM had free) even after every page had been touched. The kernel kept sliding older folders back to the archive to make room, no write-back needed.

This only works because the pages are read-only, nothing ever gets written to them. In other words, the file is opened O_RDONLY and mapped with PROT_READ + MAP_SHARED. It's like returning a clean photocopy to the archive: no notes to save first, so it's free to toss. A writable version would need somewhere to save those notes (swap) before clearing the desk, and a cloud VM without swap has nowhere to put them. That's exactly how model weights are used: read, never written.

You can verify these flags without reading the source: `PROT_READ` and `MAP_SHARED` both show up together in the permission column of `/proc/[pid]/maps` (or smaps) as r--s; O_RDONLY shows up in `/proc/[pid]/fdinfo/<fd>,`.

* `MAP_SHARED`: Meaning this mapping shares the same page cache pages as the underlying file itself.
* `PROT_READ`: Granting only read access to the mapped pages, blocking any writes entirely.
* `O_RDONLY`: open() flag meaning the underlying file descriptor itself can only be used for reading data.

## Proof, not a story

Diffing `/proc/vmstat` across the run: `pgscan_anon`/`pgsteal_anon` stayed at **0** the entire time. zero anonymous memory ever touched by reclaim. `pgsteal_file` rose by **3,443,807 pages** (~13.1GB) actually reclaimed, at **99.4%** scan efficiency, with only **0.56%** of scans needing synchronous direct reclaim — the rest ran quietly in the background via `kswapd`. That's the OOM killer's trigger condition made concrete: it only fires when reclaim and compaction fail everywhere. With ~13GB of trivially reclaimable, zero-anon file cache on tap, that never got close.

## PSS, briefly

RSS double-counts shared memory — two processes sharing a folder both get billed the full folder. PSS (Proportional Set Size) splits it proportionally. Mine matched RSS exactly, since nothing else had the file open — but on a node running several replicas of the same model, PSS is the number that shows the weights aren't actually duplicated per process.

## Wraping up and what it means in K8S context

For context of AI workload...
Separate `container_memory_rss` (anonymous — activations, KV cache, real buffers) from `container_memory_cache` (weights loaded via mmap), and size requests/limits off RSS plus a margin, not off the total working set.

### How to do that? 
Use PSI (memory.pressure, some/full) as the actual trigger for pressure decisions, instead of a byte threshold — this is exactly the point your post is building toward for its closing. If possible, use `memory.low/memory.min` to protect the "hot" RSS (active KV cache), and let the weights cache be the first thing sacrificed under pressure.
For model-serving autoscaling, prefer latency/queue-depth/GPU-utilization signals over memory bytes, since memory here is dominated by cache noise.

#### In Kubernetes
On a Kubernetes node, PSI doesn't require any bespoke plumbing anymore. At the host level, node-exporter exposes it out of the box through its pressure collector. At the pod and container level, Kubernetes now collects it natively in v1.36, exposed through the same `/metrics/cadvisor` endpoint that already serves `container_memory_working_set_bytes`. Wire an alert on some avg60 instead of a raw byte threshold, and the argument in this post stops being a lab exercise and becomes something a cluster can act on.

Recommended reading:
* https://kubernetes.io/blog/2026/05/12/kubernetes-v1-36-psi-metrics-ga/ 
* https://github.com/kubernetes/enhancements/issues/4205
* https://kubernetes.io/docs/reference/instrumentation/understand-psi-metrics/ 

### The experiment

1. Create a synthetic "weights" file
```
dd if=/dev/zero of=weights.bin bs=1M count=20480 oflag=direct status=progress
```
- `oflag=direct` bypasses the page cache on write, so the file starts cold — not pre-warmed by the write itself.

2. Write the harness (mmaptouch.c)

Claude wrote a small program that mmap()s the file and touches one byte per 4KB page, pausing at two checkpoints for external inspection, with an optional sample-count for the random mode.
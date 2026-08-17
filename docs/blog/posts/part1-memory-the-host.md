---
title: The three walls of memory, in the context of AI Models (3 part series)
summary: Part 1 - A mmap experiment
authors:
    - Hevellyn
date: 2026-08-16
updated: 2026-08-16
categories:
  - AI
slug: the-three-walls-of-memory-ai
tags:
  - ai, memory, llm, models, artificial intelligence, rss, pss, kernel
---

I've been working with Kubernetes and OpenShift for years, and sizing memory for a workload is a story that never gets old. Prometheus makes it easy, perhaps too easy, to write an expression and trust whatever number comes back, without asking what it actually counts underneath. This first part digs into memory and mmap from the host's perspective, and ends where it matters: what that means for an AI workload.
<!-- more -->

# The three walls of memory, in the context of AI Models (Part 1)

## Part 1: Inside the host, going deeper than container_memory_working_set_bytes

Picture a desk and a basement archive. The archive holds a 70GB model checkpoint. The desk is your node's RAM. The archive will never fit on the desk, and nothing about serving that model requires it to. Yet your memory dashboard will strongly imply otherwise.

This series is about the gap between what is genuinely *on the desk* and what a metric claims is on the desk. Part 1 stays on a bare VM, where the only limit is the size of the room itself.

The metric everyone reaches for, `container_memory_working_set_bytes`, is what the kubelet's eviction manager uses when a node runs short on memory and has to pick pods to evict. It is also widely mistaken for what triggers OOM kills. That is a different mechanism entirely, living in the kernel rather than the kubelet, and Part 2 shows the real one firing. Why lean on working set at all? Because it is safe enough, and that is fine for most workloads. For AI workloads it isn't, and this post is about why.

## Why model servers mmap their weights

Almost no inference stack loads weights with a plain `read()` into a buffer anymore. `llama.cpp` mmaps GGUF files. HuggingFace's `safetensors` mmaps by default on Linux. vLLM and PyTorch's newer loaders do the same.

The reason is the difference between photocopying an entire archive into your office before you can start working, versus getting a library card. `read()` is the photocopier: it copies gigabytes twice, once into the page cache and once into your buffer, and the cost scales with file size, so a 70GB checkpoint means minutes of cold start before the first token. `mmap` is the library card: the mapping *is* the page cache entry, folders are fetched only when you actually open one, and startup is near-instant no matter how big the archive is.

It is also what makes mixture-of-experts models practical. Each request only needs a handful of the model's "experts," so the ones nobody asks for are never fetched from the archive at all.

The catch is that this makes a model server's memory footprint look like something it isn't. A dashboard reporting `container_memory_working_set_bytes` in the tens of gigabytes for a model-serving pod is mostly reporting **page cache, not memory that needs to be reserved**, and schedulers, autoscalers and OOM policies rarely draw that distinction. So rather than instrument a full serving stack, I isolated the mechanism itself: a tiny C harness, no framework, no model, just the raw behaviour every one of these loaders depends on.

## The setup

`mmaptouch` maps a file with `mmap()` and reads one byte per 4KB page. It pauses at two checkpoints so I could inspect memory from another terminal: right after mapping (nothing touched), and right after touching every page of a 20GB file, on a VM with less RAM than that.

## RSS: what's on the desk, not what's in the archive

RSS (Resident Set Size) is how many folders are physically on the desk *right now*, not how big the archive is. Before touching anything, RSS was near zero. Page by page, folders piled up and RSS climbed.

## The plateau, and the precondition that makes it safe

RSS never got near 20GB. It plateaued around 7.5GB, roughly what the VM had free, even after every page had been touched. The kernel kept sliding older folders back down to the archive to make room for new ones.

That works because every folder here is a clean photocopy: read-only, never written to. There are no notes to save before returning one, so throwing it away costs nothing. A writable mapping would need somewhere to put those notes first, namely swap, and a cloud VM without swap has nowhere to put them. Model weights at inference time are exactly the clean case: read, never written.

Three flags enforce that, and you can verify them on any running process without reading its source:

* `O_RDONLY`: the file descriptor can only read. Visible in `/proc/[pid]/fdinfo/<fd>`, on the `flags:` line.
* `PROT_READ` + `MAP_SHARED`: the mapping is read-only, and shares the file's own page cache pages instead of a private copy. Both appear together in `/proc/[pid]/maps` as the permission column `r--s`.

## Proof, not a story

Diffing `/proc/vmstat` across the run: `pgsteal_file` rose by **3,443,807 pages** (~13.1GB actually reclaimed), at **99.4%** scan efficiency, with only **0.56%** of scans needing synchronous direct reclaim. The rest ran quietly in the background via `kswapd`.

`pgscan_anon`/`pgsteal_anon` stayed at **0**, which deserves an asterisk rather than a victory lap: this VM has no swap, and without swap anonymous pages can't be reclaimed at all, so that counter reads zero regardless of workload. The sharper version of this proof arrives in Part 2, scoped to a single container.

Either way, the reclaim numbers make the OOM killer's trigger condition concrete: it only fires when reclaim and compaction fail everywhere at once. With ~13GB of trivially reclaimable file cache on tap, that never came close.

## PSS, briefly

RSS double-counts shared memory: two processes with the same folder open are each billed for the whole thing. PSS (Proportional Set Size) splits the bill: a folder shared by two counts as half for each, and one nobody else has open counts in full. Both live in `/proc/[pid]/smaps_rollup`.

In a single-process run there is nothing to split, so PSS tells you nothing RSS didn't. It earns its keep on a node running several replicas of the same model, where the weights are mapped many times but resident only once, precisely where RSS will charge you for the same gigabytes over and over.

## What this means on Kubernetes

Back to the desk. The mistake is reading "the desk is full" as "we need a bigger desk." For a model server, most of what is on that desk are photocopies the kernel can return to the archive the moment it needs the space. Paying for RAM to hold photocopies is expensive, and so is setting a limit so tight the kernel spends its day carrying folders up and down the stairs.

In practice:

* Separate `container_memory_rss` (anonymous: activations, KV cache, real buffers) from `container_memory_cache` (weights loaded via mmap). Size requests and limits off RSS plus a margin, not off total working set.
* For autoscaling a model server, prefer latency, queue depth or GPU utilisation over memory bytes. Memory here is dominated by cache noise.
* Use PSI (`memory.pressure`, `some`/`full`) as the trigger for pressure decisions instead of a byte threshold. It is the difference between "the desk is full" and "I am actually stuck waiting on it."

That last point is where this series lands, and it closes Part 3. On a Kubernetes node, PSI needs no bespoke plumbing anymore: node-exporter exposes it at host level through its pressure collector, and since v1.36 the kubelet collects it natively per pod and container, on the same `/metrics/cadvisor` endpoint that already serves `container_memory_working_set_bytes`.

[Part 2](part2-memory-cgroups.md) is the layer in between: the same workload, this time inside a cgroup, where the wall is one you chose, and `memory.low` turns out to be weaker than its reputation.

Recommended reading:

* [https://kubernetes.io/blog/2026/05/12/kubernetes-v1-36-psi-metrics-ga/](https://kubernetes.io/blog/2026/05/12/kubernetes-v1-36-psi-metrics-ga/)
* [https://github.com/kubernetes/enhancements/issues/4205](https://github.com/kubernetes/enhancements/issues/4205)
* [https://kubernetes.io/docs/reference/instrumentation/understand-psi-metrics/](https://kubernetes.io/docs/reference/instrumentation/understand-psi-metrics/)

### Reproducing it

1. Create a synthetic "weights" file. The contents are irrelevant, since only size and access pattern matter to the kernel:

```
dd if=/dev/zero of=weights.bin bs=1M count=20480 oflag=direct status=progress
```

`oflag=direct` writes past the page cache, so the file starts cold instead of pre-warmed by its own creation.

2. Build the harness. `mmaptouch.c` (written with Claude's help) maps the file, reads one byte per 4KB page, and pauses at two checkpoints for external inspection:

```
gcc -O2 -o mmaptouch mmaptouch.c
```

3. Drop the caches, so nothing is warm from an earlier run:

```
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
```

4. Snapshot the reclaim counters, run, snapshot again:

```
grep -E 'pgscan|pgsteal' /proc/vmstat > before.txt
./mmaptouch weights.bin       # inspect /proc/<pid>/smaps_rollup at each checkpoint
grep -E 'pgscan|pgsteal' /proc/vmstat > after.txt
diff before.txt after.txt
```

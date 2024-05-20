---
draft: true
title: Setup custom domain for Github Pages
summary: This was a hurdle, but with help of google and friends, voi la! spoiler alert ITS ALWAYS DNS
authors:
    - Hevellyn
date:
  created: 2024-04-30
  updated: 2024-04-30
categories:
  - Networking
slug: images
tags:
  - cloudfare, dns, customdomain
---
On this exercise I will go through my journey on how setup a fresly bought domain to append to this blog
<!-- more -->

It is best to write while is still fresh, so here we go. It has been years since I have this idea cooking of writing a blog.
I work with different issues with different customers every day, so.. well, there must be something that I can share to help others!
After considering diferent platforms, like Hugo (a very popular one), I met MKDocs which is less customizable but for the purposes that I am aiming it works just fine.
It is well structured and does not need much tweaking around, their documentation is super good and easy to follow and the best part, it can be built on top of Github Pages, which in theory already gives you a out-of-the-box domain!
But I wanted more, I wanted my own domain without having to spend loads of money for it. Got it from Hostinger, to only then find out that Cloudfare have free plans of hosting the website service as well! 

 What is necessary to have a custom domain associated to your newly built Github Pages?
- A domain
- A webservice provider
# Extra Maps from DO Space - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Download extra .unr map files from a public DO Space during droplet provisioning.

**Architecture:** Add a `SPACE_NAME` config setting and a download block to the existing `provision_server()` heredoc. The block lists the S3 bucket, parses .unr keys from the XML, and curls each file into `/opt/ut99/Maps/`.

**Tech Stack:** Bash, curl, grep, sed (all already available on the droplet)

---

### Task 1: Add SPACE_NAME to config

**Files:**
- Modify: `ut99.conf.example`

**Step 1: Add SPACE_NAME to example config**

Add `SPACE_NAME=my-space` to `ut99.conf.example`.

**Step 2: Commit**

### Task 2: Add map download block to provisioning

**Files:**
- Modify: `ut99` — inside `provision_server()` heredoc, after UT99 install and user creation, before server configuration

**Step 1: Add download block**

In `provision_server()`, construct the Space URL from config and pass it to the remote script:

The Space URL is constructed as: `https://${SPACE_NAME}.${REGION}.digitaloceanspaces.com`

Change the ssh invocation to pass the URL as a positional argument using `bash -s --`.

Inside the heredoc, after `chown -R ut99:ut99 /opt/ut99` and before `echo "==> Configuring server..."`, add a block that:
1. Fetches the S3 XML bucket listing
2. Extracts `<Key>` values ending in `.unr` (case-insensitive)
3. Downloads each map file into `/opt/ut99/Maps/`
4. Fixes ownership on the Maps directory

**Step 2: Commit**

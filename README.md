# Abiri Box

A Vagrant-powered local development environment for **Node.js (TypeScript)** + **PostgreSQL**, with domain mapping similar to Laravel Homestead.

---

## Requirements
Before using Abiri Box, ensure you have the following installed on your host machine:

- [Vagrant](https://www.vagrantup.com/downloads) (>= 2.2)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (or another supported Vagrant provider)
- Unix-like environment (Linux/macOS recommended)
- `bash` shell

---

## Features
- Ubuntu 20.04 (Focal Fossa) VM
- Node.js LTS
- PostgreSQL
- Nginx with per-site domain mapping
- Automatic folder syncing between host and VM
- Easy start, provision, and halt commands via the `abiri` CLI

---

## Installation

```bash
git clone https://github.com/cokoyoh/abiri-box.git
cd abiri-box
chmod +x abiri
sudo mv abiri /usr/local/bin/abiri
```

---

## Usage

### Start the virtual machine
```bash
abiri up
```

### Provision and configure the environment
```bash
abiri provision
```

### Stop the virtual machine
```bash
abiri halt
```

---

## Domain Setup

Add entries to your host machine `/etc/hosts` file so local domains resolve correctly:

```
192.168.56.56 tabiri.test
```

---

## How It Works

### 1. Vagrantfile
- Reads settings from `abiri.yaml` (IP, synced folders, sites).
- Spins up an Ubuntu 20.04 VM.
- Assigns a private network IP.
- Syncs host directories to the VM.
- Runs `provision.sh` on first boot.

### 2. provision.sh
- Updates & upgrades packages.
- Installs:
  - Nginx
  - PostgreSQL
  - Node.js LTS
  - Development tools (curl, git, build-essential, etc.)
- Configures Nginx server blocks for each site.
- Adds `/etc/hosts` entries inside the VM.
- Restarts Nginx.

### 3. Workflow
1. Define sites & folders in `abiri.yaml`.
2. Run `abiri up` to boot the VM.
3. Run `abiri provision` to set everything up.
4. Access local domains in your browser.

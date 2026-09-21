# 🛠️ Linux System Maintenance Script

A small, conservative Bash script for routine package maintenance on **Debian/Ubuntu-based Linux systems**.

The script separates **system updates** from **package cleanup**. By default, it updates package indexes and performs a full system upgrade. Cleanup operations are only performed when explicitly requested with the `--cleanup` option.

> ⚠️ Important: This script is intended for Debian/Ubuntu-based systems that use APT. It must be run with root privileges.

## ✨ What the script does

### Normal maintenance

```bash
sudo ./maintenance.sh
```

Performs:

- 🔎 Check for root privileges
- 📦 Check that `apt-get` is installed
- 🔒 Prevent multiple copies from running simultaneously
- 🔄 Refresh package indexes
- ⬆️ Perform a full system upgrade
- 🔁 Check whether a reboot is required

### Maintenance with cleanup

```bash
sudo ./maintenance.sh --cleanup
```

Performs everything above and additionally:

- 🧹 Remove packages that APT considers no longer required
- 🗑️ Clean obsolete package archives

This separation is intentional. Updating and package removal are different administrative operations.

## 🚀 Usage

### Standard maintenance

```bash
sudo ./maintenance.sh
```

Performs:

```bash
apt-get update
apt-get full-upgrade -y
```
It does **not** automatically run `autoremove` or `autoclean`.

### Maintenance + cleanup

```bash
sudo ./maintenance.sh --cleanup
```

This additionally performs:

```bash
apt-get autoremove -y
apt-get autoclean
```

Use this when you explicitly want to clean up packages and the local package cache.

### Display help

```bash
./maintenance.sh --help
```

The help option does not require root privileges.

The short form is also supported:

```bash
./maintenance.sh -h
```

### Invalid options

The script rejects unknown options rather than silently ignoring them:

```bash
./maintenance.sh -something
```

This produces an error and displays the usage information.

## 🤔 Why separate maintenance and cleanup?

The original version automatically performed:

```bash
apt autoremove -y
apt autoclean
```

after every upgrade.

Although these operations are commonly safe, they represent a different type of system modification.

A package upgrade means:

> Bring installed packages up to date.

`autoremove`, on the other hand, means:

> Remove packages that APT currently considers unnecessary.

Separating them provides a safer and more predictable default:

```text
Normal operation
      │
      ├── Update package indexes
      └── Full upgrade

--cleanup
      │
      ├── Update package indexes
      ├── Full upgrade
      ├── Autoremove unused packages
      └── Autoclean package cache
```

Useful when scheduled with cron or systemd timers.

## 🧹 What does --cleanup do?

When `--cleanup` is supplied, the script runs:

```bash
apt-get autoremove -y
apt-get autoclean
```

### `autoremove`

APT identifies packages that were automatically installed as dependencies and are no longer required by installed packages.

Because the script uses `-y`, the proposed removals are automatically accepted.

> ⚠️ On an important server, consider reviewing the proposed removals manually before using automatic cleanup.

You can inspect them with:

```bash
sudo apt-get autoremove
```

### `autoclean`

`autoclean` removes package archives from the local cache when those archives can no longer be downloaded from configured repositories.

It is less aggressive than:

```bash
apt-get clean
```

which removes all cached package archives.

## 📦 Why apt-get instead of apt?

Both `apt` and `apt-get` are part of the APT package-management system.

`apt` is primarily designed as a convenient, user-friendly command for interactive use.

`apt-get` is the traditional package-management interface and is generally preferred for scripts because its command-line interface is intended to be more suitable for automation.

Therefore, this script uses:

```bash
apt-get update
apt-get full-upgrade
apt-get autoremove
apt-get autoclean
```

rather than the corresponding `apt` commands.

This does not mean that `apt` is unsafe. It simply makes `apt-get` a better fit for a script intended to be repeatable and potentially automated.

## ⬆️ Why full-upgrade instead of upgrade followed by full-upgrade?

The original script performed:

```bash
apt upgrade -y
apt full-upgrade -y
```

There is normally little benefit in doing both.

`full-upgrade` can perform the normal upgrade operation while also resolving dependency changes that may require packages to be installed or removed.

The revised script therefore performs:

```bash
apt-get full-upgrade -y
```

as the single upgrade operation.

> ⚠️ Important distinction: `full-upgrade` can remove packages when required to resolve dependencies. 
This is different from a conservative upgrade that avoids package removals. For a normal desktop or workstation, this may be appropriate. On production systems, administrators may prefer a more controlled update process.

## 🛡️ Error handling

The script uses:

```bash
set -Eeuo pipefail
```
This provides several safeguards:

- `-e` stop on command failure
- `-E` preserve error traps
- `-u` treat unset variables as errors
- `pipefail` detect failures inside pipelines

For example, if:

```bash
apt-get update
```

fails because of a repository or network problem, the script stops rather than continuing with a system upgrade.

## 📦 APT availability check

The script checks for the actual command it needs:

```bash
command -v apt-get
```

If `apt-get` is not installed, the script terminates with a clear message:

```text
ERROR: apt-get was not found on this system.
This script requires a Debian/Ubuntu-style APT package manager.
```

This prevents a less useful "command not found" error later in the script.

## 🔒 Preventing simultaneous executions

APT should not be manipulated by multiple maintenance processes at the same time.

The script therefore uses flock and creates a lock at:

```text
/run/system-maintenance.lock
```

If another instance is already running, the second instance exits.

This is especially useful if the script is eventually scheduled automatically.

## 🔁 Reboot detection

Some package updates, particularly kernel and core system updates, can require a reboot.

The script checks for:

```text
/var/run/reboot-required
```

f this file exists, it displays:

```text
WARNING: A reboot is required.
```
The script does **not reboot automatically**.

This is intentional. Rebooting is an administrative decision and should not happen unexpectedly, particularly on servers.

## 🔐 Root privileges

Package management requires elevated privileges.

The script checks whether it is running as root.

Run using:

```bash
sudo ./maintenance.sh
```

## 🧪 Previewing changes

Before using the script on an important system, you can inspect what APT intends to change.

Update the package indexes:

```bash
sudo apt-get update
```

List packages that can be upgraded:

```bash
apt list --upgradable
```

Simulate a full upgrade:

```bash
sudo apt-get --simulate full-upgrade
```
The simulation does not actually modify installed packages.

You can also inspect cleanup before accepting it:

```bash
sudo apt-get autoremove
```

## 📋 Example output

### Normal maintenance

```text
======================================
 Starting System Maintenance
======================================

Mode: Standard maintenance

[1/2] Updating package lists...
...

[2/2] Performing full system upgrade...
...

======================================
 Maintenance Complete
======================================
```

### Maintenance with cleanup

```text
======================================
 Starting System Maintenance
======================================

Mode: Maintenance + cleanup

[1/4] Updating package lists...
...
[2/4] Performing full system upgrade...
...
[3/4] Removing unused packages...
...
[4/4] Cleaning obsolete package archives...
...

======================================
 Maintenance Complete
======================================
```

If a reboot is required:

```text
WARNING: A reboot is required.
```

## ⚠️ Considerations for servers

This script is intentionally small, but automated package maintenance deserves additional consideration on production systems.

In particular:

- `full-upgrade` can install or remove packages
- `autoremove -y` automatically accepts removals
- Upgrades can require configuration decisions
- Kernel updates can require a reboot
- Third-party repositories can fail
- Successful package transactions do not guarantee application health

For critical infrastructure, consider testing updates before applying them to production and following your organization's normal change-management process.


## 💡 Design philosophy

The script follows a few simple principles:

- 🛡️ **Fail early** rather than continuing after an important error
- 📦 **Use** `apt-get` because this is a script rather than an interactive package-management session
- ⬆️ **Avoid redundant operations** by using `full-upgrade` rather than both `upgrade` and `full-upgrade`
- 🧹 **Separate cleanup from maintenance** so package removal is an explicit choice.
- 🔒 **Prevent concurrent executions**
- 🔁 **Never reboot automatically**
- 💬 **Provide useful error messages**
- 🔍 **Keep the script small and auditable**

The goal is not to provide a complete Linux administration framework. Instead, this project provides a small, understandable maintenance script that performs common APT maintenance tasks while keeping potentially consequential cleanup operations explicit and predictable.

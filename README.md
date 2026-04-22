# 🧠 linux-environments

> Reproducible, observable, and automated Linux systems.

---

## 💡 Philosophy

This repo is built around a simple principle:

> **A system should be recoverable, inspectable, and self-reporting.**

It is not just dotfiles.

It is a **unified platform** for managing multiple machines with:

* 🔁 **Reproducibility** — rebuild any system from scratch
* 🧱 **Recoverability** — always know and restore system state
* ⚙️ **Automation** — systems maintain themselves
* 🔔 **Observability** — systems report what they’re doing

---

## 🖥️ Systems

| Machine           | ID          | OS     |
| ----------------- | ----------- | ------ |
| 💼 Dell Precision | `laptop01`  | Arch   |
| 💻 HP Envy        | `laptop02`  | Ubuntu |
| 🧪 Covid PC       | `desktop01` | Arch   |
| 🐳 Docker Server  | `server01`  | Ubuntu |

Each machine is **independently defined, consistently managed**.

---

## 🧩 Structure

```text
linux-environments/
├── install.sh      # entry point
├── scripts/        # automation (notify, export, stow)
├── system/         # package/state per machine
├── hosts/          # machine-specific configs
├── stow/           # shared dotfiles
├── systemd/        # services + timers
└── wallpaper/
```

---

## 🔄 How It Works

```text
install.sh
   ↓
bootstrap (per machine + OS)
   ↓
packages → environment → dotfiles → services
   ↓
system state exported + monitored
   ↓
notifications sent (Discord)
```

---

## 🚀 Install

```bash
git clone https://github.com/matthewjgarry/linux-environments.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The installer:

* selects machine
* detects OS
* configures git + webhook
* launches the correct bootstrap

---

## 🧪 Bootstrap

Each bootstrap:

* verifies machine + OS
* installs packages (apt/pacman/flatpak/snap/brew)
* configures environment (GNOME, shell, defaults)
* applies dotfiles (`stow`)
* installs services
* exports system state
* shows summary → reboot

---

## 📦 Package State

Each machine defines its own system:

```text
system/<machine>/<os>/
├── apt.txt | pacman.txt
├── flatpak.txt
├── snap.txt
└── brew.txt
```

State is **authoritative and tracked**.

---

## 🔗 Configuration

* shared configs → `stow/`
* machine overrides → `hosts/<machine>/<os>/`

Everything is applied automatically.

---

## ⚙️ Automation

User-level services handle:

* 📦 package tracking
* 🔄 system updates
* 🔍 repo drift detection
* 🧾 dotfile changes
* 💾 disk monitoring
* ❤️ heartbeat

Systems are **continuously self-aware**.

---

## 🔔 Notifications

All machines report to Discord via webhook.

```bash
notify.sh "Disk Warning" "Root is 91% full" warning
```

| Level | Meaning |
| ----- | ------- |
| ℹ️    | info    |
| ✅     | success |
| ⚠️    | warning |
| ❌     | error   |

Each message includes:

* machine ID
* hostname
* timestamp

---

## 🧠 Identity

Each machine is bound to:

```bash
~/.config/dotfiles/machine-id
```

This ensures:

* correct config application
* safe automation
* separation of system state

---

## 📌 Summary

* 🔁 reproducible systems
* 🧱 recoverable state
* ⚙️ automated maintenance
* 🔔 centralized visibility

---

## 🧑‍💻 Author

Matthew J Garry

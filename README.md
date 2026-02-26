# Winstall

Automated Fedora 43 Workstation setup that transforms a fresh install into a Windows-lookalike environment. Designed for mass deployment — clone, chmod, run, walk away.

---

## Requirements

- Fresh **Fedora 43 Workstation** install
- A **normal user account** (not root)
- Internet connection
- GNOME desktop session

---

## Usage

```bash
git clone https://github.com/StiviKM/Winstall
chmod +x Winstall/Winstall_One.sh Winstall/Winstall_Two.sh
./Winstall/Winstall_One.sh
```

That's it. The rest is fully automated across two stages with an automatic reboot between them.

---

## How It Works

### Stage 1 — `Winstall_One.sh`
Runs manually. Handles all system-level setup, then reboots.

- Prompts for your password **once**, keeps sudo alive for the entire script
- Configures DNF for faster downloads (`max_parallel_downloads=10`)
- Full system update and upgrade
- Enables DNF automatic updates (`dnf5-plugin-automatic`)
- Enables RPM Fusion free and nonfree repositories
- Replaces Fedora Flatpak repo with Flathub
- Installs multimedia codecs (ffmpeg, gstreamer plugins)
- Installs Intel and AMD hardware accelerated video codecs
- Installs and enables SSH server
- Checks for firmware updates via `fwupdmgr`
- Removes bloatware (see list below)
- Installs all required packages and dependencies
- Installs Flatpak applications
- Installs NoMachine (latest version, fetched dynamically)
- Installs ZeroTier
- Clones the Winstall repo and installs all GNOME extensions
- Installs ZSH + Oh My ZSH with plugins and `jonathan` theme
- Installs Microsoft Windows fonts
- Installs Google Fonts collection
- Schedules Stage 2 to run automatically after reboot
- **Reboots the machine**

### Stage 2 — `Winstall_Two.sh`
Runs automatically after login via GNOME autostart. Handles all GNOME session-level setup, then reboots.

- Removes the autostart entry immediately on start (prevents loops even on failure)
- Waits for GNOME Shell to be fully ready before proceeding
- Loads Dash-to-Panel configuration from repo
- Loads ArcMenu configuration from repo (with automatic home directory path fix)
- Installs and applies Win11 icon theme (dark variant)
- Sets the wallpaper
- Enables all GNOME extensions
- Applies all desktop settings (see below)
- Configures GNOME Remote Desktop (RDP) with TLS certificate
- Cleans up all temporary files and the Winstall directory

---

## What Gets Removed (Bloatware)

| App | Package |
|---|---|
| Audio Player (Decibels) | `decibels` |
| Video Player (Showtime) | `showtime` |
| Boxes | `gnome-boxes` |
| Camera | `snapshot` |
| Characters | `gnome-characters` |
| Connections | `gnome-connections` |
| Contacts | `gnome-contacts` |
| Disks | `gnome-disk-utility` |
| Disk Usage Analyzer | `baobab` |
| Fedora Media Writer | `mediawriter` |
| Fonts | `gnome-font-viewer` |
| GNOME Color Manager | `gnome-color-manager` |
| LibreOffice (default) | `libreoffice*` |
| Logs | `gnome-logs` |
| Maps | `gnome-maps` |
| Music | `gnome-music` |
| Parental Controls | `malcontent-control` |
| Problem Reporting | `abrt` + related |
| Rhythmbox | `rhythmbox` |
| System Monitor | `gnome-system-monitor` |
| Tour | `gnome-tour` |
| Totem | `totem` |
| Weather | `gnome-weather` |

---

## What Gets Installed

### System Packages
`make` `git` `wget` `curl` `cabextract` `unzip` `fontconfig` `gnome-extensions-app` `gnome-tweaks` `meson` `ninja-build` `gettext` `gnome-menus` `glib2-devel` `htop` `fastfetch` `chromium` `openssh-server` `gnome-remote-desktop` `remmina` `tuned` `tuned-ppd` `zsh` `zsh-autosuggestions` `zsh-syntax-highlighting`

### Flatpak (from Flathub)
- Thunderbird
- LibreOffice
- Slack
- Flatseal
- Extension Manager

### Other
- NoMachine (latest RPM, dynamically fetched)
- ZeroTier

### GNOME Extensions
- Dash-to-Panel
- ArcMenu
- Desktop Icons NG (DING)
- AppIndicator Support

---

## Desktop Settings Applied

- **Taskbar** — Dash-to-Panel at bottom, Windows-style
- **Start menu** — ArcMenu with custom icon
- **Icons** — Win11-dark theme
- **Wallpaper** — Custom Windows-style wallpaper
- **Pinned apps** — Firefox, Nautilus, Slack, Thunderbird, Remmina
- **Window buttons** — Minimize, Maximize, Close
- **Keyboard layouts** — US + Bulgarian Traditional Phonetic
- **Locale** — `bg_BG.UTF-8`
- **Hot corners** — Disabled
- **Workspaces** — Fixed, 1 workspace
- **Power** — Never sleep, never hibernate, never dim, screen lock disabled, power button does nothing, performance profile via tuned
- **Nautilus** — Tree view, permanent delete, create link, sort directories first, recursive search, thumbnails, item counts
- **Shell** — ZSH with Oh My ZSH, jonathan theme, autosuggestions, syntax highlighting, fast-syntax-highlighting, autocomplete

---

## Remote Access

### SSH
Installed and enabled automatically. Connect with:
```bash
ssh username@machine-ip
```

### RDP (GNOME Remote Desktop)
Enabled automatically with a self-signed TLS certificate. Port 3389 is opened in the firewall. After setup, set credentials manually with:
```bash
grdctl rdp set-credentials <username> <password>

---

## Logging

Every step is logged with timestamps to:
```
~/winstall.log
```

Check this file if anything goes wrong. Each run appends to the same log so you have a full history.

---

## Notes

- Script must be run as a **normal user**, not root or with sudo
- Firmware updates are attempted but will show warnings on VMs — this is expected
- Intel and AMD codec installs will log warnings if the hardware is not present — this is expected and non-fatal
- Google Fonts download is large (~600MB) and may take a while on slow connections
- RDP credentials must be set manually after setup — they are intentionally not stored in the script

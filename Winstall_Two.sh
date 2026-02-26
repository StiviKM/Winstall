#!/bin/bash
# =============================================================================
# Winstall_Two.sh - Fedora 43 Windows Lookalike Setup - Stage 2
# Runs automatically after reboot via autostart entry
# =============================================================================

set -e

# === Logging Setup ===
LOG_FILE="$HOME/winstall.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
log_section() { echo; echo "========================================"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] >>> $1"; echo "========================================"; }

color_echo() {
  case "$1" in
    red)    echo -e "\e[31m$2\e[0m" ;;
    green)  echo -e "\e[32m$2\e[0m" ;;
    yellow) echo -e "\e[33m$2\e[0m" ;;
    blue)   echo -e "\e[34m$2\e[0m" ;;
    *)      echo "$2" ;;
  esac
}

ACTUAL_USER=$(logname 2>/dev/null || echo "$USER")
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
WINSTALL_DIR="$ACTUAL_HOME/Winstall"

# === Request sudo once and keep it alive for the entire script ===
color_echo "yellow" "🔑 Please enter your password once to authorize the setup:"
sudo -v
while true; do sudo -n true; sleep 60; done &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT

log "Stage 2 started by user: $ACTUAL_USER"
color_echo "blue" "🚀 Starting Winstall Stage 2..."

# =============================================================================
# SECTION 1: Wait for GNOME Shell to be Ready
# =============================================================================
log_section "Waiting for GNOME Shell"

color_echo "yellow" "⏳ Waiting for GNOME Shell to initialize..."
MAX_WAIT=120
WAITED=0
until gnome-extensions list &>/dev/null; do
  sleep 3
  WAITED=$((WAITED + 3))
  if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    log "ERROR: GNOME Shell did not become ready within ${MAX_WAIT}s"
    color_echo "red" "❌ GNOME Shell not ready after ${MAX_WAIT}s. Exiting."
    exit 1
  fi
done

log "GNOME Shell ready after ${WAITED}s"
color_echo "green" "✅ GNOME Shell is ready."

# Extra buffer for extensions to fully register
sleep 5

# =============================================================================
# SECTION 2: Load Extension Configurations via dconf
# =============================================================================
log_section "Loading Extension Configurations"

DTP_CONF="$WINSTALL_DIR/Dash_To_Panel_Win"
ARC_CONF="$WINSTALL_DIR/Arc_Menu_Win"

# Dash-to-Panel config
if [ -f "$DTP_CONF" ]; then
  color_echo "yellow" "Loading Dash-to-Panel config..."
  dconf load /org/gnome/shell/extensions/dash-to-panel/ < "$DTP_CONF"
  log "Dash-to-Panel config loaded"
else
  log "WARNING: Dash_To_Panel_Win config not found at $DTP_CONF"
  color_echo "yellow" "⚠️  Dash-to-Panel config not found, skipping."
fi

# ArcMenu config - update home directory path then load
if [ -f "$ARC_CONF" ]; then
  color_echo "yellow" "Updating ArcMenu config for current user home directory..."
  # Make a temp copy with updated paths
  ARC_CONF_TMP="/tmp/Arc_Menu_Win_tmp"
  sed "s|/home/[^/]*/\.arc_icon\.png|$ACTUAL_HOME/.arc_icon.png|g" "$ARC_CONF" > "$ARC_CONF_TMP"
  color_echo "yellow" "Loading ArcMenu config..."
  dconf load /org/gnome/shell/extensions/arcmenu/ < "$ARC_CONF_TMP"
  rm -f "$ARC_CONF_TMP"
  log "ArcMenu config loaded"
else
  log "WARNING: Arc_Menu_Win config not found at $ARC_CONF"
  color_echo "yellow" "⚠️  ArcMenu config not found, skipping."
fi

color_echo "green" "✅ Extension configs loaded."

# =============================================================================
# SECTION 3: Install Win11 Icon Theme
# =============================================================================
log_section "Installing Win11 Icon Theme"

ICON_DIR="/tmp/Win11-icon-theme"
rm -rf "$ICON_DIR"

color_echo "yellow" "Cloning Win11 icon theme..."
git clone https://github.com/yeyushengfan258/Win11-icon-theme.git "$ICON_DIR"
cd "$ICON_DIR"
chmod +x ./install.sh
color_echo "yellow" "Installing Win11 icon theme (all variants)..."
./install.sh -a
cd ~
rm -rf "$ICON_DIR"
log "Win11 icon theme installed"

color_echo "yellow" "Applying Win11-dark icon theme..."
gsettings set org.gnome.desktop.interface icon-theme "Win11-dark"
log "Icon theme set to Win11-dark"

color_echo "green" "✅ Win11 icon theme installed and applied."

# =============================================================================
# SECTION 4: Set Wallpaper
# =============================================================================
log_section "Setting Wallpaper"

WALLPAPER_SRC="$WINSTALL_DIR/Wallpaper.jpg"
WALLPAPER_DST="$ACTUAL_HOME/.win_wallpaper.jpg"

if [ -f "$WALLPAPER_SRC" ]; then
  color_echo "yellow" "Moving and applying wallpaper..."
  mv -f "$WALLPAPER_SRC" "$WALLPAPER_DST"
  gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_DST"
  gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER_DST"
  log "Wallpaper set to $WALLPAPER_DST"
  color_echo "green" "✅ Wallpaper applied."
else
  log "WARNING: Wallpaper.jpg not found at $WALLPAPER_SRC"
  color_echo "yellow" "⚠️  Wallpaper.jpg not found, skipping."
fi

# =============================================================================
# SECTION 5: Enable GNOME Extensions
# =============================================================================
log_section "Enabling GNOME Extensions"

color_echo "yellow" "Enabling extensions..."

gnome-extensions enable dash-to-panel@jderose9.github.com \
  && log "Dash-to-Panel enabled" \
  || log "WARNING: Could not enable Dash-to-Panel"

gnome-extensions enable ding@rastersoft.com \
  && log "Desktop Icons NG enabled" \
  || log "WARNING: Could not enable Desktop Icons NG"

gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com \
  && log "AppIndicator Support enabled" \
  || log "WARNING: Could not enable AppIndicator Support"

# ArcMenu: enable, wait, disable, wait, re-enable to ensure it loads config fully
color_echo "yellow" "Enabling ArcMenu (with reload cycle)..."
gnome-extensions enable arcmenu@arcmenu.com \
  && log "ArcMenu enabled (first pass)" \
  || log "WARNING: Could not enable ArcMenu on first pass"
sleep 3
gnome-extensions disable arcmenu@arcmenu.com 2>/dev/null || true
sleep 2
gnome-extensions enable arcmenu@arcmenu.com \
  && log "ArcMenu re-enabled (second pass)" \
  || log "WARNING: Could not re-enable ArcMenu on second pass"

color_echo "green" "✅ Extensions enabled."

# =============================================================================
# SECTION 6: GNOME Desktop Settings
# =============================================================================
log_section "Configuring GNOME Desktop Settings"

# --- Window Buttons ---
color_echo "yellow" "Setting minimize/maximize buttons..."
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
log "Window buttons configured"

# --- Taskbar / Pinned Apps ---
color_echo "yellow" "Setting pinned apps..."
gsettings set org.gnome.shell favorite-apps "['org.mozilla.firefox.desktop', 'org.gnome.Nautilus.desktop', 'com.slack.Slack.desktop', 'org.mozilla.Thunderbird.desktop', 'org.remmina.Remmina.desktop']"
log "Pinned apps set"

# --- Locale & Keyboard ---
color_echo "yellow" "Setting locale and keyboard layouts..."
gsettings set org.gnome.system.locale region 'bg_BG.UTF-8'
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'bg+phonetic')]"
log "Locale set to bg_BG.UTF-8, keyboard: US + Bulgarian Phonetic"

# --- Multitasking ---
color_echo "yellow" "Configuring multitasking settings..."
gsettings set org.gnome.desktop.interface enable-hot-corners false
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 1
log "Hot corners disabled, fixed 1 workspace"

# --- Power Settings (Never Sleep/Hibernate/Dim) ---
color_echo "yellow" "Configuring power settings (never sleep)..."
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false

# Disable suspend/hibernate via systemd (system-wide)
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
log "Sleep, hibernate, suspend disabled"

# Set performance power profile using tuned (Fedora 41+) or powerprofilesctl fallback
color_echo "yellow" "Setting performance power profile..."
if systemctl is-active --quiet tuned 2>/dev/null; then
  sudo tuned-adm profile throughput-performance 2>/dev/null \
    && log "Power profile set to throughput-performance via tuned" \
    || log "WARNING: tuned profile set failed"
elif command -v powerprofilesctl &>/dev/null; then
  powerprofilesctl set performance 2>/dev/null \
    && log "Power profile set to performance via powerprofilesctl" \
    || log "WARNING: Could not set performance power profile"
else
  log "WARNING: No power profile manager found (tuned or powerprofilesctl)"
fi

color_echo "green" "✅ Power settings configured."

# --- Nautilus Settings ---
color_echo "yellow" "Configuring Nautilus..."
gsettings set org.gnome.nautilus.list-view use-tree-view true
gsettings set org.gnome.nautilus.preferences show-delete-permanently true
gsettings set org.gnome.nautilus.preferences show-create-link true
gsettings set org.gtk.gtk4.Settings.FileChooser sort-directories-first true 2>/dev/null \
  || log "WARNING: GTK4 FileChooser sort-directories-first not available"
gsettings set org.gnome.nautilus.preferences recursive-search 'always'
gsettings set org.gnome.nautilus.preferences show-image-thumbnails 'always'
gsettings set org.gnome.nautilus.preferences show-directory-item-counts 'always'
log "Nautilus configured"

color_echo "green" "✅ Desktop settings applied."

# =============================================================================
# SECTION 7: GNOME Remote Desktop (RDP) Setup
# =============================================================================
log_section "Configuring GNOME Remote Desktop"

color_echo "yellow" "Enabling GNOME Remote Desktop (RDP)..."

# Ensure gnome-remote-desktop service is enabled
systemctl --user enable gnome-remote-desktop.service 2>/dev/null || true
systemctl --user start gnome-remote-desktop.service 2>/dev/null || true

gsettings set org.gnome.desktop.remote-desktop.rdp enable true
gsettings set org.gnome.desktop.remote-desktop.rdp view-only false
gsettings set org.gnome.desktop.remote-desktop.rdp prompt-enabled false
gsettings set org.gnome.desktop.remote-desktop.rdp authentication-methods "['password']"

# Generate TLS certificate for RDP if not already present
RDP_CERT_DIR="$ACTUAL_HOME/.local/share/gnome-remote-desktop/certificates"
if [ ! -f "$RDP_CERT_DIR/rdp-tls.crt" ]; then
  mkdir -p "$RDP_CERT_DIR"
  openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
    -subj "/CN=$(hostname)" \
    -keyout "$RDP_CERT_DIR/rdp-tls.key" \
    -out "$RDP_CERT_DIR/rdp-tls.crt" 2>/dev/null
  gsettings set org.gnome.desktop.remote-desktop.rdp tls-cert "$RDP_CERT_DIR/rdp-tls.crt"
  gsettings set org.gnome.desktop.remote-desktop.rdp tls-key "$RDP_CERT_DIR/rdp-tls.key"
  log "RDP TLS certificate generated"
else
  log "RDP TLS certificate already exists"
fi

# Open RDP port in firewall
sudo firewall-cmd --permanent --add-port=3389/tcp 2>/dev/null && \
  sudo firewall-cmd --reload 2>/dev/null && \
  log "Firewall: RDP port 3389 opened" || \
  log "WARNING: Could not configure firewall for RDP"

color_echo "yellow" "⚠️  RDP credentials not set - set them manually with:"
color_echo "yellow" "    grdctl rdp set-credentials <username> <password>"
log "RDP enabled - credentials must be set manually"

color_echo "green" "✅ GNOME Remote Desktop configured."

# =============================================================================
# SECTION 8: Create Remmina RDP Profile
# =============================================================================
log_section "Creating Remmina RDP Profile"

color_echo "yellow" "Creating Remmina connection profile for Gensoft..."
REMMINA_DIR="$ACTUAL_HOME/.local/share/remmina"
mkdir -p "$REMMINA_DIR"

cat > "$REMMINA_DIR/group_rdp_gensoft_10-100-33-60.remmina" <<EOF
[remmina]
password=.
gateway_username=
notes_text=
vc=
window_height=480
smartcard_pin=
preferipv6=0
ssh_tunnel_loopback=0
serialname=
tls-seclevel=0
sound=off
printer_overrides=
name=Gensoft
console=0
colordepth=99
security=
smartcard-logon=0
precommand=
disable_fastpath=0
postcommand=
left-handed=0
ssh_tunnel_command_args=
group=
server=10.100.33.60
ssh_tunnel_certfile=
glyph-cache=0
rdp_idle_keypress_combo=1
disableclipboard=0
rdp_idle_keypress_time=No
audio-output=
ssh_tunnel_command=
monitorids=
cert_ignore=1
disconnect-prompt=0
parallelpath=
protocol=RDP
old-license=0
labels=
ssh_tunnel_password=
resolution_mode=2
ssh_tunnel_enabled=0
assistance_mode=0
pth=
disableautoreconnect=0
loadbalanceinfo=
clientbuild=
gateway_server=
multitransport=1
clientname=
resolution_width=0
allow_empty_pass=0
drive=
serialpermissive=0
relax-order-checks=0
base-cred-for-gw=0
gateway_domain=
network=none
rdp2tcp=
serialdriver=
rdp_reconnect_attempts=
domain=
gateway_password=
username=
restricted-admin=0
force_multimon=0
exec=
multimon=0
serialpath=
enable-autostart=0
smartcardname=
profile-lock=0
ssh_tunnel_passphrase=
usb=
shareprinter=1
disablepasswordstoring=0
quality=0
span=0
shareparallel=0
parallelname=
viewmode=1
ssh_tunnel_auth=0
keymap=
ssh_tunnel_username=
execpath=
shareserial=0
resolution_height=0
rdp_mouse_jitter=No
useproxyenv=0
sharesmartcard=0
freerdp_log_filters=
microphone=
timeout=
ssh_tunnel_privatekey=
gwtransp=http
ssh_tunnel_server=
ignore-tls-errors=1
window_maximize=1
forceipvx=0
dvc=
gateway_usage=0
window_width=838
no-suppress=0
freerdp_log_level=INFO
websockets=0
disable-smooth-scrolling=0
EOF

chown "$ACTUAL_USER:$ACTUAL_USER" "$REMMINA_DIR/group_rdp_gensoft_10-100-33-60.remmina"
log "Remmina Gensoft profile created"

color_echo "green" "✅ Remmina profile created."

# =============================================================================
# SECTION 9: Cleanup
# =============================================================================
log_section "Cleanup"

color_echo "yellow" "Cleaning up..."

# Remove autostart entry FIRST so it never runs again on next login
AUTOSTART_FILE="$ACTUAL_HOME/.config/autostart/winstall_two.desktop"
rm -f "$AUTOSTART_FILE"
log "Autostart entry removed"

# Remove Winstall directory
# Note: we use a subshell cd to home first so we are never inside the deleted dir
cd "$ACTUAL_HOME"
rm -rf "$WINSTALL_DIR"
log "Winstall directory removed"

color_echo "green" "✅ Cleanup complete."

# =============================================================================
# DONE - Reboot
# =============================================================================
log_section "Stage 2 Complete"

color_echo "green" ""
color_echo "green" "╔══════════════════════════════════════════╗"
color_echo "green" "║   ✅ Winstall Complete! Rebooting...     ║"
color_echo "green" "║   Log saved to: ~/winstall.log           ║"
color_echo "green" "╚══════════════════════════════════════════╝"
color_echo "green" ""

kill $SUDO_KEEPALIVE_PID 2>/dev/null || true
log "Winstall Stage 2 complete. Rebooting in 15 seconds..."
echo
echo "Rebooting in 15 seconds... Press Ctrl+C to cancel."
sleep 15
sudo reboot

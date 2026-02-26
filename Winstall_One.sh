#!/bin/bash
# =============================================================================
# Winstall_One.sh - Fedora 43 Windows Lookalike Setup - Stage 1
# =============================================================================

set -e

# === Logging Setup ===
LOG_FILE="$HOME/winstall.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
log_section() { echo; echo "========================================"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] >>> $1"; echo "========================================"; }

# === Color Output ===
color_echo() {
  case "$1" in
    red)    echo -e "\e[31m$2\e[0m" ;;
    green)  echo -e "\e[32m$2\e[0m" ;;
    yellow) echo -e "\e[33m$2\e[0m" ;;
    blue)   echo -e "\e[34m$2\e[0m" ;;
    *)      echo "$2" ;;
  esac
}

# === Root Check ===
if [ "$EUID" -eq 0 ]; then
  color_echo "red" "❌ Please run this script as a normal user, not with sudo."
  exit 1
fi

# === Detect Actual User ===
ACTUAL_USER=$(logname 2>/dev/null || echo "$USER")
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

# === Request sudo once and keep it alive for the entire script ===
color_echo "yellow" "🔑 Please enter your password once to authorize the installation:"
sudo -v
# Keep sudo alive in background until script exits
while true; do sudo -n true; sleep 60; done &
SUDO_KEEPALIVE_PID=$!
# Make sure we kill the keepalive on exit (normal or error)
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT

log "Script started by user: $ACTUAL_USER (home: $ACTUAL_HOME)"
color_echo "blue" "🚀 Starting Winstall Stage 1..."

# =============================================================================
# SECTION 1: System Update & DNF Configuration
# =============================================================================
log_section "System Update & DNF Configuration"

color_echo "yellow" "Configuring DNF for faster downloads..."
if ! grep -q "max_parallel_downloads" /etc/dnf/dnf.conf; then
  sudo cp /etc/dnf/dnf.conf /etc/dnf/dnf.conf.bak."$(date +%Y%m%d%H%M%S)"
  echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf > /dev/null
  log "DNF max_parallel_downloads set to 10"
else
  log "DNF max_parallel_downloads already configured"
fi

color_echo "yellow" "Installing DNF plugins..."
sudo dnf -y install dnf-plugins-core
log "DNF plugins installed"

color_echo "yellow" "Running system update and upgrade..."
sudo dnf update -y
sudo dnf upgrade -y
sudo dnf autoremove -y
log "System update complete"

color_echo "yellow" "Enabling DNF automatic updates..."
sudo dnf install -y dnf5-plugin-automatic
# Copy the default config template if not already present
if [ ! -f /etc/dnf/automatic.conf ]; then
  sudo cp /usr/share/dnf5/dnf5-plugins/automatic.conf /etc/dnf/automatic.conf
  log "DNF automatic config template copied"
fi
sudo sed -i 's/apply_updates = false/apply_updates = true/' /etc/dnf/automatic.conf
sudo sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf
sudo systemctl enable --now dnf5-automatic.timer
log "DNF automatic updates enabled"

color_echo "green" "✅ System update and DNF configuration complete."

# =============================================================================
# SECTION 2: RPM Fusion & Flatpak Setup
# =============================================================================
log_section "RPM Fusion & Flatpak Setup"

color_echo "yellow" "Enabling RPM Fusion repositories..."
sudo dnf install -y \
  "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
sudo dnf update @core -y
log "RPM Fusion enabled"

color_echo "yellow" "Setting up Flathub..."
sudo dnf install -y flatpak
flatpak remote-delete fedora --force 2>/dev/null || true
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak repair
flatpak update -y
log "Flathub configured"

color_echo "green" "✅ RPM Fusion and Flatpak setup complete."

# =============================================================================
# SECTION 3: Multimedia Codecs & Hardware Acceleration
# =============================================================================
log_section "Multimedia Codecs & Hardware Acceleration"

color_echo "yellow" "Installing multimedia codecs..."
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing || log "WARNING: ffmpeg swap failed, may already be installed"
sudo dnf group install -y multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin || log "WARNING: multimedia group install failed"
sudo dnf group install -y sound-and-video || log "WARNING: sound-and-video group install failed"
log "Multimedia codecs installed"

color_echo "yellow" "Installing Intel hardware accelerated codecs..."
sudo dnf install -y intel-media-driver || log "WARNING: intel-media-driver not available on this hardware"

color_echo "yellow" "Installing AMD hardware accelerated codecs..."
sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld || log "WARNING: AMD VA drivers swap failed"
sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld || log "WARNING: AMD VDPAU drivers swap failed"
log "Hardware codecs setup attempted"

color_echo "green" "✅ Multimedia codecs complete."

# =============================================================================
# SECTION 4: SSH & Remote Services
# =============================================================================
log_section "SSH Setup"

color_echo "yellow" "Installing and enabling SSH server..."
sudo dnf install -y openssh-server
sudo systemctl enable --now sshd
log "SSH server installed and enabled"

color_echo "green" "✅ SSH setup complete."

# =============================================================================
# SECTION 5: Firmware Updates
# =============================================================================
log_section "Firmware Updates"

color_echo "yellow" "Checking for firmware updates..."
sudo fwupdmgr refresh --force || log "WARNING: fwupdmgr refresh failed"
sudo fwupdmgr get-updates || log "INFO: No firmware updates available or fwupdmgr error"
sudo fwupdmgr update -y || log "WARNING: Firmware update failed or not needed"
log "Firmware update step complete"

color_echo "green" "✅ Firmware update step complete."

# =============================================================================
# SECTION 6: Remove Bloatware
# =============================================================================
log_section "Removing Bloatware"

color_echo "yellow" "Removing unwanted pre-installed applications..."
BLOAT_PACKAGES=(
  gnome-music
  gnome-boxes
  snapshot
  gnome-characters
  gnome-connections
  gnome-contacts
  gnome-disk-utility
  baobab
  mediawriter
  gnome-font-viewer
  gnome-color-manager
  "libreoffice*"
  gnome-logs
  gnome-maps
  malcontent-control
  abrt
  abrt-desktop
  abrt-java-connector
  abrt-cli
  abrt-libs
  abrt-gui
  gnome-system-monitor
  gnome-tour
  totem
  showtime
  decibels
  gnome-weather
  rhythmbox
)

for pkg in "${BLOAT_PACKAGES[@]}"; do
  sudo dnf remove -y "$pkg" 2>/dev/null && log "Removed: $pkg" || log "INFO: $pkg not installed or already removed"
done

color_echo "green" "✅ Bloatware removal complete."

# =============================================================================
# SECTION 7: Install Required Dependencies & Packages
# =============================================================================
log_section "Installing Required Packages"

color_echo "yellow" "Installing core dependencies..."
sudo dnf install -y \
  make \
  git \
  wget \
  curl \
  cabextract \
  unzip \
  fontconfig \
  xorg-x11-font-utils \
  gnome-extensions-app \
  gnome-tweaks \
  meson \
  ninja-build \
  gettext \
  gnome-menus \
  glib2-devel \
  htop \
  fastfetch \
  chromium \
  openssh-server \
  gnome-remote-desktop \
  tuned \
  tuned-ppd \
  remmina
log "Core packages installed"

color_echo "green" "✅ Core packages installed."

# =============================================================================
# SECTION 8: Install Flatpak Applications
# =============================================================================
log_section "Installing Flatpak Applications"

color_echo "yellow" "Installing Thunderbird..."
flatpak install -y flathub org.mozilla.Thunderbird
log "Thunderbird installed"

color_echo "yellow" "Installing LibreOffice..."
flatpak install -y flathub org.libreoffice.LibreOffice
flatpak install -y --reinstall org.freedesktop.Platform.Locale/x86_64/24.08 || log "WARNING: LibreOffice locale platform reinstall failed"
flatpak install -y --reinstall org.libreoffice.LibreOffice.Locale || log "WARNING: LibreOffice locale reinstall failed"
log "LibreOffice installed"

color_echo "yellow" "Installing Flatseal..."
flatpak install -y flathub com.github.tchx84.Flatseal
log "Flatseal installed"

color_echo "yellow" "Installing Extension Manager..."
flatpak install -y flathub com.mattjakeman.ExtensionManager
log "Extension Manager installed"

color_echo "yellow" "Installing Slack..."
flatpak install -y flathub com.slack.Slack
log "Slack installed"

color_echo "green" "✅ Flatpak applications installed."

# =============================================================================
# SECTION 9: Install NoMachine (Dynamic Latest Version)
# =============================================================================
log_section "Installing NoMachine"

color_echo "yellow" "Fetching latest NoMachine RPM URL..."

NX_URL=$(curl -s "https://www.nomachine.com/download/download&id=1" \
  | grep -oP 'https://download\.nomachine\.com/download/[^"]+x86_64\.rpm' \
  | head -1)

if [ -z "$NX_URL" ]; then
  # Fallback: try the download page directly
  NX_URL=$(curl -s "https://www.nomachine.com/download" \
    | grep -oP 'https://download\.nomachine\.com/download/[^"]+x86_64\.rpm' \
    | head -1)
fi

if [ -z "$NX_URL" ]; then
  log "WARNING: Could not dynamically fetch NoMachine URL, using known latest version"
  NX_URL="https://download.nomachine.com/download/9.3/Linux/nomachine_9.3.7_1_x86_64.rpm"
fi

log "NoMachine download URL: $NX_URL"
NX_RPM="/tmp/nomachine_latest_x86_64.rpm"
wget -O "$NX_RPM" "$NX_URL"
sudo dnf install -y "$NX_RPM"
rm -f "$NX_RPM"
log "NoMachine installed"

color_echo "green" "✅ NoMachine installed."

# =============================================================================
# SECTION 10: Install ZeroTier
# =============================================================================
log_section "Installing ZeroTier"

color_echo "yellow" "Installing ZeroTier..."
curl -s 'https://raw.githubusercontent.com/zerotier/ZeroTierOne/main/doc/contact%40zerotier.com.gpg' | gpg --import
if z=$(curl -s 'https://install.zerotier.com/' | gpg); then
  echo "$z" | sudo bash
  log "ZeroTier installed"
else
  log "WARNING: ZeroTier GPG verification failed, trying direct install"
  curl -s https://install.zerotier.com | sudo bash
  log "ZeroTier installed via fallback"
fi

color_echo "green" "✅ ZeroTier installed."

# =============================================================================
# SECTION 11: Clone Winstall Repository & Install GNOME Extensions
# =============================================================================
log_section "Cloning Winstall Repository"

WINSTALL_DIR="$ACTUAL_HOME/Winstall"
if [ -d "$WINSTALL_DIR" ]; then
  log "Winstall directory already exists, pulling latest..."
  git -C "$WINSTALL_DIR" pull
else
  git clone https://github.com/StiviKM/Winstall "$WINSTALL_DIR"
  log "Winstall repository cloned"
fi

color_echo "yellow" "Copying hidden icon file..."
cp "$WINSTALL_DIR/.arc_icon.png" "$ACTUAL_HOME/.arc_icon.png"
log "Icon file copied"

log_section "Installing GNOME Extensions"

# --- Dash-to-Panel ---
color_echo "yellow" "Installing Dash-to-Panel..."
DTP_DIR="/tmp/dash-to-panel"
rm -rf "$DTP_DIR"
git clone https://github.com/home-sweet-gnome/dash-to-panel.git "$DTP_DIR"
cd "$DTP_DIR"
make install
cd ~
rm -rf "$DTP_DIR"
log "Dash-to-Panel installed"

# --- ArcMenu ---
color_echo "yellow" "Installing ArcMenu..."
ARCMENU_DIR="/tmp/ArcMenu"
rm -rf "$ARCMENU_DIR"
git clone https://gitlab.com/arcmenu/ArcMenu.git "$ARCMENU_DIR"
cd "$ARCMENU_DIR"
make install
cd ~
rm -rf "$ARCMENU_DIR"
log "ArcMenu installed"

# --- Desktop Icons NG ---
color_echo "yellow" "Installing Desktop Icons NG..."
DING_DIR="/tmp/desktop-icons-ng"
rm -rf "$DING_DIR"
git clone https://gitlab.com/rastersoft/desktop-icons-ng.git "$DING_DIR"
cd "$DING_DIR"
chmod +x ./local_install.sh
./local_install.sh
cd ~
rm -rf "$DING_DIR"
log "Desktop Icons NG installed"

# --- AppIndicator Support ---
color_echo "yellow" "Installing AppIndicator Support..."
APPIND_DIR="/tmp/gnome-shell-extension-appindicator"
APPIND_BUILD="/tmp/g-s-appindicators-build"
rm -rf "$APPIND_DIR" "$APPIND_BUILD"
git clone https://github.com/ubuntu/gnome-shell-extension-appindicator.git "$APPIND_DIR"
meson --prefix="$ACTUAL_HOME/.local" "$APPIND_DIR" "$APPIND_BUILD"
ninja -C "$APPIND_BUILD" install
rm -rf "$APPIND_DIR" "$APPIND_BUILD"
log "AppIndicator Support installed"

color_echo "green" "✅ All GNOME extensions installed."


# =============================================================================
# SECTION 12: Install ZSH + Oh My ZSH
# =============================================================================
log_section "Installing ZSH and Oh My ZSH"

color_echo "yellow" "Installing ZSH..."
sudo dnf install -y zsh zsh-autosuggestions zsh-syntax-highlighting
log "ZSH packages installed"

color_echo "yellow" "Installing Oh My ZSH..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
log "Oh My ZSH installed"

color_echo "yellow" "Installing ZSH plugins..."
git clone https://github.com/zsh-users/zsh-autosuggestions.git \
  "${ZSH_CUSTOM:-$ACTUAL_HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" 2>/dev/null \
  || log "INFO: zsh-autosuggestions plugin already exists"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
  "${ZSH_CUSTOM:-$ACTUAL_HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" 2>/dev/null \
  || log "INFO: zsh-syntax-highlighting plugin already exists"
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git \
  "${ZSH_CUSTOM:-$ACTUAL_HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting" 2>/dev/null \
  || log "INFO: fast-syntax-highlighting plugin already exists"
git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git \
  "${ZSH_CUSTOM:-$ACTUAL_HOME/.oh-my-zsh/custom}/plugins/zsh-autocomplete" 2>/dev/null \
  || log "INFO: zsh-autocomplete plugin already exists"
log "ZSH plugins installed"

color_echo "yellow" "Configuring .zshrc..."
ZSHRC="$ACTUAL_HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
  sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)/' "$ZSHRC"
  log ".zshrc plugins configured"
else
  log "WARNING: .zshrc not found, Oh My ZSH may not have installed correctly"
fi

color_echo "yellow" "Setting ZSH as default shell..."
sudo chsh -s "$(which zsh)" "$ACTUAL_USER"
log "Default shell changed to ZSH for $ACTUAL_USER"

color_echo "green" "✅ ZSH and Oh My ZSH installed."
# =============================================================================
# SECTION 12: Install Fonts
# =============================================================================
log_section "Installing Fonts"

FONTS_DIR="$ACTUAL_HOME/.local/share/fonts"
mkdir -p "$FONTS_DIR/windows" "$FONTS_DIR/google"

color_echo "yellow" "Installing Microsoft Windows fonts..."
wget -O /tmp/winfonts.zip https://mktr.sbs/fonts
unzip -o /tmp/winfonts.zip -d "$FONTS_DIR/windows"
rm -f /tmp/winfonts.zip
log "Windows fonts installed"

log "INFO: Google Fonts skipped for testing"

fc-cache -fv
log "Font cache updated"

color_echo "green" "✅ Fonts installed."

# =============================================================================
# SECTION 13: Schedule Winstall_Two.sh After Reboot
# =============================================================================
log_section "Scheduling Stage 2"

# Detect available terminal emulator
if command -v ptyxis &>/dev/null; then
  TERMINAL="ptyxis --"
elif command -v gnome-terminal &>/dev/null; then
  TERMINAL="gnome-terminal --"
elif command -v xterm &>/dev/null; then
  TERMINAL="xterm -e"
else
  TERMINAL="bash -c"
  log "WARNING: No known terminal emulator found, autostart may not show a window"
fi

log "Using terminal: $TERMINAL"

AUTOSTART_DIR="$ACTUAL_HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/winstall_two.desktop"
STAGE2_SCRIPT="$WINSTALL_DIR/Winstall_Two.sh"

mkdir -p "$AUTOSTART_DIR"
chmod +x "$STAGE2_SCRIPT"

cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Exec=$TERMINAL bash -c '$STAGE2_SCRIPT; echo; echo "✅ Winstall Stage 2 finished. Check ~/winstall.log for details."; read -p "Press Enter to close..."'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Winstall Stage 2
Comment=Completes the Winstall setup after reboot
EOF

log "Stage 2 autostart entry created at $AUTOSTART_FILE"
color_echo "green" "✅ Stage 2 scheduled for after reboot."

# =============================================================================
# DONE - Reboot
# =============================================================================
log_section "Stage 1 Complete - Rebooting"
color_echo "green" "✅ Winstall Stage 1 complete! Rebooting in 10 seconds..."
kill $SUDO_KEEPALIVE_PID 2>/dev/null || true
log "Rebooting system..."
sleep 10
sudo reboot

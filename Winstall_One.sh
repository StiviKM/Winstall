#!/bin/bash
set -e  # Exit on error

echo "🚀 Starting Win Lookalike installation..."

# Ensure script is not run as root
if [ "$EUID" -eq 0 ]; then
  echo "❌ Please run this script as a normal user, not with sudo."
  exit 1
fi

# === 1. Install dependencies ===
echo "📦 Installing required packages..."
sudo dnf install -y make git wget gnome-extensions-app meson ninja-build

# === 2. Clone Win_Lookalike repository ===
echo "🧩 Cloning Win Lookalike repository..."
git clone https://github.com/StiviKM/Win_Lookalike "$HOME/Win_Lookalike"

# === 3. Copy the icon file to home ===
echo "🖼️ Copying icon file..."
cp "$HOME/Win_Lookalike/.arc_icon.png" "$HOME/.arc_icon.png"

# === 4. Download and install Dash-to-Panel ===
echo "⬇️ Downloading Dash-to-Panel extension..."
wget -O /tmp/dash-to-panel.zip \
  https://github.com/home-sweet-gnome/dash-to-panel/releases/download/v72/dash-to-panel@jderose9.github.com_v72.zip

echo "🧱 Installing Dash-to-Panel..."
gnome-extensions install /tmp/dash-to-panel.zip --force

# === 5. Clone and install ArcMenu ===
echo "🧭 Cloning and installing ArcMenu..."
git clone https://gitlab.com/arcmenu/ArcMenu.git "$HOME/ArcMenu"
cd "$HOME/ArcMenu"
make install
cd ~

# === 6. Clone and install Desktop Icons NG ===
echo "🖥️ Cloning and installing Desktop Icons NG..."
git clone https://gitlab.com/rastersoft/desktop-icons-ng.git "$HOME/desktop-icons-ng"
cd "$HOME/desktop-icons-ng"
./local_install.sh
cd ~

# === 7. Clone and install AppIndicator Support ===
echo "🔔 Cloning and installing AppIndicator Support..."
git clone https://github.com/ubuntu/gnome-shell-extension-appindicator.git "$HOME/gnome-shell-extension-appindicator"
meson "$HOME/gnome-shell-extension-appindicator" /tmp/g-s-appindicators-build
ninja -C /tmp/g-s-appindicators-build install
cd ~

# === 8. Cleanup ===
rm -f /tmp/dash-to-panel.zip
rm -rf "$HOME/ArcMenu"
rm -rf "$HOME/desktop-icons-ng"
rm -rf "$HOME/gnome-shell-extension-appindicator"

# === 9. Prepare next script to run automatically on next login ===
echo "🧩 Scheduling WinLook_Second.sh to run after next login..."

AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/winlook_second.desktop"

mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Exec=ptyxis -- bash -c '$HOME/Win_Lookalike/WinLook_Second.sh; echo; echo "✅ Script finished. You can close this window."; read -p "Press Enter to close..."'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=WinLook Second Stage
Comment=Completes the Win Lookalike setup
EOF

chmod +x "$HOME/Win_Lookalike/WinLook_Second.sh"

echo "✅ WinLook_Second.sh will run automatically after next login."

# === 10. Log out to apply changes ===
echo "🔁 Logging out in 5 seconds..."
sleep 5
gnome-session-quit --logout --no-prompt


#!/usr/bin/env bash
set -euo pipefail
ask(){ printf "%s" "$1" >/dev/tty; IFS= read -r REPLY </dev/tty; }
if [[ $EUID -ne 0 ]]; then echo "run as root" >/dev/tty; exit 1; fi
echo "example:"
echo "https://example.com/index.php"
echo "http://raspberrypi.local/index.php"
echo "file:///home/dash/index.php"
ask "dashboard url (index.php)? "
URL="${REPLY:-}"
URL="$(echo "$URL" | tr -d '\r' | xargs)"
if [[ -z "$URL" ]]; then echo "empty url" >/dev/tty; exit 1; fi
if [[ "$URL" != http://* && "$URL" != https://* && "$URL" != file://* ]]; then
if [[ "$URL" == /* || "$URL" == ./* || "$URL" == ../* ]]; then
ABS="$(readlink -f "$URL" 2>/dev/null || true)"
if [[ -z "$ABS" ]]; then echo "invalid path" >/dev/tty; exit 1; fi
URL="file://$ABS"
else
echo "invalid url (must start with http://, https://, file:// or a local path like /path/to/index.php)" >/dev/tty
exit 1
fi
fi
KIOSK_USER="dash"
apt-get update
CHROMIUM_BIN="$(command -v chromium-browser || command -v chromium || true)"
if [[ -z "${CHROMIUM_BIN}" ]]; then
INSTALL_OK=0
for PKG in chromium chromium-browser; do
if apt-get install -y "$PKG"; then INSTALL_OK=1; break; fi
done
if [[ "${INSTALL_OK}" -ne 1 ]]; then echo "chromium install failed" >/dev/tty; exit 1; fi
CHROMIUM_BIN="$(command -v chromium-browser || command -v chromium || true)"
if [[ -z "${CHROMIUM_BIN}" ]]; then echo "chromium not found" >/dev/tty; exit 1; fi
fi
apt-get install -y unclutter || true
if ! id -u "${KIOSK_USER}" >/dev/null 2>&1; then adduser --disabled-password --gecos "" "${KIOSK_USER}"; fi
usermod -aG audio,video,input,gpio,render "${KIOSK_USER}" || true
AUTOSTART_DIR="/home/${KIOSK_USER}/.config/autostart"
mkdir -p "${AUTOSTART_DIR}"
chown -R "${KIOSK_USER}:${KIOSK_USER}" "/home/${KIOSK_USER}/.config"
cat > "${AUTOSTART_DIR}/dash-kiosk.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Dashboard Kiosk
Exec=${CHROMIUM_BIN} --kiosk --incognito --noerrdialogs --disable-translate --disable-infobars --check-for-update-interval=31536000 --password-store=basic --no-first-run --no-default-browser-check --ignore-certificate-errors --allow-insecure-localhost --disable-features=WebContentsForceDark --force-color-profile=srgb --disable-session-crashed-bubble --disable-pinch --overscroll-history-navigation=0 "${URL}"
X-GNOME-Autostart-enabled=true
EOF
cat > "${AUTOSTART_DIR}/unclutter.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Hide Mouse Cursor (unclutter)
Exec=/usr/bin/unclutter -idle 3 -root
X-GNOME-Autostart-enabled=true
EOF
chown "${KIOSK_USER}:${KIOSK_USER}" "${AUTOSTART_DIR}/dash-kiosk.desktop" "${AUTOSTART_DIR}/unclutter.desktop"
if getent group sudo | grep -qE "\b${KIOSK_USER}\b"; then deluser "${KIOSK_USER}" sudo || true; fi
if [[ -f /etc/lightdm/lightdm.conf ]]; then
if grep -q '^autologin-user=' /etc/lightdm/lightdm.conf; then
sed -i "s/^autologin-user=.*/autologin-user=${KIOSK_USER}/" /etc/lightdm/lightdm.conf
else
sed -i "/^\[Seat:\*\]/a autologin-user=${KIOSK_USER}" /etc/lightdm/lightdm.conf || echo "autologin-user=${KIOSK_USER}" >> /etc/lightdm/lightdm.conf
fi
if grep -q '^autologin-user-timeout=' /etc/lightdm/lightdm.conf; then
sed -i "s/^autologin-user-timeout=.*/autologin-user-timeout=0/" /etc/lightdm/lightdm.conf
else
sed -i "/^autologin-user=${KIOSK_USER}/a autologin-user-timeout=0" /etc/lightdm/lightdm.conf || echo "autologin-user-timeout=0" >> /etc/lightdm/lightdm.conf
fi
fi
KEYRING_DIR="/home/${KIOSK_USER}/.local/share/keyrings"
rm -f "${KEYRING_DIR}"/* 2>/dev/null || true
mkdir -p "${KEYRING_DIR}"
printf "[Keyring]\ndisplay-name=Login\nlock-on-idle=false\n" > "${KEYRING_DIR}/login.keyring"
chown -R "${KIOSK_USER}:${KIOSK_USER}" "/home/${KIOSK_USER}/.local"
reboot now

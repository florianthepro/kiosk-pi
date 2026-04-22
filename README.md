# 📝 Description
Setup raspberrypi with side.

run on pi:
```
curl -sSL https://raw.githubusercontent.com/florianthepro/kiosk-dashbourd/refs/heads/main/setup-pi | sudo bash
```

To Set raspberrypi hdmi on/off:
```
sudo crontab -e
30 18 * * * echo off | tee /sys/class/drm/card1-HDMI-A-2/status
30 07 * * * echo on | tee /sys/class/drm/card1-HDMI-A-2/status
```
/wake:
sudo apt install -y cec-utils

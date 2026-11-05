#!/bin/bash
# Installs the ProArt key listener: udev rule (root), script + user service.
set -e
cd "$(dirname "$0")"

sudo install -m 644 70-proart-key.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=hidraw

install -Dm 755 proart-key ~/.local/bin/proart-key
install -Dm 644 proart-key.service ~/.config/systemd/user/proart-key.service
systemctl --user daemon-reload
systemctl --user enable --now proart-key.service
systemctl --user restart proart-key.service

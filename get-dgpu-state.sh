#!/bin/bash
# Usage: get-dgpu-state.sh [pci-address]
# Prints: <address> <power_state> <runtime_status> <control>
# No address: picks the display-class PCI device that is not the boot VGA.

addr="$1"
if [ -z "$addr" ]; then
	for d in /sys/bus/pci/devices/*; do
		case "$(cat "$d/class" 2>/dev/null)" in
		0x030*) ;;
		*) continue ;;
		esac
		[ "$(cat "$d/boot_vga" 2>/dev/null)" = "1" ] && continue
		addr="${d##*/0000:}"
		break
	done
fi
[ -n "$addr" ] || exit 1

dev="/sys/bus/pci/devices/0000:${addr}"
[ -d "$dev" ] || exit 1

read_attr() { [ -f "$1" ] && tr -d '[:space:]' <"$1" || echo "?"; }

echo "${addr} $(read_attr "$dev/power_state") $(read_attr "$dev/power/runtime_status") $(read_attr "$dev/power/control")"

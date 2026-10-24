#!/bin/bash
# Prints: <ac_online 0|1> <status> <capacity %> <health % or -1>

ac_online="0"
for a in /sys/class/power_supply/ADP* /sys/class/power_supply/AC* /sys/class/power_supply/IEC*; do
	if [ -f "$a/online" ]; then
		[ "$(tr -d '[:space:]' <"$a/online")" = "1" ] && ac_online="1"
		break
	fi
done

bat_status="Unknown"
capacity="0"
health="-1"
for bat in /sys/class/power_supply/BAT*; do
	[ -d "$bat" ] || continue
	[ -f "$bat/status" ] && bat_status=$(tr -d '[:space:]' <"$bat/status")
	[ -f "$bat/capacity" ] && capacity=$(tr -d '[:space:]' <"$bat/capacity")
	# energy_* (µWh) on some firmware, charge_* (µAh) on others; the ratio is the same
	for prefix in energy charge; do
		full="$bat/${prefix}_full"
		design="$bat/${prefix}_full_design"
		if [ -f "$full" ] && [ -f "$design" ]; then
			f=$(tr -d '[:space:]' <"$full")
			d=$(tr -d '[:space:]' <"$design")
			if [ "$d" -gt 0 ] 2>/dev/null; then
				health=$(((f * 100 + d / 2) / d))
				[ "$health" -gt 100 ] && health=100
			fi
			break
		fi
	done
	break
done

echo "${ac_online} ${bat_status} ${capacity} ${health}"

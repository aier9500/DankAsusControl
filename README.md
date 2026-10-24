# Dank ASUS Control Center

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar widget for ASUS
laptops. One pill, one popout: power profile, battery wattage, dGPU power state, cardwire GPU
mode, charge limit. It replaces ROG Control Center for daily use; keep ROG Control Center only
for the one-time EPP / throttle-policy setup.

Continuation of [ASUS Control Center](https://github.com/pseudofractal/AsusControl), merged with
[dgpu-sleep-monitor](https://github.com/xantrk/dgpu-sleep-monitor).

## Bar pill

`<profile icon>  11.8 W │ D3cold`

- Icon: current `asusctl` profile (Quiet / Balanced / Performance).
- Wattage: battery draw from sysfs.
- D-state: dGPU PCI power state. Red when the dGPU is awake on battery.

## Popout

| Section       | Source                                   | Shown when              |
| ------------- | ---------------------------------------- | ----------------------- |
| Battery       | `/sys/class/power_supply/BAT*`           | a battery exists        |
| Power Profile | `asusctl profile`                        | `asusctl` installed     |
| GPU           | PCI sysfs + `cardwire get` / `set`       | dGPU found or cardwire  |
| Charge Limit  | `asusctl battery limit` / `oneshot`      | `asusctl` + battery     |

The ⚡ button next to the slider is **One Shot**: charge to 100% once, then the limit resumes.

## Requirements

- [asusctl](https://github.com/OpenGamingCollective/asusctl) with `asusd` running.
- [cardwire](https://github.com/OpenGamingCollective/cardwire) for GPU mode switching
  (optional; the section hides without it). `supergfxctl` is not supported — it is archived.

## Install

```bash
cd ~/.config/DankMaterialShell/plugins
git clone https://github.com/aier9500/DankAsusControl.git dankAsusControlCenter
dms ipc call plugins reload dankAsusControlCenter
```

Then add `dankAsusControlCenter` to a bar section in DMS settings.

## Settings

| Setting         | Default | Meaning                                                   |
| --------------- | ------- | --------------------------------------------------------- |
| Show wattage    | on      | Battery draw in the pill                                  |
| Show dGPU state | on      | D-state in the pill                                       |
| Refresh interval| 5 s     | Poll period for everything                                |
| PCI address     | auto    | dGPU address; auto picks the display device that is not the boot VGA |

## Open the popout from a key

```bash
dms ipc call widget toggle dankAsusControlCenter
```

Bind that to any key or hardware button.

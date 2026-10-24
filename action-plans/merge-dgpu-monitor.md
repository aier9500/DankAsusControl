# Merge dGPU Sleep Monitor into Dank ASUS Control

**Goal** — one DMS bar widget that replaces ROG Control Center for daily use: power profile,
battery wattage, dGPU power state, cardwire GPU mode, charge limit. ROG Control Center stays
only for the one-time EPP / throttle-policy setup.

**Sources** — this repo (profiles, charge limit, one shot) and
[dgpu-sleep-monitor](https://github.com/xantrk/dgpu-sleep-monitor) (sysfs battery + dGPU
readers, cardwire switcher). Plugin id `dankAsusControlCenter` stays, so existing bar layouts
and settings keep working.

**Dropped** — supergfxctl (archived), logout-on-GPU-switch (cardwire switches live), upower
(sysfs covers it), panel overdrive / auto-brightness, per-profile colour settings.

## Steps

1. **Data layer** — owner: main agent. Replace `upower -b` with sysfs reads from
   `dgpu-sleep-monitor` (`get-power-usage.sh`, `get-battery-status.sh`, capacity/health).
   Add `power_state`, `runtime_status` readers and `cardwire get` / `cardwire set`.
   Done: all properties populate on this P16 with no upower installed.
2. **Bar pill** — owner: main agent. Profile icon · `11.8 W` · `D3cold`; wattage and D-state
   each toggleable in settings. Done: pill matches the mock in the brief.
3. **Popout** — owner: main agent. Sections in order: Battery → Power Profile → GPU
   (state + cardwire modes) → Charge Limit. Footer: `asusctl` / `cardwire` versions.
   Done: renders under 480 px tall; every section hides when its tool is missing.
4. **Settings pane** — owner: main agent. PCI address, refresh interval, show-wattage,
   show-dGPU-state. Done: changes apply without `dms restart`.
5. **Docs** — owner: main agent. README rewritten for the new feature set; `plugin.json`
   bumped to 3.0.0. Done: README lists requirements and settings only.
6. **ProArt key** — owner: main agent, in `hypr-dms`. `proart-key/` holds the hidraw listener,
   user unit and udev rule; listener calls `dms ipc call widget toggle dankAsusControlCenter`.
   Done: button toggles the popout on the live session.
7. **Wiki** — owner: main agent, in `tuxies-wiki`. `proart-p16-2025.md` gains a "ProArt
   button" section: sniff the report, install the service. Done: follows guidelines.md
   (steps, details block for the technical why, no image yet).

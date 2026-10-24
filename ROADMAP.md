# Roadmap

## Open

- Replace `assets/popup.png` with a screenshot of the 3.0 popout; README does not embed it yet.
- Push the 3.0 merge to a fork and point `plugins.lock.json` at it (currently a symlink to
  `~/Projects/DankAsusControl`).

## Changes

- **3.0.0 (2026-10-24)** — merged dgpu-sleep-monitor. Battery, dGPU and profile in one pill
  and popout. Dropped supergfxctl, logout-on-switch, upower, panel overdrive / auto-brightness,
  per-profile colour settings. dGPU PCI address auto-detects. Health reads `energy_*` or
  `charge_*`. Plan: `action-plans/merge-dgpu-monitor.md`.

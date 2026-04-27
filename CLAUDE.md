# Lenovo TB-X304F LineageOS Flashing Project

This repo contains a printable flashing guide and helper scripts for installing
**LineageOS 17.1 (Android 10)** + **MindTheGapps 10.0 arm64** + **Magisk** on a
**Lenovo Tab 4 10 (TB-X304F WiFi)**.

## Hardware target

- Lenovo TB-X304F (Snapdragon 425 / msm8917, **ARMv8 / 64-bit**, Cortex-A53, 2GB / 16GB)
- Stock: Android 8.1.0, build `TB-X304F_S001014_181113_ROW`
- Bootloader: user reports OEM-unlock toggle on, and expects Path A (`fastboot oem unlock-go`) to succeed. **Caveat surfaced by research:** TB-X304F typically ships with the `devinfo` unlock-allowed byte set to `00` regardless of toggle state — `unlock-go` may return `FAILED (remote: oem unlock is not allowed)`. Test before assuming. EDL byte-flip workaround is documented in `guide.md` Part 3 if needed.

## Three corrections applied (vs original chat draft)

1. **arm64**, not arm. SD425 is ARMv8. MindTheGapps **10.0 arm64**, APKMirror sideloads use **arm64-v8a**.
2. Magisk installs via the canonical patched-`boot.img` path (boot LOS, app patches, `fastboot flash boot magisk_patched.img`). topjohnwu deprecated the TWRP zip-flash path in v30.7. Keep an `uninstall.zip` rename of the APK on the SD card as the TWRP-side bootloop safety net (substring detection verified in `update_binary.sh` at the v30.7 tag) and a clean LOS `boot.img` on the host as the fastboot-side recovery.
3. Use `winget install Google.PlatformTools` instead of manual zip extraction.

## Layout

- `guide.md` — printable guide, source for the PDF
- `pdf.config.js` — md-to-pdf config (5.5"×8.5", 0.5" margins, page numbers)
- `scripts/restore.ps1` — driver: installs winget items and downloads flashable artifacts to `downloads/` (in parallel, with per-file progress bars)
- `scripts/artifacts.json` — the actual artifact list; `restore.ps1` reads this and dispatches by `kind`
- `research/` — research notes; bootstrap memory for future Claude sessions
- `package.json` — `build` (PDF) and `restore` (downloads)

## npm scripts

- `npm run build` — produce `guide.pdf` from `guide.md`
- `npm run restore` — install platform-tools + download flashable artifacts to `downloads/`
- `npm run restore:check` — dry-run of the above

## `scripts/artifacts.json`

Flat array of artifact entries. `restore.ps1` dispatches each by its `kind`:

| `kind`   | Required fields                          | Behavior |
|----------|------------------------------------------|----------|
| `winget` | `package`, `label`                       | Sequential `winget install --id <package>`. Idempotent (skips if already installed). |
| `direct` | `id`, `label`, `url`, `name`             | Parallel HttpClient download from `url` to `downloads/<name>`. |
| `github` | `id`, `owner`, `repo`, `pattern`         | Parallel: resolves the latest release asset matching `pattern` via `gh release view --json`, then downloads `asset.url`. |
| `manual` | `name`, `source`                         | Not automated — printed at the end with `from: <source>` so the user fetches it themselves. |

`id` is the `Write-Progress -Id` slot for the parallel download bars; it must be unique across `direct`/`github` entries (winget/manual don't need one).

To add an artifact, edit `artifacts.json` only — `restore.ps1` doesn't need changing.

## Decisions / context worth carrying forward

- **No EDL / BLUnlocker path.** Skip QDLoader, devinfo hex edits, firehose `.mbn` — not needed. OEM unlock toggle is on.
- **Flash order:** LineageOS → GApps in TWRP (no reboot between, wipe cache/dalvik after GApps). Reboot to LOS, finish OOBE, then install Magisk via the canonical patched-`boot.img` path (Magisk app patches LOS `boot.img`, `fastboot flash boot magisk_patched.img`). The TWRP zip-flash path for Magisk is officially deprecated in v30.7 and avoided here.
- **TWRP — boot temporarily OR flash, but don't let stock Android boot between TWRP-install and LOS-flash.** Stock Android's `install-recovery.sh` re-writes `/recovery` on boot. The handoff's "booting TWRP is unreliable" claim isn't supported by research — `fastboot boot twrp.img` is the *preferred* community approach. Either path works.
- **Format Data is mandatory** before LOS flash. Stock 8.1 encryption is incompatible with LOS 17.1.
- **First boot is 5–10 min.** Multiple bootloop reports in the XDA thread are impatient flashers.
- **Root stays in.** Streaming targets (Crunchyroll, Prime) are root-tolerant; no banking use case. PIF + TrickyStore workaround for Netflix/Hulu in Appendix A if the user adds them later.
- **Widevine L3.** SD425 is L3-only. Caps are uneven: Crunchyroll plays **1080p** on L3 (outlier), Netflix **540p**, Prime / Disney+ / Max **480p–SD**.
- **PIF is a Magisk Zygisk module**, not a TWRP-flashable zip. Earlier draft had this wrong — corrected.
- **TrickyStore is optional for the in-scope streamers.** PIF alone clears Netflix; Hulu also needs Shamiko + DenyList. TrickyStore is only required for STRONG-tier integrity (banking-class apps, out of scope).

## Things to NOT do

- Don't suggest the EDL/BLUnlocker path.
- Don't switch ROMs (deadman96385's LOS 17.1 is the chosen pick for this device).
- Don't pad with brick/warranty disclaimers — risk is accepted.
- Don't over-explain shell or PowerShell. User is TS/JS/C# expert, comfortable in C++/Python.

## Commit discipline

Commit your work as each task completes. One logical change per commit, atomic — don't batch unrelated edits into a single commit, and don't leave finished work uncommitted across tasks. If a single user request spans multiple independent changes, commit them separately as you finish each one.

## Source URLs

| Item | URL |
|---|---|
| XDA thread (LineageOS + TWRP) | https://xdaforums.com/t/rom-unofficial-10-0-tb-x304f-tb-8504f-lineageos-17-1-for-lenovo-tab4-8-10-wifi.4466879/ |
| MindTheGapps 10.0 arm64 | https://github.com/MindTheGapps/10.0.0-arm64/releases |
| Magisk | https://github.com/topjohnwu/Magisk/releases |
| PlayIntegrityFork | https://github.com/osm0sis/PlayIntegrityFork |
| TrickyStore | https://github.com/5ec1cff/TrickyStore |

The LineageOS zip and TWRP `.img` are linked from the XDA thread (mailru / gdrive mirrors) and must be downloaded manually — they're not on a host the restore script can reach without scraping.

## Research notes

See `research/` for verified findings from the session bootstrap (XDA thread, GitHub releases, hardware specs, streaming compatibility). Treat those notes as the authoritative source if anything in this file disagrees with them — they were captured at a known point in time.

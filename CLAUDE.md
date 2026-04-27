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
2. Magisk install zip needs an **uninstall.zip** copy on the microSD as a safety net (TWRP-flashable to remove Magisk cleanly).
3. Use `winget install Google.PlatformTools` instead of manual zip extraction.

## Layout

- `guide.md` — printable guide, source for the PDF
- `pdf.config.js` — md-to-pdf config (5.5"×8.5", 0.5" margins, page numbers)
- `scripts/restore.ps1` — installs platform-tools (winget) and downloads flashable artifacts to `downloads/`
- `research/` — research notes; bootstrap memory for future Claude sessions
- `package.json` — `build` (PDF) and `restore` (downloads)

## npm scripts

- `npm run build` — produce `guide.pdf` from `guide.md`
- `npm run restore` — install platform-tools + download flashable artifacts to `downloads/`
- `npm run restore:check` — dry-run of the above

## Decisions / context worth carrying forward

- **No EDL / BLUnlocker path.** Skip QDLoader, devinfo hex edits, firehose `.mbn` — not needed. OEM unlock toggle is on.
- **Flash order:** LineageOS → GApps → Magisk (no reboots between). Wipe cache/dalvik once at end.
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

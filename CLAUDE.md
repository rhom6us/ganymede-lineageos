# Lenovo TB-X304F LineageOS Flashing Project

This repo contains a printable flashing guide and helper scripts for installing
**LineageOS 17.1 (Android 10)** + **MindTheGapps 10.0 arm64** + **Magisk** on a
**Lenovo Tab 4 10 (TB-X304F WiFi)**.

## Hardware target

- Lenovo TB-X304F (Snapdragon 425 / msm8917, **ARMv8 / 64-bit**, Cortex-A53, 2GB / 16GB)
- Stock: Android 8.1.0, build `TB-X304F_S001014_181113_ROW`
- Bootloader: user reports OEM-unlock toggle on, and expects Path A (`fastboot oem unlock-go`) to succeed. **Caveat surfaced by research:** TB-X304F typically ships with the `devinfo` unlock-allowed byte set to `00` regardless of toggle state — `unlock-go` may return `FAILED (remote: oem unlock is not allowed)`. Test before assuming. EDL byte-flip workaround is documented in `guide.md` Part 3 if needed.

## Corrections applied (vs original chat draft)

1. **arm64**, not arm. SD425 is ARMv8. MindTheGapps **10.0 arm64**, APKMirror sideloads use **arm64-v8a**.
2. Magisk installs via the canonical patched-`boot.img` path (boot LOS, app patches, `fastboot flash boot magisk_patched.img`). topjohnwu deprecated the TWRP zip-flash path in v30.7. Keep an `uninstall.zip` rename of the APK on the SD card as the TWRP-side bootloop safety net (substring detection verified in `update_binary.sh` at the v30.7 tag) and a clean LOS `boot.img` on the host as the fastboot-side recovery.
3. Use `winget install Google.PlatformTools` instead of manual zip extraction.
4. **TWRP install of the LOS zip does NOT work on this device.** Confirmed empirically (2026-04-27 session) and matches XDA reports. TWRP's `update-binary` writing /system via `block_image_update` wedges the kernel in `D` state on `wait_on_page_bit` — `updater` deadlocks on the eMMC write, never recovers, only force-reboot escapes. Fixing this means **bypassing TWRP entirely for /system**: extract the system image from the LOS zip, sparse-convert it, and `fastboot flash` it directly. Detailed recipe in the "Install path that actually works" section below.

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

- **No EDL / BLUnlocker path.** Skip QDLoader, devinfo hex edits, firehose `.mbn` — not needed. OEM unlock toggle is on. (Confirmed 2026-04-27: `fastboot oem unlock-go` succeeded immediately on this unit, `unlocked: yes` on subsequent `getvar`.)
- **Flash order (revised after empirical pain):** `fastboot erase system` → flash `system.simg` (sparse) and `boot.img` via fastboot → reboot to LOS for OOBE → re-enter recovery → install GApps via TWRP (it can do small zips fine; only the giant LOS install hangs) → reboot → install Magisk via patched-`boot.img` path. The TWRP zip-flash for the LOS ROM itself does NOT work on this hardware.
- **TWRP must be FLASHED to /recovery, not booted via `fastboot boot`.** XDA user `ahecht` (sister thread #81) confirmed this is the canonical fix for the "Unmounting System" hang. **Caveat:** for THIS device, that fix isn't enough — the install still hangs further along, in `block_image_update`'s first system write. The fix is to bypass TWRP entirely for /system, see "Install path that actually works." Flashing TWRP to /recovery is still required so it survives reboots.
- **Format Data via TWRP UI hangs at `mke2fs /system`.** Skip wiping /system through TWRP entirely — `fastboot erase system` followed by the fastboot flash gets you a clean partition without TWRP touching it. Wipe Dalvik + Cache + Data via TWRP fine; just don't include System.
- **`twrp wipe data` from CLI is a soft wipe** (preserves /data/media/0). Format-Data-equivalent isn't exposed through `twrp` CLI in 3.4 (`twrp format data` returns "Unrecognized script command"). Manual `mke2fs` of `/dev/block/mmcblk0p48` fails because the dm-0 crypto mapper holds the partition busy and no `dmsetup` ships in this TWRP. For our purposes, `unlock-go` already factory-reset /data and `twrp wipe data` is sufficient — LOS first boot proceeds normally with default-key encryption.
- **First boot is 5–10 min** and was confirmed empirically. Tablet sits on a black screen for the bulk of it; user should not interrupt.
- **LineageOS ships with Developer options + USB debugging pre-enabled.** No need to walk the user through tap-Build-number-7× post-OOBE. Just hit Allow on the RSA prompt.
- **Don't enable LineageOS's built-in root** (Settings → Developer options → Root access). It's separate from Magisk and conflicts with it. Use Magisk only.
- **/sdcard is `/data/media/0`** in TWRP (same `dm-0` mount as /data) — verify with `adb shell mount | grep sdcard`. Pushing files BEFORE Format Data wipes them. Order: wipe → push → install. If the install dies and the user force-reboots mid-write, expect any pushed zips on /sdcard to truncate to 0 bytes — re-push.
- **Root stays in.** Streaming targets (Crunchyroll, Prime) are root-tolerant; no banking use case. PIF + TrickyStore workaround for Netflix/Hulu in Appendix A if the user adds them later.
- **Widevine L3.** SD425 is L3-only. Caps are uneven: Crunchyroll plays **1080p** on L3 (outlier), Netflix **540p**, Prime / Disney+ / Max **480p–SD**.
- **PIF is a Magisk Zygisk module**, not a TWRP-flashable zip. Earlier draft had this wrong — corrected.
- **TrickyStore is optional for the in-scope streamers.** PIF alone clears Netflix; Hulu also needs Shamiko + DenyList. TrickyStore is only required for STRONG-tier integrity (banking-class apps, out of scope).

## Install path that actually works (2026-04-27 verified)

Empirically verified on this exact unit. Steps assume tablet is unlocked, in fastboot, with the Windows USB driver fix in place (Zadig WinUSB + Android device-interface GUID — see `flash-walkthrough.md` Part 3).

1. **Extract the LOS zip pieces on the host:**
   ```pwsh
   $dst = "downloads/_los-flash"
   New-Item -ItemType Directory $dst -Force | Out-Null
   & "C:\Program Files\7-Zip\7z.exe" e downloads/lineage-17.1-*.zip -o"$dst" `
     "system.new.dat.br" "system.transfer.list" "boot.img"
   ```

2. **Decompress brotli + reconstruct flat `system.img`** (Python with `pip install brotli` plus xpirt's `sdat2img.py` from GitHub):
   ```pwsh
   python scripts/.tmp-brotli-decompress.py $dst/system.new.dat.br $dst/system.new.dat
   python $dst/sdat2img.py $dst/system.transfer.list $dst/system.new.dat $dst/system.img
   ```
   Output `system.img` is ~3.8 GB (sparse holes padded with zeros up to the highest-addressed block).

3. **Sparse-convert** to drop zero regions. **Mandatory** because `fastboot.exe` on Windows is **32-bit** (ASCII machine `0x14c` in PE header) and can't allocate >~3 GB. Sparse output is ~1.5 GB:
   ```pwsh
   python scripts/.tmp-flat-to-sparse.py $dst/system.img $dst/system.simg
   ```

4. **Erase /system + flash:**
   ```pwsh
   fastboot erase system
   fastboot flash system $dst/system.simg
   fastboot flash boot $dst/boot.img
   fastboot reboot
   ```

   `fastboot flash system` chunks automatically — expect 3 sub-uploads, ~108s total. Save off `$dst/boot.img` to `boot-stock-los.img` for the Magisk patch step in Part 6.

5. **First boot ~5-10 min**, then OOBE, then re-enable dev options + USB debugging.

GApps is small enough that TWRP's `twrp install /sdcard/MindTheGapps-*.zip` should work after LOS is up — but if it also hangs, the fallback is to extract GApps's `system/` tree on the host and `adb push` the contents into a rooted LOS shell. (Update this section if the GApps step needs the same fastboot-flash workaround.)

## Windows host gotchas (2026-04-27 verified)

- **fastboot.exe shipped by `Google.PlatformTools` is 32-bit** (`0x14c` PE machine). Caps RAM at ~3 GB. Flat images >3 GB throw `std::bad_alloc`. Sparse format mandatory for the LOS system image.
- **No working USB driver out of the box for the AOSP fastboot interface (`VID_18D1&PID_D00D`).** Google USB Driver r13 doesn't list it (predates AOSP standardization on D00D). `ClockworkMod.UniversalADBDriver` covers ADB only, not fastboot. Working recipe: install `akeo.ie.Zadig`, bind WinUSB to the `Android` entry, then add `{F72FE0D4-CBCB-407D-8814-9ED673D0DD6B}` to `HKLM\SYSTEM\CurrentControlSet\Enum\USB\VID_18D1&PID_D00D\<SERIAL>\Device Parameters\DeviceInterfaceGUIDs` (REG_MULTI_SZ, append, don't replace) and `pnputil /restart-device`. Detail in `flash-walkthrough.md` Part 3.
- **Cold-boot fastboot combo is Power + Volume UP**, NOT Vol Down. Vol Down doesn't enter fastboot on this hardware.
- **`adb reboot bootloader` post-unlock** goes straight to fastboot. Pre-unlock it lands on a chooser menu (Start / Power off / Recovery mode / Restart bootloader / Boot to ffbm) — Volume Down to navigate, Power to select.
- **`pwsh -NoProfile -Command "..."` through bash mangles `$variables` and `&` and `C:\paths`.** Prefer the `PowerShell` tool directly when it's registered for the session. Otherwise put scripts in `.ps1` files and invoke via `pwsh -File`. The `&` in registry paths like `USB\VID_18D1&PID_D00D\...` is an especially nasty trap — bash treats `&` as a command separator and gsudo passes the truncated path through.
- **USB cable quality matters more than you'd expect.** A cable that charges fine and passes `adb shell echo ok` can still fail mid-`adb pull` for the patched boot.img (~11 MB). Symptom: `device offline` errors after a few seconds of transfer. Repro: `md5sum` of the on-device file works (full read), but `adb pull` of the same file dies. Fix: try a different cable. Don't waste cycles diagnosing the host driver / port / adbd before swapping cables.

## Magisk policy gotchas

- **Default `adb shell su` is silently denied even after the patched boot is flashed.** First-time `adb shell su -c id` returns `Permission denied` with no on-screen prompt — Magisk's notification "Shell was denied superuser" is the only signal. The grant prompt's 10-second timeout window passes before the user notices.
- **Two-step fix in Magisk app:** Settings → Superuser → set **Superuser access** = "Apps and ADB" (not "Apps only"), set **Automatic response** = "Prompt" (or "Grant" if you trust the local dev environment). Then go to the **Superuser** tab — there will be a "Shell" entry from the prior denial; toggle it to allow. Re-run `adb shell su -c id` to confirm `uid=0(root)`.
- **The `magisk` binary lives at `/sbin/su -> /sbin/magisk` on this build.** It's NOT in `/system/bin/`. If `adb shell su` returns `not found`, root isn't installed; if it returns `Permission denied`, root IS installed but policy blocks it (above).

## Background-task hygiene during flashing

- **A zombie `fastboot flash` from a killed background task can fire later** when the tablet re-enters fastboot for an unrelated reason. Symptom: a flash you don't remember issuing succeeds against whatever file path was in the original command, possibly with a now-different (and bad) file at that path. Mitigation: always `Get-Process fastboot,adb | Stop-Process -Force` before reusing the file path or starting a new flash sequence. Don't trust that "task failed exit 1" means the underlying child process died.
- **Sequential `fastboot flash X.img` immediately followed by `fastboot reboot` in the same script can swallow the flash output** — only the reboot logs "OKAY" and you assume the flash worked. It didn't. Run flash and reboot in separate tool calls so you can verify the flash output ("Sending 'X' (NN KB) ... Writing 'X' OKAY") before issuing the reboot.

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

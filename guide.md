# LineageOS 17.1 Flash Guide — Lenovo TB-X304F

**Device:** Lenovo Tab 4 10 (TB-X304F WiFi) · Snapdragon 425 · ARMv8 / 64-bit · 2GB / 16GB
**Target:** LineageOS 17.1 (Android 10) by deadman96385 + MindTheGapps 10.0 arm64 + Magisk
**Host PC:** Windows 10
**Bootloader:** OEM unlock enabled — no EDL workaround needed.

---

## Part 1 — Downloads

Run `npm run restore` from this repo to fetch the items marked **[auto]** into `downloads/`. The XDA-hosted items are **[manual]** — download them from the XDA thread and drop them in `downloads/` alongside the rest.

| File | Source | Mode |
|---|---|---|
| Platform-tools (adb / fastboot) | `winget install Google.PlatformTools` | [auto] |
| LineageOS 17.1 zip for TB-X304F | XDA thread (mailru or gdrive mirror) | [manual] |
| TWRP `tbx304-twrp-3.4.0-20201207.img` | XDA thread (Highwaystar build) | [manual] |
| MindTheGapps 10.0 **arm64** zip | github.com/MindTheGapps/10.0.0-arm64/releases | [auto] |
| Magisk latest `.apk` | github.com/topjohnwu/Magisk/releases | [auto] |
| PlayIntegrityFork (Appendix A only) | github.com/osm0sis/PlayIntegrityFork | [auto] |
| TrickyStore (Appendix A only) | github.com/5ec1cff/TrickyStore | [auto] |

**XDA thread:** `https://xdaforums.com/t/rom-unofficial-10-0-tb-x304f-tb-8504f-lineageos-17-1-for-lenovo-tab4-8-10-wifi.4466879/`

### Magisk: rename + create `uninstall.zip`

After download (handled by `restore.ps1`):
1. `Magisk-vXX.X.apk` → copied to `Magisk-vXX.X.zip`
2. The same APK → copied to `uninstall.zip`

Both end up on the tablet's microSD before flashing. The `uninstall.zip`, flashed via TWRP, cleanly removes Magisk if the boot partition gets stuck after root.

---

## Part 2 — Tablet prep (already complete on your end)

If repeating from scratch:

1. Settings → System → About tablet → tap **Build number** 7 times → Developer options unlocked.
2. Developer options → enable **OEM unlocking** and **USB debugging**.
3. Install platform-tools on the PC: `winget install Google.PlatformTools` (then restart the terminal so `adb` / `fastboot` resolve).

Verify from the host:

```
adb devices
```

Should list one device. Tap **Allow** on the tablet for the RSA prompt; re-run if the first attempt shows "unauthorized".

---

## Part 3 — Bootloader unlock

1. Reboot to bootloader:
   ```
   adb reboot bootloader
   ```
2. Confirm the tablet shows the **Fastboot** screen.
3. Verify host sees it:
   ```
   fastboot devices
   ```
4. Unlock:
   ```
   fastboot oem unlock-go
   ```
5. The tablet shows a confirmation prompt. **Volume Up** to highlight unlock, **Power** to confirm.
6. Device reboots and **factory resets**. Re-do dev options + USB debugging from Part 2 after first boot.
7. Reboot back to fastboot when ready for Part 4 (`adb reboot bootloader`).

If `unlock-go` is rejected with "not allowed" or "permission denied", re-check the OEM unlocking toggle — it must be on before the unlock command.

---

## Part 4 — Flash TWRP (do not boot it)

Booting a temporary recovery is unreliable on TB-X304F. Flash to the recovery partition instead.

1. From fastboot:
   ```
   fastboot flash recovery tbx304-twrp-3.4.0-20201207.img
   ```
2. **Critical:** do NOT let stock Android boot — it overwrites recovery. Hold **Volume Up** while issuing:
   ```
   fastboot reboot
   ```
   Keep Volume Up held until TWRP appears.

If you missed the timing and stock booted, repeat the flash from fastboot (`adb reboot bootloader` if you can get USB back, otherwise hold **Power + VolDown** from off to re-enter fastboot).

3. Inside TWRP: choose **Keep Read Only** when prompted, skip the password prompt (no encryption used yet).

---

## Part 5 — Flash LineageOS + GApps + Magisk

### Push files to the tablet

From host PC, with the tablet in TWRP:

```
adb push lineage-17.1-*-x304.zip          /sdcard/
adb push MindTheGapps-10.0.0-arm64-*.zip  /sdcard/
adb push Magisk-vXX.X.zip                 /sdcard/
adb push uninstall.zip                    /sdcard/
```

(Or pre-load the microSD on the host and insert it.)

### Wipe → Format Data

In TWRP:

1. **Wipe → Advanced Wipe** → check Dalvik / Cache / System / Data → swipe.
2. **Wipe → Format Data** → type `yes`. **Mandatory.** Stock 8.1 encryption is incompatible with LOS 17.1.
3. Back to main menu.

### Flash in order, no reboots between

1. **Install** → select `lineage-17.1-*.zip` → swipe.
2. After it completes: **Install** → `MindTheGapps-10.0.0-arm64-*.zip` → swipe.
3. After it completes: **Install** → `Magisk-vXX.X.zip` → swipe.
4. **Wipe → Advanced Wipe** → Dalvik + Cache → swipe (just these two).
5. **Reboot → System**.

If the device hangs at the boot logo for **more than ~10 minutes**, see Troubleshooting.

---

## Part 6 — First boot & root verification

- First boot is **5–10 minutes**. Don't interrupt.
- Walk through setup; skip Google sign-in if you want a clean check first.
- Open the **Magisk** app (auto-installed). It will prompt to "complete the install" and reboot once. Allow it.
- After the second reboot, Magisk → Superuser tab is empty until apps request root. Confirm version is current and "Installed" matches "App version" with no delta.

### Test root

- Install **Termux** (F-Droid is fine, or sideload).
- `su` should pop a Magisk grant prompt. Approve. Prompt then shows a `#` shell.

### Confirm GApps

- Sign into Play Store. Install **Crunchyroll** → it should run normally.
- (Optional) Install **Prime Video** → also fine; root-tolerant.
- (Optional) **Netflix / Hulu** → see Appendix A; expect failure without PIF.

---

## Troubleshooting

- **Stuck at LineageOS boot logo > 10 min.** Boot back into TWRP (Power + VolUp at boot) → Wipe → Advanced Wipe → Dalvik + Cache → swipe → reboot system.
- **Bootloop after Magisk.** Boot into TWRP → flash `uninstall.zip` → reboot. Device returns to LOS without root.
- **`fastboot oem unlock-go` rejected.** OEM unlocking toggle is off. Boot back to system, re-enable in Developer options, retry.
- **TWRP overwritten on first boot.** Stock Android booted before you got into recovery. Re-flash TWRP from fastboot, then immediately Volume Up + Power on reboot.
- **`adb devices` empty.** Drivers / cable. Check Device Manager for unrecognized devices, accept the RSA prompt on the tablet, try a different USB-A port.
- **Crunchyroll / Prime won't play HD.** Expected. Snapdragon 425 is **Widevine L3** — SD/720p ceiling regardless of ROM/root.

---

## Quick command reference

```
# Discovery
adb devices
fastboot devices

# Reboot paths
adb reboot bootloader
fastboot reboot                                       # to system
fastboot reboot recovery

# Flashing
fastboot oem unlock-go
fastboot flash recovery tbx304-twrp-3.4.0-20201207.img
adb push <file> /sdcard/
```

### Hardware button combos (TB-X304F)

- **Recovery:** Power + Volume Up (held from off / during reboot)
- **Bootloader:** Power + Volume Down (held from off)
- **Force off:** hold Power for ~10 s

---

## Appendix A — Streaming app compatibility

| App | Stock LOS+root | With PIF + TrickyStore | Widevine | Notes |
|---|---|---|---|---|
| Crunchyroll | ✅ Works | — | L3 | SD/720p ceiling |
| Prime Video | ✅ Works | — | L3 | Same |
| Netflix | ❌ Fails (Play Integrity) | ✅ Works (usually) | L3 | Play Store hides app on rooted L3; sideload + PIF |
| Hulu | ❌ Fails | ✅ Works | L3 | Same |
| Disney+ | ❌ Fails | ⚠️ Hit-or-miss | L3 | Tightening attestation |

### Adding Netflix / Hulu later (PIF + TrickyStore setup)

1. Run `npm run restore` to fetch **PlayIntegrityFork** + **TrickyStore** zips into `downloads/`.
2. Push both to the tablet's microSD.
3. Boot TWRP → Install → flash both. Reboot.
4. Open Magisk → Modules → both should be enabled.
5. Sideload Netflix / Hulu APK from APKMirror — pick the **arm64-v8a** variant (NOT arm).
6. Open the app cold (clear Play Store cache first if previously installed via Play). Should pass attestation; failures usually mean PIF fingerprints need refreshing from the upstream repo.

The TB-X304F is **arm64-v8a** (Cortex-A53 / ARMv8). Always pick the arm64 variant on APKMirror, never `armeabi-v7a`.

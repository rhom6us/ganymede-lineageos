# Magisk install procedure — v30.7 on LOS 17.1

**Captured:** 2026-04-26.

## TL;DR

- TWRP zip-flash is **officially deprecated** in v30.7 but still works on TB-X304F (boot ramdisk present).
- Canonical 2026 path: install Magisk APK on a booted LOS, patch the LOS `boot.img` from the app, `fastboot flash boot magisk_patched.img`.
- The `uninstall.zip` rename trick still works — substring match in `scripts/update_binary.sh`.

## TWRP zip-flash status

`docs/install.md` § Custom Recovery (master, unchanged through v30.7) carries:

> "**This installation method is deprecated and is maintained with minimum effort. YOU HAVE BEEN WARNED!**"

Source: https://github.com/topjohnwu/Magisk/blob/master/docs/install.md#custom-recovery

The installer scripts are intact at the v30.7 tag (`scripts/update_binary.sh`, `scripts/flash_script.sh`, `assets/util_functions.sh`). v30.7 release notes (https://github.com/topjohnwu/Magisk/releases/tag/v30.7, 2026-02-23) make no mention of removing TWRP support — changes are scoped to MagiskInit (Android 16 QPR2), Zygisk, and MagiskSU/MagiskBoot. So zip-flash works on TB-X304F today; topjohnwu just won't help if it breaks.

## Canonical install path (recommended for v30.7)

For a TB-X304F (A-only, TWRP available, LOS 17.1):

1. Flash LOS + GApps in TWRP. **Reboot to LOS.**
2. Install `Magisk-v30.7.apk` (sideload — `adb install` or push + tap to install).
3. Extract `boot.img` from the LOS zip on the host PC. Push it: `adb push boot.img /sdcard/Download/`.
4. Open Magisk → **Install** → **Select and Patch a File** → pick `boot.img`. App emits `magisk_patched-[hash].img` to `/sdcard/Download/`.
5. `adb pull /sdcard/Download/magisk_patched-*.img` → host.
6. `adb reboot bootloader` → `fastboot flash boot magisk_patched-*.img` → `fastboot reboot`.
7. Magisk app on next boot will prompt to "complete the install" — accept, reboot once more.

Trade-off vs current TWRP-zip plan: one extra reboot + APK install step, but uses a non-deprecated code path that topjohnwu actively maintains.

## `uninstall.zip` detection mechanism (verified at v30.7 tag)

`scripts/update_binary.sh` lines 21-25 (https://github.com/topjohnwu/Magisk/blob/v30.7/scripts/update_binary.sh):

```sh
if echo "$3" | $BBBIN grep -q "uninstall"; then
  exec $BBBIN sh "$INSTALLER/assets/uninstaller.sh" "$@"
else
  exec $BBBIN sh "$INSTALLER/META-INF/com/google/android/updater-script" "$@"
fi
```

`$3` is the zip path. Detection is **case-sensitive substring `uninstall`** anywhere in the path. So `uninstall.zip`, `magisk-uninstall.zip`, `Magisk-v30.7-uninstall.zip` all route to the uninstaller. `Uninstall.zip` (capital U) does **not** match.

Docs confirm:

> "If you insist on using custom recoveries, rename the Magisk APK to `uninstall.zip` and flash it like any other ordinary flashable zip."
> — `docs/install.md` § Uninstallation

The uninstaller restores stock boot via the backup at `/data/magisk_backup_[sha1]` left during install.

## Bootloop recovery — two supported paths

**TWRP path (matches current plan's safety net):** boot to TWRP, flash `uninstall.zip` (substring match per above). Magisk's uninstaller restores the pre-Magisk boot partition. Always works on a TWRP-equipped device.

**Fastboot path (canonical):** keep an unpatched copy of the LOS `boot.img` on the host PC. `fastboot flash boot boot.img` returns to LOS-without-Magisk. Skips the TWRP boot step.

For a TB-X304F (A-only with TWRP available), the rename-to-`uninstall.zip` trick is the most ergonomic recovery and is genuinely supported in v30.7.

## Recommendation for this project

**Switch primary install to canonical patched-boot path.** It's only one extra reboot vs the current TWRP-zip plan and avoids the deprecation warning. Keep `uninstall.zip` on the SD card as the bootloop safety net regardless — that path is still maintained.

The existing plan (TWRP zip-flash Magisk inside Part 5) will continue to work in v30.7 but is on borrowed time the moment topjohnwu decides to pull the installer scripts.

## Citations

- Install docs: https://github.com/topjohnwu/Magisk/blob/master/docs/install.md
- v30.7 release: https://github.com/topjohnwu/Magisk/releases/tag/v30.7
- Detection source: https://github.com/topjohnwu/Magisk/blob/v30.7/scripts/update_binary.sh
- Installer entry: https://github.com/topjohnwu/Magisk/blob/v30.7/scripts/flash_script.sh
- Uninstaller source: https://github.com/topjohnwu/Magisk/blob/v30.7/scripts/uninstaller.sh

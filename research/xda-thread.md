# XDA thread research — TB-X304F LineageOS 17.1

**Source:** https://xdaforums.com/t/rom-unofficial-10-0-tb-x304f-tb-8504f-lineageos-17-1-for-lenovo-tab4-8-10-wifi.4466879/
**OP author:** deadman96385
**Captured:** 2026-04-26

## ROM zip (LineageOS 17.1)

- **Filename:** `lineage-17.1-20220710-UNOFFICIAL-TBX304F.zip`
- **Build date:** 2022-07-10. **No newer build exists in the thread** — this remains the latest.
- **Direct mirror (Wasabi S3 — only mirror in OP):**
  https://s3.us-west-1.wasabisys.com/rom-release/LineageOS/17.1/TB-X304F/lineage-17.1-20220710-UNOFFICIAL-TBX304F.zip
- The handoff's note about "mailru or gdrive mirror" for the **ROM** is wrong — those mirrors are for TWRP, not the ROM. ROM has only the Wasabi mirror.
- Filesize / hashes not stated in OP.
- **OP-listed differences vs Highwaystar's earlier release:** "Telephony components removed (much better battery life and performance, previously they would constantly crash in the background)." LTE variants would behave as WiFi-only after flashing.

## TWRP recovery image

- **File:** `tbx304-twrp-3.4.0-20201207.img` (Highwaystar's build)
- **Mirrors (in OP):**
  - mailru: `https://cloud.mail.ru/public/AU29/uv1CLEfEs`
  - gdrive: `https://drive.google.com/file/d/1c-pWmg6LyygebFRFPI9tnOGg8T-6xuD0/view?usp=sharing`
- OP describes: "Highwaystar's twrp omnirom android 9.0 source, includes same kernel as Lineage build, with support for pstore (kernel logs after crash), exfat, ntfs, reboot to EDL mode."
- OP teases "(NEW TWRP VERSIONS COMING SOON WITH FIXES/UPDATES)" but no newer image has appeared.
- Filesize not stated.

## Format Data requirement

OP, verbatim:
> "If you have android 8 stock rom installed you have to format Data with data loss, because the newer encryption is incompatible with android 7.1."

The "android 7.1" reference is a typo — context is LOS 17.1 (Android 10). Format Data is **mandatory** when coming from stock 8.1.

## Install procedure

**OP does not contain a step-by-step install section.** No fastboot commands, no flashing order, no "do not boot TWRP, flash it" wording in the OP itself. The closest community guide is from user `qu4droro` (post #18, 2023-09-23):

1. Unlock bootloader (links external guide)
2. Enable Developer Mode + USB Debugging
3. Install ADB on PC
4. Flash TWRP via ADB (fastboot, presumably)
5. Wipe all data via TWRP (except SD card)
6. Flash ROM zip via TWRP
7. Optional: MindTheGapps
8. Optional: Magisk

## Magisk uninstall.zip safety net

Not from OP. Recommended by `qu4droro` (post #18):
> "never forget to convert magisk.apk to magisk.zip and make a one copy of magisk.zip and rename it uninstall.zip. it will help you if your tablet gonna bootloop to save."

## Known issues / what works

OP's "What works": WiFi, Bluetooth, GPS, Camera, Audio, FM radio, WLAN and USB tethering.
OP's "Broken": "You tell me" (no specifics).

User-reported:
- **koop1955:** SafetyNet passes when using **MagiskHide Props Config** module.
- **brickme:** MindTheGapps was "a little buggy"; sideloaded Play Store as a workaround. Disabling haptic feedback improved UI responsiveness.
- **tek3195:** Trouble booting to recovery from the power menu (not reproduced by koop1955).
- **johneri (post #10, 2023-04-03):** "if the ROM doesn't load and gets stuck on boot: Go back to recovery after installing ZIP and format data" — Format-Data-after-flash resolves boot-stuck cases.

## Bootloader unlock command

**Not specified in the OP.** Neither `fastboot oem unlock-go` nor `fastboot flashing unlock` is quoted. Replies reference an external unlock guide (joshat10xda, post #11). Confirm via the hardware research note (`research/hardware.md`).

## What could not be confirmed from this thread

- ROM zip filesize / SHA / MD5
- TWRP image filesize / SHA / MD5
- Any "do not boot TWRP, flash it" phrasing (not present in OP — that wisdom likely came from the TWRP author's own thread)
- Specific first-boot wait time (handoff's "5–10 minutes" is reasonable but not OP-sourced)
- Exact bootloader unlock command — see hardware research

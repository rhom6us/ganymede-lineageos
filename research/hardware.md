# Hardware + flashing procedure — TB-X304F

**Captured:** 2026-04-26.

## SoC / architecture (confirmed)

- **SoC:** Snapdragon 425 (MSM8917).
- **CPU:** 4× Cortex-A53 @ 1.4 GHz.
- **Architecture:** ARMv8-A 64-bit (AArch64). Cortex-A53 implements ARMv8-A; the prior 32-bit ARMv7 line was Cortex-A7/A9.
- Confirmed by LineageOS device-tree common board config (`android_device_lenovo_tb-common/BoardConfigCommon.mk`):
  ```
  TARGET_ARCH := arm64
  TARGET_ARCH_VARIANT := armv8-a
  TARGET_2ND_ARCH := arm
  TARGET_2ND_CPU_ABI := armeabi-v7a
  TARGET_2ND_CPU_VARIANT := cortex-a53
  ```
- Sources: [Notebookcheck SD425](https://www.notebookcheck.net/Qualcomm-Snapdragon-425-SoC.207568.0.html), [lenovo-devs/android_device_lenovo_TBX304](https://github.com/lenovo-devs/android_device_lenovo_TBX304).

## APK ABI

Pick **`arm64-v8a`** when offered. `armeabi-v7a` works (32-bit compat libs are loaded as `TARGET_2ND_CPU_ABI`) but uses more RAM and runs slower. Universal/fat APKs are fine but waste storage. `x86`/`x86_64` will not install.

## Widevine level

**L3 (software-only)** — confirmed. SD425 has no TrustZone-backed Widevine L1 keybox; entry-tier SD4xx Lenovo tablets of this era are uniformly L3.

Practical caps (2026):
- Netflix: 540p.
- Prime, Disney+, Hulu, Max: 480p–540p.
- Crunchyroll: **1080p** (Widevine policy is permissive — outlier).
- YouTube, Plex, Jellyfin, Twitch, Kodi local: unaffected (don't gate on Widevine).

Sources: [Vudu Lenovo L3 thread](https://forum.fandango.com/forum/technical-help/vudu-support-faq/556009-various-motorola-lenovo-mobile-devices-mistakenly-categorized-as-widevine-l3), [XDA Lenovo P10 L3 discussion](https://xdaforums.com/t/lenovo-p10-tab-with-netflix-widevine-l3.4083899/).

## Hardware button combos

| Action | Combo |
|---|---|
| Stock recovery | Power off → hold **Volume Up + Power**, release at Lenovo logo. Use Volume keys to highlight, Power to confirm. |
| Fastboot / bootloader | Power off → hold **Volume Down + Power** until fastboot screen. (Or `adb reboot bootloader` from booted Android.) |
| Force shutdown | Hold **Power + Volume Down** for ~10–15 s. |

No official LineageOS device wiki exists for TB-X304F (LOS 17.1 builds are unofficial XDA ports). Canonical refs are HardReset.info / AndroidBiits.

## Bootloader unlock

- **Correct command:** `fastboot oem unlock-go` (not `flashing unlock`).
- **No Lenovo unlock account, no online token, no Mi-style 7-day wait.**
- **CATCH:** OEM-unlocking is **greyed out from factory on most TB-X304F units**. The dev-options toggle may appear enabled but the underlying `devinfo` flag remains `00`. On a stock unit `fastboot oem unlock-go` returns:
  ```
  FAILED (remote: oem unlock is not allowed)
  ```
- **EDL workaround when greyed out:** boot to EDL (hold **Vol Up + Vol Down** while connecting USB) → device enumerates as "Qualcomm HS-USB QDLoader 9008" → use QFIL or `edl.py` with the OEM `prog_emmc_firehose_8917_ddr.mbn` firehose loader → dump the `devinfo` partition → flip the unlock-allowed byte (`00` → `01`) with a hex editor → flash it back → `fastboot oem unlock-go` then succeeds.
- **On-device confirmation flow:** after `unlock-go` succeeds the tablet typically reboots straight into a wipe/unlock flow without prompting. Some units do show a Yes/No dialog: **Volume Up = navigate, Power = select**. First boot wipes userdata.

Sources: [XDA TB-X304F unlock guide](https://xdaforums.com/t/guide-unlock-bootloader-of-lenovo-tab-4-10-with-oem-unlock-greyed-out-tb-x304f-l-and-other-qcom-tablets.4201857/), [AndroidBiits unlock guide](https://androidbiits.com/unlock-bootloader-lenovo-tab4-tb-x304f-tb-x304l-easily/).

## TWRP flashing — gotchas

The handoff said "don't boot TWRP, flash it — booting is unreliable on X304F." **Research disagrees:** `fastboot boot twrp.img` is the *preferred* community approach. The real concern is the **stock-recovery overwrite**: stock Android contains `install-recovery.sh` that re-writes `/recovery` on first boot, clobbering TWRP if Android ever boots between TWRP-flash and LOS-flash.

Two workable patterns:

**Preferred — boot temporarily, then flash from inside TWRP:**
```
fastboot boot tbx304-twrp-3.4.0-20201207.img
# inside TWRP: Wipe → format Data, then Install → LineageOS zip
# then GApps, then Magisk — no stock-Android boot in between
```

**Alternative — flash + immediately reboot to TWRP (no Android boot between):**
```
fastboot flash recovery tbx304-twrp-3.4.0-20201207.img
fastboot reboot
# the moment the screen blanks, hold Volume Up + Power until Lenovo logo
# release; you'll land in TWRP. DO NOT let it boot to Android first.
```

Once LineageOS is flashed it disables the stock `install-recovery` script, after which TWRP persists across reboots normally.

**Brick recovery:** SD425 has unkillable Qualcomm EDL (9008) mode. Worst-case: hold Vol Up + Vol Down while connecting USB → QFIL or `edl.py` with the OEM firehose `.mbn` and a stock TB-X304F factory image. Soft-bricks (boot loop, "no command", encryption-failed) are TWRP-recoverable: full data wipe + re-flash LOS.

Sources: [XDA TWRP+root master thread Tab 4 series](https://xdaforums.com/t/twrp-and-root-for-tab-4-8-10-plus-tb-8704x-f-v-tb-x704l-f-tb-8504x-f-tb-x304l-f.3664407/), [XDA "avoid stock recovery overwrite" guide](https://xdaforums.com/t/closed-guide-avoid-overwriting-twrp-by-your-stock-oem-recovery-all-devices-r-11.4344257/).

## Partition layout — A-only

- **Confirmed A-only** (legacy / non-A/B), with a dedicated `recovery` partition.
- Evidence from LOS device tree:
  - `BOARD_RECOVERYIMAGE_PARTITION_SIZE := 67108864` — explicit 64 MiB recovery.
  - **No** `AB_OTA_PARTITIONS`, **no** `AB_OTA_UPDATER := true`, **no** `BOARD_USES_RECOVERY_AS_BOOT`.
  - **No** `PRODUCT_USE_DYNAMIC_PARTITIONS` — pre-Android-10 static layout.
- Therefore: `fastboot flash recovery <img>` is correct. **Not** `fastboot flash boot ...` (that's the A/B-style command). Slot suffixes (`recovery_a` / `_b`) do not apply.
- You can flash to slot-less `recovery` or boot transiently with `fastboot boot`.

Source: [BoardConfig.mk lineage-16.0 branch](https://github.com/lenovo-devs/android_device_lenovo_TBX304/blob/lineage-16.0/BoardConfig.mk).

## Disagreements with the handoff

| Handoff claim | Research finding |
|---|---|
| "EDL workaround NOT needed" | TB-X304F typically needs the EDL `devinfo` byte-flip; the user may have done this already, but verify by attempting `unlock-go` and watching for `FAILED (remote: oem unlock is not allowed)`. |
| "Don't boot TWRP, flash it — boot is unreliable" | Wrong. `fastboot boot twrp.img` is the preferred path. The risk is stock-recovery overwrite, not boot reliability. |
| Architecture: ARMv8 64-bit | Confirmed. Handoff's correction (vs the original draft's "ARM not ARM64") was right. |
| Widevine L3 | Confirmed. |
| `fastboot oem unlock-go` is the unlock command | Confirmed. |
| A-only partitioning (implicit, since `flash recovery` is used) | Confirmed. |

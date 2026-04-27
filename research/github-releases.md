# GitHub releases — flashing companions

**Captured:** 2026-04-26 via the GitHub API.

## Summary

| # | Component | Latest tag | Released | Asset | Size |
|---|---|---|---|---|---|
| 1 | MindTheGapps 10.0.0-arm64 | `MindTheGapps-10.0.0-arm64-20230922_081111` | 2023-09-22 | `MindTheGapps-10.0.0-arm64-20230922_081111.zip` | 127.08 MB |
| 2 | Magisk (topjohnwu) | `v30.7` | 2026-02-23 | `Magisk-v30.7.apk` | 11.08 MB |
| 3 | PlayIntegrityFork (osm0sis) | `v16` | 2026-01-09 | `PlayIntegrityFork-v16.zip` | 0.27 MB |
| 4 | TrickyStore (5ec1cff) | `1.4.1` | 2025-11-02 | `Tricky-Store-v1.4.1-245-72b2e84-release.zip` | 2.71 MB |

## 1. MindTheGapps 10.0.0-arm64

- **Direct URL:** https://github.com/MindTheGapps/10.0.0-arm64/releases/download/MindTheGapps-10.0.0-arm64-20230922_081111/MindTheGapps-10.0.0-arm64-20230922_081111.zip
- This is the final Android-10 GApps release upstream — no newer 10.0.0-arm64 build exists or is expected.
- Correct pick for the TB-X304F (SD425 is ARMv8 / 64-bit; LOS 17.1 builds are 64-bit).
- **Install:** Flash in TWRP immediately after the LineageOS zip, before first boot. Clean install only.

## 2. Magisk

- **Direct URL:** https://github.com/topjohnwu/Magisk/releases/download/v30.7/Magisk-v30.7.apk
- **Debug APK** (ignore): `app-debug.apk` (24.10 MB).
- **TWRP-flashable procedure:**
  1. Download `Magisk-v30.7.apk`.
  2. Make a copy renamed `Magisk-v30.7.zip`.
  3. Make another copy renamed `uninstall.zip`. Magisk's installer reads install mode from filename — `uninstall.zip` triggers the uninstaller path when flashed in TWRP.
  4. Push both to the device. Flash `Magisk-v30.7.zip` from TWRP after LOS+GApps. Keep `uninstall.zip` as the safety net.
- **Forks (Magisk Delta / Kitsune Mask):** canonical upstream repos `HuskyDG/magisk-files` and `1q23lyc45/KitsuneMagisk` both 404 on GitHub at capture time. Active mirrors exist but are device-specific. **For a clean LOS 17.1 install in 2026, mainline `topjohnwu/Magisk v30.7` is the right default** — Zygisk + DenyList + PIF + (optional) TrickyStore covers everything Delta/Kitsune historically offered.

## 3. PlayIntegrityFork

- **Direct URL:** https://github.com/osm0sis/PlayIntegrityFork/releases/download/v16/PlayIntegrityFork-v16.zip
- **Install type:** Zygisk module — flash from the Magisk app (Modules → Install from storage), **not** from TWRP. Requires Zygisk enabled in Magisk settings. Reboot after install.
- **TrickyStore relationship:** TrickyStore is **optional**, not required. README quote: needed only "for spoofing locked bootloader and attempting to pass <A13 PI STRONG integrity, or A13+ PI DEVICE or STRONG integrity." For Android 10 (TB-X304F target) BASIC integrity is the realistic ceiling, and PIF v16 alone usually achieves it.
- **Install order if both are used:** TrickyStore first, reboot, then PlayIntegrityFork. PIF's `autopif4` post-install script detects TrickyStore's directory and self-configures.
- **Fingerprint refresh:** bundled. Run `autopif4.sh` from a root shell to generate a fresh Pixel Canary fingerprint. Random fingerprints expire roughly every 6 weeks per the README. No automatic remote pif.json fetch in v16 — fingerprints are self-generated locally from public Pixel build metadata. Manual `pif.json` swaps still work (`/data/adb/modules/playintegrityfix/pif.json`) but aren't the recommended workflow.

## 4. TrickyStore

- **Direct URL:** https://github.com/5ec1cff/TrickyStore/releases/download/1.4.1/Tricky-Store-v1.4.1-245-72b2e84-release.zip
- **What it does:** hijacks Android Keystore `getCertificateChain` to forge or substitute the leaf certificate produced by hardware key attestation. Lets a rooted/unlocked device present an attestation chain that looks bootloader-locked, defeating Play Integrity's hardware-backed DEVICE/STRONG verdicts that PIF alone cannot bypass.
- **Layering with PIF:** PIF spoofs the *software-side* fingerprint and props that Play Integrity reads; TrickyStore spoofs the *hardware-side* attestation chain. They cover different layers of the same check. On Android 10 (BASIC verdict only) TrickyStore is unnecessary for normal Play Integrity passes — PIF alone is enough.
- **Install:** Magisk/KernelSU/APatch module. Flash from the manager app, reboot. Requires Android 10+ (TB-X304F qualifies).
- **Note:** TrickyStore went **closed-source from v1.1.0 onward** due to abuse concerns. Releases are signed and SHA256-published.

## Practical guidance for TB-X304F (Android 10, BASIC integrity ceiling)

- **GApps + Magisk v30.7 + PIF v16** is sufficient for the use cases in scope (Crunchyroll, Prime, Netflix, Hulu).
- **TrickyStore is optional padding**, not required. Add only if a specific app fails Play Integrity with PIF alone.
- **PIF is a Magisk module** — flash from Magisk app, not TWRP. (The handoff/draft guide had this wrong.)

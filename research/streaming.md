# Streaming app compatibility — rooted Android 10 on TB-X304F

**Captured:** 2026-04-26.

**Device-specific note:** TB-X304F shipped with Android 7 and is on the legacy RSA-2048 attestation root, NOT RKP. Google's May 2025 hardware-attestation tightening only affects devices originally shipped with Android 13+. The Feb/Apr 2026 RKP cutover that affects newer devices does NOT apply here. **The keybox/PIF approach remains durable on this device.**

## Compatibility table

| App | Rooted, no PIF | Rooted, PIF (+ Shamiko if noted) | L3 cap | Notes |
|---|---|---|---|---|
| Crunchyroll | ✅ Works | ✅ Works | **1080p** | No real root detection; permissive Widevine policy; outlier — every other major streamer is L1-gated for HD. |
| Prime Video | ✅ Mostly works | ✅ Works | 480p–SD | Historically root-tolerant; Amazon added some attestation in 2025 but no hard block. PIF clears occasional "device not supported" spots. |
| Netflix | ❌ Hidden in Play Store | ✅ Works (sideload + PIF) | 540p | TrickyStore not needed; BASIC + DEVICE is enough. Sideload APK; PIF passes; capped at 540p on L3. |
| Hulu | ⚠️ Starts, won't play | ✅ Works (PIF + Shamiko + DenyList) | 720p | 2025–2026 failure mode: app launches but buffers indefinitely on press-play. Fix is Zygisk DenyList + Shamiko whitelist + PIF. |
| Disney+ | ❌ Blue-screen on launch | ⚠️ Mostly yes (fragile) | 480p–SD | Tightest of the lot. Needs PIF + TrickyStore + Shamiko + DenyList for GMS-adjacent processes (NEVER DenyList GMS itself — breaks PIF). Some users still see intermittent failures. |
| HBO Max / Max | ✅ Mostly works | ✅ Works | 480p–SD | Warner reverted "Max" → "HBO Max" on 2025-07-09; cosmetic auto-update, no detection-stack change. |

## Per-app notes

**Crunchyroll.** No meaningful root detection in early 2026; app launches and plays without PIF. Widevine policy is unusually permissive — 1080p works on L3 devices, unlike every other major streamer. No 2025–2026 breakages reported. ([Crunchy-DL Widevine FAQ](https://github.com/Crunchy-DL/Crunchy-Downloader/discussions/36), [Crunchyroll quality help](https://help.crunchyroll.com/hc/en-us/articles/36816426440980))

**Prime Video.** Most root-tolerant major streamer historically and that remains true in 2026. Amazon added some attestation checks during 2025 that occasionally produce "device not supported" on stricter setups. PIF passing BASIC integrity clears those spots. SD ceiling on Widevine L3. ([Widevine L1 Pixel community](https://support.google.com/pixelphone/thread/95116918))

**Netflix.** Will be hidden in Play Store on any rooted/L3 device — sideload the APK from APKMirror (pick **arm64-v8a**). With PIF passing BASIC+DEVICE, login + playback work. TrickyStore is generally not needed — BASIC+DEVICE is the verdict ceiling on Android 10 anyway. Capped at 540p on L3. ([XDA Strong Integrity guide Mar 2026](https://xdaforums.com/t/4773849/), [Gadget Hacks Widevine cap](https://android.gadgethacks.com/how-to/netflix-caps-video-quality-based-your-phones-widevine-drm-level-heres-check-for-hdr-fhd-support-0329213/))

**Hulu.** Known 2025–2026 failure mode: app launches fine, then buffers indefinitely when you press play. Fix stack: Zygisk DenyList + Shamiko (whitelist mode) + PIF. With that combination it plays. 720p on L3. ([XDA Hulu/Disney+ root thread](https://xdaforums.com/t/4667013/))

**Disney+.** Tightest of the major streamers. Common 2025 symptom: blue-screen error on launch even with PIF installed. Often needs PIF + TrickyStore + Shamiko + DenyList for GMS-adjacent processes (NEVER add GMS itself to DenyList — that breaks PIF). Some users still report intermittent failures. SD only on L3. ([XDA Hulu/Disney+ root thread](https://xdaforums.com/t/4667013/))

**HBO Max / Max.** The 2025-07-09 rebrand from "Max" back to "HBO Max" was a cosmetic auto-update with no app-id change, no detection-stack change. Behaves like before: usually fine with PIF; occasional reports of needing DenyList. SD on L3. ([NPR rebrand](https://www.npr.org/2025/05/15/nx-s1-5399115/), [9to5Mac auto-update](https://9to5mac.com/2025/07/09/hbo-max-comes-full-circle/))

## Play Integrity landscape (Apr 2026)

- **PlayIntegrityFork (osm0sis fork)** is the active successor. The original osm0sis PIF and Universal SafetyNet Fix are dead.
- Fingerprints from Pixel Beta/Canary expire roughly every 6 weeks. The bundled `autopif4` script pulls a fresh one.
- Pair with **Zygisk-Next** (replaces built-in Zygisk on LOS 17.1 since Magisk 27+) and **Shamiko** for visibility hiding.
- **TrickyStore** is only needed for STRONG integrity (banking-class apps). None of the six target streamers require it.

## Apps newly "no root, no service" since 2024

McDonald's, Snapchat, several airline apps, and most US/EU banking apps tightened to require DEVICE integrity in 2025. None of the six target streamers fully blocked rooted users in 2026 — Disney+ comes closest. ([Android Authority May 2025 policy](https://www.androidauthority.com/google-play-integrity-hardware-attestation-3561592/))

## Rapidly-changing facts (stale risk)

1. **PIF fingerprints rotate every ~6 weeks.** Don't pin specific fingerprints in the guide — point users at PIF's GitHub releases and `autopif`.
2. **Disney+ behavior** has been the most volatile of the six — re-test before adding it.
3. **TrickyStore keybox revocations** continue. Feb/Apr 2026 RKP enforcement targets Android 13+ devices only; TB-X304F is unaffected.
4. **Magisk vs KernelSU/APatch:** community is shifting toward SukiSU+SUSFS, but on a SD425 / Android 10 LOS build, plain Magisk + Zygisk-Next + PIFork + Shamiko is the well-trodden path.

## Disagreements with the handoff

| Handoff claim | Research finding |
|---|---|
| "Crunchyroll capped SD/720p ceiling on L3" | Wrong. Crunchyroll plays **1080p** on L3 — outlier among major streamers. |
| "Netflix/Hulu workaround = PIF + TrickyStore" | TrickyStore is optional on Android 10. PIF alone clears Netflix; Hulu needs PIF + Shamiko + DenyList; TrickyStore is for STRONG integrity (banking). |
| Crunchyroll + Prime are root-tolerant | Confirmed. |
| Widevine L3 = SD/720p ceiling for everything | Approximately right with caveats: Crunchyroll 1080p (up), Netflix 540p (down), others 480p–SD. |

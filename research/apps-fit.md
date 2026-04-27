# App fit — required + maybe-later apps on TB-X304F + LOS 17.1

**Captured:** 2026-04-26.

## Use case

**Required apps:**
- Anthropic Claude (`com.anthropic.claude`)
- Microsoft Edge browser
- Bitwarden password manager
- Crunchyroll
- Amazon Prime Video

**Maybe later:**
- Hulu
- Netflix

## Per-app summary

| App | GMS needed? | Root-tolerant? | L3 cap | Hardware caveat |
|---|---|---|---|---|
| Claude | Yes (FCM for push); microG GCM works | Yes (no detection) | n/a | — |
| Edge | No (microG OK; sync is Microsoft, not Google) | Yes | n/a | — |
| Bitwarden | No (F-Droid build available); Play Store build needs GMS for FCM | Yes | n/a | **No biometric on TB-X304F** — no fingerprint or face hardware. PIN/master password only. |
| Crunchyroll | Optional — playback works without GMS; in-app subscribe needs Play Billing → GMS | Yes (no detection) | **1080p (outlier)** | — |
| Prime Video | No (Fire OS-style; works on microG / no-GMS via APKMirror sideload) | Yes (PIF clears occasional "device not supported") | 480p–SD | — |
| Hulu | Yes (login flow + Play services) | Conditional — needs PIF + Zygisk DenyList + Shamiko | 720p | — |
| Netflix | No for app, but **must sideload arm64-v8a APK** (Play Store hides on L3/rooted) | Conditional — PIF BASIC clears | 540p | — |

## Per-app notes

### Claude (`com.anthropic.claude`)

- Email/password login — no Google account required to use the app. ([Claude Help](https://support.claude.com/en/articles/9612887-how-do-i-install-claude-for-android))
- **Push notifications use FCM**, which requires GMS (full GApps) or microG's GCM module. Without either, the app runs but no push notifications.
- No published root detection. Treat as root-tolerant; PIF BASIC sufficient if a future build adds checks.

### Microsoft Edge

- No GMS hard-dependency. Sync is Microsoft's backend.
- Confirmed working on microG. ([wisetux/apps_under_microG](https://github.com/wisetux/apps_under_microG))
- No root detection.

### Bitwarden

- F-Droid build ships without Firebase Messaging. Manual sync only — no push. ([Bitwarden F-Droid contributing docs](https://contributing.bitwarden.com/getting-started/mobile/android/f-droid/))
- Play Store build works on microG with FCM via GCM module.
- **Biometric concern is moot.** TB-X304F has no fingerprint sensor and no face-unlock hardware. ([Lenovo Tab4 10 PSREF spec](https://psref.lenovo.com/syspool/Sys/PDF/Lenovo_Tablets/TAB4_10/TAB4_10_Spec.PDF)) The "Class 3 biometric needs hardware-backed keystore" question never comes up because there's no biometric option to enable. User unlocks with master password / PIN.

### Crunchyroll

- 2026 status re-confirmed: no meaningful root detection, **1080p plays on Widevine L3** (outlier — every other major streamer is L1-gated for HD). ([Crunchy-DL Widevine FAQ](https://github.com/Crunchy-DL/Crunchy-Downloader/discussions/36))
- **Subscription billing nuance:** in-app subscribe flow uses Google Play Billing → requires GMS. Subscribing via the web (crunchyroll.com) and signing into the app afterward bypasses Play Billing — works on no-GMS / microG.

### Amazon Prime Video

- Built to run on Fire OS without GMS; the Play Store APK is largely the same binary. Works with microG + Aurora-sideloaded APK.
- Login uses Amazon account. DRM is Widevine direct.
- Historically the most root-tolerant major streamer; 2025 added some attestation that PIF BASIC clears when triggered. SD ceiling on L3.

### Hulu (maybe-later)

- App launches without PIF but buffers indefinitely on press-play in 2025-2026.
- Fix stack on rooted: PIF + Zygisk DenyList + Shamiko (whitelist mode). 720p on L3. ([XDA Hulu/Disney+ root thread](https://xdaforums.com/t/4667013/))

### Netflix (maybe-later)

- Hidden in Play Store on L3 / rooted devices — **must sideload arm64-v8a APK from APKMirror**.
- PIF BASIC verdict clears playback (TrickyStore not needed on Android 10).
- 540p L3 cap.

## GApps decision

**Recommendation: stay with MindTheGapps full** (current plan). Reasoning:

1. **microG on LOS 17.1 is the pain path.** Official LineageOS signature spoofing only landed in 18.1 (Feb 2025) — 17.1 stock builds don't ship the patch. ([LineageOS gerrit](https://review.lineageos.org/q/717a8db87eaf2c736f0d4ea1a24b188a6fe15c45)) Workarounds:
   - The "LineageOS for microG" 17.1 community fork (unmaintained for TB-X304F)
   - A Magisk signature-spoof module like NanoDroid-patcher (not fully updated for Android 9+)
   - A custom build patch
   None of these is appropriate for a one-shot flash by a non-Android-developer user.
2. **Required apps benefit from full GMS.** Claude (FCM push), Bitwarden (FCM push if Play Store build), Crunchyroll (Play Billing if subscribing in-app). microG's FCM proxy works but adds setup friction.
3. **2GB RAM concern is real but overstated.** MindTheGapps "core" / standard footprint is ~150 MB on disk plus a few hundred MB of Play Services + Play Store background load. microG saves on the order of 200-300 MB but adds setup complexity.
4. **NikGapps `core` arm64** is comparable to MindTheGapps standard for this app set — no meaningful win, more variant churn.

## Plan B — if 2GB RAM proves too tight post-flash

If app switching is sluggish or OOM kills are frequent on the standard plan, the fallback is:

1. Re-flash without GApps (LOS 17.1 only).
2. Install **microG** via Magisk module + LineageOS-microG patcher (or accept LOS doesn't have sig-spoof and use NanoDroid-patcher via Magisk).
3. Install **Aurora Store** for Play Store apps.
4. Use **Bitwarden F-Droid** build (no Firebase).
5. Sideload Edge, Prime Video APKMirror (arm64-v8a).
6. Subscribe to Crunchyroll on the web before signing in on the app.

Trade-offs:
- Lose: in-app subscribe for Crunchyroll, push notifications without microG-GCM, easy Play Store auto-updates.
- Gain: 200-300 MB RAM, fewer background services, faster boot.

Don't do this preemptively — measure first.

## Sources

- [Claude install Help](https://support.claude.com/en/articles/9612887-how-do-i-install-claude-for-android)
- [Bitwarden F-Droid contributing docs](https://contributing.bitwarden.com/getting-started/mobile/android/f-droid/)
- [Bitwarden biometrics help](https://bitwarden.com/help/biometrics/)
- [Lenovo Tab4 10 PSREF spec](https://psref.lenovo.com/syspool/Sys/PDF/Lenovo_Tablets/TAB4_10/TAB4_10_Spec.PDF)
- [Crunchy-DL Widevine FAQ](https://github.com/Crunchy-DL/Crunchy-Downloader/discussions/36)
- [microG Signature Spoofing wiki](https://github.com/microg/GmsCore/wiki/Signature-Spoofing)
- [LineageOS gerrit signature spoof](https://review.lineageos.org/q/717a8db87eaf2c736f0d4ea1a24b188a6fe15c45)
- [LineageOS for microG site](https://lineage.microg.org/)
- [wisetux microG app compatibility list](https://github.com/wisetux/apps_under_microG)
- [FCM Android requirements](https://firebase.google.com/docs/cloud-messaging/android/get-started)
- [XDA Hulu/Disney+ root thread](https://xdaforums.com/t/4667013/)

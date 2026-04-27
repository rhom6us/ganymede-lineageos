# Platform-tools install path verification

**Captured:** 2026-04-26.

## winget package

`winget show --id Google.PlatformTools` returns:

| Field | Value |
|---|---|
| Name | Android SDK Platform-Tools |
| ID | `Google.PlatformTools` |
| Version | **r37.0.0** |
| Publisher | Google LLC |
| Installer Type | portable (zip) |
| Installer URL | `https://dl.google.com/android/repository/platform-tools_r37.0.0-win.zip` |
| Installer SHA256 | `4fe305812db074cea32903a489d061eb4454cbc90a49e8fea677f4b7af764918` |
| Release Date | 2026-03-02 |
| License | Apache-2.0 |

The installer URL is Google's canonical direct-download URL — the same zip the user would manually fetch from https://developer.android.com/tools/releases/platform-tools. The SHA256 is published, so winget integrity-checks the download.

## Portable install behavior

`Installer Type: portable (zip)` means winget extracts the zip to:

```
%LOCALAPPDATA%\Microsoft\WinGet\Packages\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe\
```

and creates `adb.exe` / `fastboot.exe` symlinks in:

```
%LOCALAPPDATA%\Microsoft\WinGet\Links\
```

That `Links` directory is added to the user PATH by winget on first portable install (one-time PATH update; existing terminals need a restart to pick it up). After install + terminal restart, `adb` and `fastboot` resolve from any directory.

## Decision

**winget path is the right call for this project.** Reasoning:

1. Same artifact as manual download (Google's direct URL, SHA256-verified).
2. PATH wiring is automatic — no manual `setx PATH` step.
3. Updates are a one-line `winget upgrade Google.PlatformTools`.
4. 2026-03-02 release = current; tracks Google's monthly platform-tools cadence.

The "manual zip extraction" path the original chat draft suggested still works but is strictly worse: more steps, manual PATH wiring, no integrity check, no upgrade path.

## Caveats

- **First-run PATH refresh.** After `winget install Google.PlatformTools`, a fresh terminal is required for `adb` / `fastboot` to resolve. The current `scripts/restore.ps1` should account for this (or at least warn).
- **Stale terminal sessions** that were open before the install won't see the new PATH — restart pwsh / cmd.
- **No system-wide install option** — winget portable installs are user-scoped. Fine for single-user dev machines.

## Sources

- Direct verification: `winget show --id Google.PlatformTools` (run 2026-04-26).
- Google platform-tools releases: https://developer.android.com/tools/releases/platform-tools
- winget portable install docs: https://learn.microsoft.com/en-us/windows/package-manager/package/manifest#installer-type

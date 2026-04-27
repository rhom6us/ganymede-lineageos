# PowerShell progress bars in concurrent contexts

**Captured:** 2026-04-26.

## Write-Progress from `ForEach-Object -Parallel`

**Confirmed broken (or at least architecturally crippled) in pwsh 7.5.x.** Not fixed in 7.2, 7.3, 7.4, or 7.5 release notes. Most recent corroboration is issue #26843 (filed 2026-02-17 against PSVersion **7.5.4**), where mklement0 — a top PowerShell community contributor — explicitly states: *"The `Write-Progress ... -Completed ...` call for closing the progress bar is apparently ineffective across runspaces (use of `-Parallel`)."*

The earlier claim attributing this to PowerShell/PowerShell#13816 was **wrong**. #13816 is about the Verbose / Debug / Information *streams* not propagating from `-Parallel` runspaces — not the Progress stream. That issue was reopened as #21549, which is still OPEN. The actual canonical issue for progress is **#18847** ("ForEach-Object -Parallel prevents Write-Progress from working in the same pipeline"), filed 2022-12-25 by mklement0 against pwsh 7.3.1, closed the same day with no fix — apparently considered "by design" because parallel iterations run in *separate runspaces with no host*.

The architectural cause was articulated by jhoneill in #21549: each `-Parallel` iteration gets its own runspace. *"The runspace doesn't have a console to write to, so continue / silentlycontinue don't change much."* `Write-Progress` records get written to a stream local to that runspace; the parent host never sees them. The same is true for Verbose/Debug/Information.

There is a related secondary bug, **#18848** (closed 2023-11-22), where `Write-Progress` updates don't render unless the calls are at least 200 ms apart — confirmed still present, attributed to PR #2822's rate limiter. This bites parallel scenarios because if you *did* get progress propagation working, the >200-ms gating would still suppress most updates.

The only release-notes change touching this area was **PR #18887** (merged 2023-01-09, shipped in 7.4): added the `-ProgressAction` common parameter. That's a control knob (`SilentlyContinue`/`Continue`/etc.), not a fix to cross-runspace propagation.

The other issue numbers from the original draft don't correspond to anything relevant: #11340 is about `Get-Process -ComputerName`, #11401 is about `Get-Help`, #15071 is about emoji rendering. Those were all wrong.

**Bottom line for question A:** the original claim is *correct in conclusion* (`Write-Progress` from `ForEach-Object -Parallel` does not propagate to the parent host in pwsh 7.5) but *cited the wrong issue*. The correct citations are #18847 (root issue), #21549 (sibling stream issue still open), and #26843 (recent 7.5.4 confirmation).

## Write-Progress from `Start-ThreadJob`

**Different architecture, partially works — but only with `-StreamingHost $Host`.**

`Start-ThreadJob` (Microsoft-owned module, in-box since pwsh 7.0) runs each job in its own runspace inside the same process, just like `ForEach-Object -Parallel`. By default the same propagation problem applies. The escape hatch is `-StreamingHost $Host`: when present, the thread job's host is connected to the caller's host, so progress *and* host writes flow through to the parent terminal in real time. Issue **#24575** (OPEN, opened 2024-11-13) is the canonical evidence — alx9r's repro starts 100 thread jobs each calling `Write-Progress` with unique `-Id` values via `-StreamingHost $Host`, and the bars *do* render concurrently. The bug being filed is *not* "no bars appear" but "extra bars get left behind after completion" because `Receive-Job` replays buffered progress records.

Important caveat from that thread (mklement0, 2024-11-14): `Write-Progress` output **is not a proper stream** and `Receive-Job` arguably should not buffer or replay it. The workaround is to call `$job.Progress.Clear()` before `Receive-Job`, or to skip `Receive-Job` for the progress data entirely.

So for our use case, `-StreamingHost $Host` is the actual mechanism that makes `Start-ThreadJob` progress visible to cmd.exe. Without it, you have the same cross-runspace blackhole as `-Parallel`. Our current refactor sidesteps both by calling `Write-Progress` *from the main thread* (after polling a synchronized state hashtable), so `-StreamingHost` isn't required — the progress calls happen in the host's own runspace and render normally.

## Host-rendering caveats

**Two views, both work in cmd.exe and Windows Terminal under pwsh 7.5, but with different failure modes.**

`$PSStyle.Progress.View` defaults to `'Minimal'` since pwsh 7.2. The Minimal view renders inline (one or more lines at the bottom of the scroll buffer, ANSI-erased and redrawn on each update). Classic renders in a fixed pane at the top of the console, scrolling content underneath.

- **Minimal view** has a known O(N²) re-render problem when many bars accumulate without `-Completed` being called: each update redraws *every* active bar plus a screen of blank space, flooding the console (issue **#26915**, OPEN, opened 2026 — covers 7.4.x and 7.5.x). For our 5–6 bar use case this isn't a practical concern, but if you ever reuse this pattern with 50+ concurrent items, switch to Classic.
- **Classic view** caps the displayed bars at ~4 per screen; the rest are summarized. With more than 9 distinct `-Id` values old issues showed jumbled output (#7507, closed 2023-11-23 as fixed — verify if you push past 9 simultaneous IDs).
- **CJK / wide character handling** in the Minimal view is broken (#25861, OPEN), but irrelevant for ASCII filenames.
- **Newlines in `-Activity` strings** break clearing in Minimal view (also #25861) — never put `` `n `` in `-Activity`.
- **cmd.exe vs Windows Terminal:** both are VT/ANSI-capable in modern Windows 10/11 builds, and both render Minimal and Classic correctly under pwsh 7.5.5. `pwsh -NoProfile -Command 'Write-Progress -Activity test -Status x -PercentComplete 50; Start-Sleep 3'` shows the bar identically in either terminal. The original "bars never appeared in cmd.exe" symptom was *not* a host-rendering issue — it was the cross-runspace propagation issue. Worth noting because it's a common misdiagnosis.
- **Multiple stacked bars** with distinct `-Id` values render fine *as long as each call is from the host's runspace*. Both views support nested bars via `-ParentId`.

## Better idioms (community survey)

1. **Synchronized hashtable + main-thread polling** — Microsoft's official recommendation, documented in the [`write-progress-across-multiple-threads`](https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/write-progress-across-multiple-threads) deep dive. Pattern: build `[Hashtable]::Synchronized($origin)`, pass into `ForEach-Object -Parallel -AsJob` with `$using:`, each thread mutates its slot, main thread polls and calls `Write-Progress` itself. This is fundamentally what we're doing with `Start-ThreadJob` — the `-AsJob` vs `Start-ThreadJob` choice is cosmetic at this layer.
2. **mklement0's `ForEach-ObjectParallelWithProgress` wrapper** (Stack Overflow 74905668, referenced from #13433) — uses `ForEach-Object -Parallel -AsJob`, then polls `$job.ChildJobs.Where({ $_.State -notin 'NotStarted', 'Running' }).Count` for an aggregate percentage. Simpler than per-task bars but only gives you "X of N done" — no per-file bytes/percent.
3. **`Start-ThreadJob -StreamingHost $Host`** with `Write-Progress` *inside* each thread — works, but bars get left behind on completion (#24575) requiring `$job.Progress.Clear()` cleanup. Awkward.
4. **PSWriteProgress / Indented.ProgressBar / similar PSGallery modules** — searched 2026-04-26; nothing on the Gallery or in active GitHub repos solves the parallel propagation problem at a level above what Microsoft's own deep-dive recommends. They're sugar over `Write-Progress`, not replacements for it. No reason to add a dependency.
5. **Raw ANSI cursor manipulation** (write your own bars to specific terminal rows with `\e[H` positioning) — feasible, but you reinvent line-wrap, terminal-resize, and `$PSStyle.Progress.View` semantics. Only worth it if you need something `Write-Progress` can't express (e.g., 20+ bars, custom colors per bar).

## Decision

**Keep the `Start-ThreadJob` + synchronized state + main-thread `Write-Progress` design.** It is the recommended Microsoft pattern modulo the choice of `Start-ThreadJob` vs `ForEach-Object -Parallel -AsJob` (both are runspace-pool-backed and equivalent for this purpose; `Start-ThreadJob` exposes per-job objects more cleanly). The main-thread renderer dodges every cross-runspace bug catalogued above (#18847, #21549, #24575, #26843), avoids the `-StreamingHost` `Receive-Job`/progress-replay foot-gun, and renders identically in cmd.exe and Windows Terminal.

Recommended hardening for the implementation:

- Default to `$PSStyle.Progress.View = 'Minimal'` (already default in 7.5) — fine for 5–6 bars.
- Always call `Write-Progress -Id N -Completed` for each download once it's finished, in the main-thread render loop. Don't rely on the 100% bar being "obviously done" — leftover bars are a known wart.
- Throttle the main-thread render loop to ~250 ms intervals to stay clear of the #18848/#14322 200-ms rate limit.
- Use `-Id` values starting at 1 and assigned per-download-slot (not per-URL hash). Keeps the bar order stable in Minimal view as downloads complete and slots get reused.

Untested assumption to verify on hardware: the actual cmd.exe rendering. Run the refactored script once with a slow link (or `Start-Sleep` injected into the worker) and confirm bars appear and update before declaring victory.

## Sources

- PowerShell/PowerShell#18847 — *ForEach-Object -Parallel prevents Write-Progress from working in the same pipeline* (closed 2022-12-25): https://github.com/PowerShell/PowerShell/issues/18847
- PowerShell/PowerShell#21549 — *ForEach-Object -Parallel / Start-ThreadJob don't honor unsilencing of silent-by-default streams* (OPEN, reopened from #13816): https://github.com/PowerShell/PowerShell/issues/21549
- PowerShell/PowerShell#13816 — closed 2023-12-04, the original (unrelated to Progress, despite earlier claim): https://github.com/PowerShell/PowerShell/issues/13816
- PowerShell/PowerShell#26843 — *Write-Progress bug when using ForEach-Object -Parallel* (OPEN 2026-02-17, PSVersion 7.5.4): https://github.com/PowerShell/PowerShell/issues/26843
- PowerShell/PowerShell#24575 — *Start-ThreadJob -StreamingHost $Host leaves behind progress bars* (OPEN 2024-11-13): https://github.com/PowerShell/PowerShell/issues/24575
- PowerShell/PowerShell#18848 — *Write-Progress 200ms rate limit* (closed 2023-11-22, won't fix): https://github.com/PowerShell/PowerShell/issues/18848
- PowerShell/PowerShell#14322 — *Write-Progress doesn't always update (rate limited)* (closed 2023-02-18): https://github.com/PowerShell/PowerShell/issues/14322
- PowerShell/PowerShell#26915 — *Minimal progress view re-renders all active bars on every update, causing O(N²) console output* (OPEN): https://github.com/PowerShell/PowerShell/issues/26915
- PowerShell/PowerShell#25861 — *Write-Progress bug with newlines and CJK in -Activity* (OPEN): https://github.com/PowerShell/PowerShell/issues/25861
- PowerShell/PowerShell#13433 — *ForEach-Object -Parallel add ShowProgressBar functionality* (closed 2024-05-23, contains mklement0's wrapper code): https://github.com/PowerShell/PowerShell/issues/13433
- PowerShell/PowerShell#3366 — *Progress bar problems tracking issue* (closed 2022-10-04): https://github.com/PowerShell/PowerShell/issues/3366
- PowerShell/PowerShell PR #18887 — *Add -ProgressAction common parameter* (merged 2023-01-09, shipped in 7.4): https://github.com/PowerShell/PowerShell/pull/18887
- PowerShell/PowerShell PR #2822 — *Write-Progress performance refactor that introduced the rate limiter*: https://github.com/PowerShell/PowerShell/pull/2822
- MicrosoftDocs/PowerShell-Docs#6160 — *Foreach-Object -Parallel examples of how to report progress* (closed 2020-08-07, request that produced the official deep-dive): https://github.com/MicrosoftDocs/PowerShell-Docs/issues/6160
- Microsoft Learn — *Displaying progress while multi-threading* (the official recommended pattern): https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/write-progress-across-multiple-threads
- Microsoft Learn — *What's New in PowerShell 7.5* (no Write-Progress / parallel fixes listed): https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-75
- Microsoft Learn — *What's New in PowerShell 7.4* (`-ProgressAction` common parameter added; no parallel-progress fix): https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-74
- mklement0's `ForEach-ObjectParallelWithProgress` wrapper, full source: https://github.com/PowerShell/PowerShell/issues/13433#issuecomment-1364736200

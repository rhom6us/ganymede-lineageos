[CmdletBinding()]
param(
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
# Leave $ProgressPreference at its default ('Continue') so the main-thread
# render loop's Write-Progress calls actually emit bars. We no longer call
# Invoke-WebRequest (HttpClient streaming instead), so there's nothing
# unwanted to suppress.

$RepoRoot = Split-Path -Parent $PSScriptRoot
$DestDir  = Join-Path $RepoRoot "downloads"
$Throttle = 6

function Write-Step([string]$msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok  ([string]$msg) { Write-Host "[ok] $msg"   -ForegroundColor Green }
function Write-Skip([string]$msg) { Write-Host "[skip] $msg" -ForegroundColor DarkGray }

if (-not (Test-Path $DestDir)) {
  Write-Step "creating $DestDir"
  if (-not $DryRun) { New-Item -ItemType Directory -Path $DestDir | Out-Null }
}

# Load the artifact list. Each entry has a 'kind' that drives dispatch:
#   winget   - sequential winget install
#   direct   - parallel HttpClient download from a direct URL
#   github   - parallel HttpClient download of a release asset (resolved via gh)
#   manual   - print an instruction line at the end (not automatable)
$artifacts = Get-Content -Raw (Join-Path $PSScriptRoot 'artifacts.json') | ConvertFrom-Json

# ----- winget items (sequential, may prompt for UAC) -----
$wingetItems = @($artifacts | Where-Object kind -eq 'winget')
$winget = Get-Command winget -ErrorAction SilentlyContinue
foreach ($w in $wingetItems) {
  Write-Step "winget: $($w.label) ($($w.package))"
  if (-not $winget) {
    Write-Warning "winget not found. Install 'App Installer' from the Microsoft Store, or install $($w.label) manually."
    continue
  }
  $listed = (winget list --id $w.package --exact 2>&1 | Out-String)
  if ($listed -match [regex]::Escape($w.package)) {
    Write-Ok "$($w.package) already installed"
  } elseif ($DryRun) {
    Write-Host "[dry-run] winget install --id $($w.package)"
  } else {
    winget install --id $w.package --exact --silent --accept-source-agreements --accept-package-agreements
  }
}

# ----- parallel downloads via Start-ThreadJob -----
# We deliberately do NOT use ForEach-Object -Parallel here: Write-Progress
# emitted from inside parallel runspaces does not render in the parent host
# (PowerShell/PowerShell#13816, still present as of 7.5). Instead each job
# updates a synchronized state hashtable, and the main thread polls and
# renders Write-Progress itself, so the bars actually show.
$downloadItems = @($artifacts | Where-Object { $_.kind -in 'direct','github' })

if ($downloadItems.Count -gt 0) {
  Write-Step "downloading $($downloadItems.Count) artifacts (up to $Throttle in parallel, with progress bars)"

  $state = [hashtable]::Synchronized(@{})
  foreach ($t in $downloadItems) {
    $state[$t.id] = [hashtable]::Synchronized(@{
      activity = if ($t.kind -eq 'direct') { $t.name } else { "$($t.owner)/$($t.repo)" }
      label    = if ($t.kind -eq 'direct') { $t.label } else { "$($t.owner)/$($t.repo)" }
      written  = [long]0
      total    = [long]0
      status   = 'pending'
      detail   = ''
      tag      = ''
      elapsed  = 0.0
    })
  }

  $jobs = foreach ($task in $downloadItems) {
    Start-ThreadJob -ThrottleLimit $Throttle -ArgumentList $task, $state, $DestDir, $DryRun -ScriptBlock {
      param($task, $state, $destDir, $dryRun)
      $s  = $state[$task.id]
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      try {
        $url = $null; $dest = $null; $expectedSize = [long]0
        if ($task.kind -eq 'direct') {
          $dest = Join-Path $destDir $task.name
          if (Test-Path $dest) { $s.status='skip'; $s.detail="$($task.name) already downloaded"; return }
          if ($dryRun)         { $s.status='dry-run'; $s.detail="$($task.url) -> $dest"; return }
          $url = $task.url
        }
        elseif ($task.kind -eq 'github') {
          $slug = "$($task.owner)/$($task.repo)"
          $info = gh release view --repo $slug --json tagName,assets | ConvertFrom-Json
          $asset = $info.assets | Where-Object { $_.name -like $task.pattern } | Select-Object -First 1
          if (-not $asset) { $s.status='err'; $s.detail="no asset matching '$($task.pattern)' in $($info.tagName)"; return }
          $s.activity = $asset.name
          $s.tag      = $info.tagName
          $dest = Join-Path $destDir $asset.name
          if (Test-Path $dest) { $s.status='skip'; $s.detail="$($asset.name) already downloaded"; return }
          if ($dryRun)         { $s.status='dry-run'; $s.detail="$($asset.name) -> $dest"; return }
          $url = $asset.url
          $expectedSize = [long]$asset.size
        }

        $s.status = 'downloading'
        $client = [System.Net.Http.HttpClient]::new()
        $client.Timeout = [TimeSpan]::FromMinutes(30)
        $client.DefaultRequestHeaders.Add('User-Agent', 'restore-ps1')
        try {
          $resp = $client.GetAsync($url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
          $resp.EnsureSuccessStatusCode() | Out-Null
          $s.total = if ($expectedSize -gt 0) { $expectedSize } else { [long]($resp.Content.Headers.ContentLength ?? 0) }
          $stream = $resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
          $file   = [System.IO.File]::Create($dest)
          try {
            $buffer  = [byte[]]::new(262144)
            $written = [long]0
            while (($n = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
              $file.Write($buffer, 0, $n)
              $written += $n
              $s.written = $written
            }
          } finally {
            $file.Close()
            $stream.Close()
          }
        } finally {
          $client.Dispose()
        }
        $finalMb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
        $name    = Split-Path -Leaf $dest
        $detail  = "$name, $finalMb MB"
        if ($s.tag) { $detail += ", $($s.tag)" }
        $s.detail = $detail
        $s.status = 'done'
      }
      catch {
        $s.status = 'err'
        $s.detail = $_.Exception.Message
      }
      finally {
        $s.elapsed = [math]::Round($sw.Elapsed.TotalSeconds, 1)
      }
    }
  }

  # Main-thread render loop. Polls state, renders Write-Progress per task, and
  # prints a terminal status line once per task as it transitions to a terminal
  # state. Exits when every task has been emitted.
  $emitted   = @{}
  $tickCount = 0
  $totalCount = $downloadItems.Count

  while ($emitted.Count -lt $totalCount) {
    foreach ($task in $downloadItems) {
      $s = $state[$task.id]
      if ($emitted[$task.id]) { continue }

      if ($s.status -eq 'downloading' -and $s.total -gt 0) {
        $pct = [int][math]::Min(100, ($s.written * 100) / $s.total)
        $mb  = [math]::Round($s.written / 1MB, 1)
        $tot = [math]::Round($s.total / 1MB, 1)
        Write-Progress -Id $task.id -Activity $s.activity -Status "$mb / $tot MB ($pct%)" -PercentComplete $pct
      }

      if ($s.status -in 'done','skip','dry-run','err') {
        Write-Progress -Id $task.id -Activity $s.activity -Completed
        $tickCount++
        $msg = "[{0}/{1}] {2}: {3}" -f $tickCount, $totalCount, $s.status, $s.label
        $detail = $s.detail
        if ($s.status -eq 'done' -and $s.elapsed -gt 0) { $detail += ", $($s.elapsed)s" }
        if ($detail) { $msg += " ($detail)" }
        $color = switch ($s.status) {
          'done'    { 'Green' }
          'skip'    { 'DarkGray' }
          'dry-run' { 'DarkGray' }
          'err'     { 'Red' }
          default   { 'Gray' }
        }
        Write-Host $msg -ForegroundColor $color
        $emitted[$task.id] = $true
      }
    }
    if ($emitted.Count -lt $totalCount) { Start-Sleep -Milliseconds 100 }
  }

  $jobs | Receive-Job -ErrorAction SilentlyContinue | Out-Null
  $jobs | Remove-Job -Force
}

# ----- Magisk uninstall.zip safety net (after downloads) -----
$magiskApk = Get-ChildItem -Path $DestDir -Filter "Magisk-v*.apk" -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($magiskApk) {
  $magiskZip    = [IO.Path]::ChangeExtension($magiskApk.FullName, ".zip")
  $uninstallZip = Join-Path $DestDir "uninstall.zip"

  if (-not (Test-Path $magiskZip)) {
    if ($DryRun) { Write-Host "[dry-run] copy $($magiskApk.Name) -> $(Split-Path -Leaf $magiskZip)" }
    else { Copy-Item $magiskApk.FullName $magiskZip; Write-Ok "Magisk .zip copy" }
  } else { Write-Skip "$(Split-Path -Leaf $magiskZip) already exists" }

  if (-not (Test-Path $uninstallZip)) {
    if ($DryRun) { Write-Host "[dry-run] copy $($magiskApk.Name) -> uninstall.zip" }
    else { Copy-Item $magiskApk.FullName $uninstallZip; Write-Ok "uninstall.zip" }
  } else { Write-Skip "uninstall.zip already exists" }
}

# ----- manual reminders -----
$manualItems = @($artifacts | Where-Object kind -eq 'manual')
if ($manualItems.Count -gt 0) {
  Write-Host ""
  Write-Step "Manual downloads (not automatable):"
  foreach ($m in $manualItems) {
    Write-Host "  - $($m.name)"
    Write-Host "    from: $($m.source)"
  }
  Write-Host "  Save to: $DestDir"
  Write-Host ""
}

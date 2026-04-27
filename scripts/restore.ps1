[CmdletBinding()]
param(
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

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

# ----- parallel downloads (direct + github) -----
# Each task gets a unique id so Write-Progress bars stack instead of colliding.
# Invoke-WebRequest's default progress uses Id 1 across all callers, so we
# stream via HttpClient and drive Write-Progress ourselves with the per-task id.
$downloadItems = @($artifacts | Where-Object { $_.kind -in 'direct','github' })

$total    = $downloadItems.Count
$progress = [System.Collections.Concurrent.ConcurrentBag[string]]::new()

if ($total -gt 0) {
  Write-Step "downloading $total artifacts (up to $Throttle in parallel, with progress bars)"

  $downloadItems | ForEach-Object -ThrottleLimit $Throttle -Parallel {
    $task     = $_
    $destDir  = $using:DestDir
    $dryRun   = $using:DryRun
    $progress = $using:progress
    $total    = $using:total

    $ErrorActionPreference = 'Stop'
    $ProgressPreference    = 'Continue'

    $label = if ($task.kind -eq 'direct') { $task.label } else { "$($task.owner)/$($task.repo)" }

    function Tick {
      param($Status, $Label, $Detail = '')
      $progress.Add($Label)
      $n = $progress.Count
      $msg = "[{0}/{1}] {2}: {3}" -f $n, $total, $Status, $Label
      if ($Detail) { $msg += " ($Detail)" }
      $color = switch ($Status) {
        'done'    { 'Green' }
        'skip'    { 'DarkGray' }
        'dry-run' { 'DarkGray' }
        'err'     { 'Red' }
        default   { 'Gray' }
      }
      Write-Host $msg -ForegroundColor $color
    }

    function Save-WithProgress {
      param([string]$Url, [string]$Dest, [int]$Id, [string]$Activity, [long]$ExpectedSize = 0)
      $client = [System.Net.Http.HttpClient]::new()
      $client.Timeout = [TimeSpan]::FromMinutes(30)
      $client.DefaultRequestHeaders.Add('User-Agent', 'restore-ps1')
      try {
        $resp = $client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        $resp.EnsureSuccessStatusCode() | Out-Null
        $size = if ($ExpectedSize -gt 0) { $ExpectedSize } else { [long]($resp.Content.Headers.ContentLength ?? 0) }
        $stream = $resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $file   = [System.IO.File]::Create($Dest)
        try {
          $buffer  = [byte[]]::new(262144)
          $written = [long]0
          $last    = [DateTime]::MinValue
          while (($n = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $file.Write($buffer, 0, $n)
            $written += $n
            $now = [DateTime]::UtcNow
            if (($now - $last).TotalMilliseconds -ge 100) {
              $last = $now
              $mb = [math]::Round($written / 1MB, 1)
              if ($size -gt 0) {
                $pct = [int][math]::Min(100, ($written * 100) / $size)
                $tot = [math]::Round($size / 1MB, 1)
                Write-Progress -Id $Id -Activity $Activity -Status "$mb / $tot MB ($pct%)" -PercentComplete $pct
              } else {
                Write-Progress -Id $Id -Activity $Activity -Status "$mb MB"
              }
            }
          }
        } finally {
          $file.Close()
          $stream.Close()
        }
      } finally {
        $client.Dispose()
        Write-Progress -Id $Id -Activity $Activity -Completed
      }
    }

    Write-Host "[start] $label" -ForegroundColor Cyan
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
      if ($task.kind -eq 'direct') {
        $dest = Join-Path $destDir $task.name
        if (Test-Path $dest) { Tick 'skip' $label "$($task.name) already downloaded"; return }
        if ($dryRun)         { Tick 'dry-run' $label "$($task.url) -> $dest"; return }
        Save-WithProgress -Url $task.url -Dest $dest -Id $task.id -Activity $task.name
        $mb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
        $s  = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        Tick 'done' $label "$($task.name), $mb MB, ${s}s"
      }
      elseif ($task.kind -eq 'github') {
        $slug  = "$($task.owner)/$($task.repo)"
        $info  = gh release view --repo $slug --json tagName,assets | ConvertFrom-Json
        $asset = $info.assets | Where-Object { $_.name -like $task.pattern } | Select-Object -First 1
        if (-not $asset) { Tick 'err' $label "no asset matching '$($task.pattern)' in $($info.tagName)"; return }
        $dest = Join-Path $destDir $asset.name
        if (Test-Path $dest) { Tick 'skip' $label "$($asset.name) already downloaded"; return }
        if ($dryRun)         { Tick 'dry-run' $label "$($asset.name) -> $dest"; return }
        Save-WithProgress -Url $asset.url -Dest $dest -Id $task.id -Activity $asset.name -ExpectedSize ([long]$asset.size)
        $mb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
        $s  = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        Tick 'done' $label "$($asset.name), $mb MB, ${s}s, $($info.tagName)"
      }
    }
    catch {
      Tick 'err' $label $_.Exception.Message
    }
  }
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

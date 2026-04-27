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

# ----- platform-tools via winget (sequential) -----
Write-Step "platform-tools (winget Google.PlatformTools)"
$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
  Write-Warning "winget not found. Install 'App Installer' from the Microsoft Store, or download platform-tools manually."
} else {
  $listed = (winget list --id Google.PlatformTools --exact 2>&1 | Out-String)
  if ($listed -match "Google\.PlatformTools") {
    Write-Ok "Google.PlatformTools already installed"
  } elseif ($DryRun) {
    Write-Host "[dry-run] winget install --id Google.PlatformTools"
  } else {
    winget install --id Google.PlatformTools --exact --silent --accept-source-agreements --accept-package-agreements
  }
}

# ----- parallel downloads -----
# Each task gets a unique ProgressId so Write-Progress bars stack instead of
# colliding. Invoke-WebRequest's default progress uses Id 1 across all callers,
# so we stream via HttpClient and drive Write-Progress ourselves with the
# per-task id.
$tasks = @(
  [pscustomobject]@{ ProgressId=1; Kind='direct'; Label='LineageOS 17.1 ROM (Wasabi mirror)'
                     Url='https://s3.us-west-1.wasabisys.com/rom-release/LineageOS/17.1/TB-X304F/lineage-17.1-20220710-UNOFFICIAL-TBX304F.zip'
                     Name='lineage-17.1-20220710-UNOFFICIAL-TBX304F.zip' }
  [pscustomobject]@{ ProgressId=2; Kind='github'; Owner='topjohnwu';    Repo='Magisk';            Pattern='Magisk-v*.apk' }
  [pscustomobject]@{ ProgressId=3; Kind='github'; Owner='MindTheGapps'; Repo='10.0.0-arm64';      Pattern='MindTheGapps-10.0.0-arm64-*.zip' }
  [pscustomobject]@{ ProgressId=4; Kind='github'; Owner='osm0sis';      Repo='PlayIntegrityFork'; Pattern='*.zip' }
  [pscustomobject]@{ ProgressId=5; Kind='github'; Owner='5ec1cff';      Repo='TrickyStore';       Pattern='*.zip' }
)

$total    = $tasks.Count
$progress = [System.Collections.Concurrent.ConcurrentBag[string]]::new()

Write-Step "downloading $total artifacts (up to $Throttle in parallel, with progress bars)"

$tasks | ForEach-Object -ThrottleLimit $Throttle -Parallel {
  $task     = $_
  $destDir  = $using:DestDir
  $dryRun   = $using:DryRun
  $progress = $using:progress
  $total    = $using:total

  $ErrorActionPreference = 'Stop'
  $ProgressPreference    = 'Continue'

  $label = if ($task.Kind -eq 'direct') { $task.Label } else { "$($task.Owner)/$($task.Repo)" }

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
    if ($task.Kind -eq 'direct') {
      $dest = Join-Path $destDir $task.Name
      if (Test-Path $dest) { Tick 'skip' $label "$($task.Name) already downloaded"; return }
      if ($dryRun)         { Tick 'dry-run' $label "$($task.Url) -> $dest"; return }
      Save-WithProgress -Url $task.Url -Dest $dest -Id $task.ProgressId -Activity $task.Name
      $mb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
      $s  = [math]::Round($sw.Elapsed.TotalSeconds, 1)
      Tick 'done' $label "$($task.Name), $mb MB, ${s}s"
    }
    elseif ($task.Kind -eq 'github') {
      $slug  = "$($task.Owner)/$($task.Repo)"
      $info  = gh release view --repo $slug --json tagName,assets | ConvertFrom-Json
      $asset = $info.assets | Where-Object { $_.name -like $task.Pattern } | Select-Object -First 1
      if (-not $asset) { Tick 'err' $label "no asset matching '$($task.Pattern)' in $($info.tagName)"; return }
      $dest = Join-Path $destDir $asset.name
      if (Test-Path $dest) { Tick 'skip' $label "$($asset.name) already downloaded"; return }
      if ($dryRun)         { Tick 'dry-run' $label "$($asset.name) -> $dest"; return }
      Save-WithProgress -Url $asset.url -Dest $dest -Id $task.ProgressId -Activity $asset.name -ExpectedSize ([long]$asset.size)
      $mb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
      $s  = [math]::Round($sw.Elapsed.TotalSeconds, 1)
      Tick 'done' $label "$($asset.name), $mb MB, ${s}s, $($info.tagName)"
    }
  }
  catch {
    Tick 'err' $label $_.Exception.Message
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
Write-Host ""
Write-Step "Manual downloads (XDA-hosted, not automatable):"
Write-Host "  - LineageOS 17.1 zip for TB-X304F"
Write-Host "  - tbx304-twrp-3.4.0-20201207.img"
Write-Host "  Linked from: https://xdaforums.com/t/rom-unofficial-10-0-tb-x304f-tb-8504f-lineageos-17-1-for-lenovo-tab4-8-10-wifi.4466879/"
Write-Host "  Save both to: $DestDir"
Write-Host ""

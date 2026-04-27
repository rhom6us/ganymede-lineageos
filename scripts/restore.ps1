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
$tasks = @(
  [pscustomobject]@{
    Kind  = 'direct'
    Label = 'LineageOS 17.1 ROM (Wasabi mirror)'
    Url   = 'https://s3.us-west-1.wasabisys.com/rom-release/LineageOS/17.1/TB-X304F/lineage-17.1-20220710-UNOFFICIAL-TBX304F.zip'
    Name  = 'lineage-17.1-20220710-UNOFFICIAL-TBX304F.zip'
  }
  [pscustomobject]@{ Kind='github'; Owner='topjohnwu';    Repo='Magisk';            Pattern='Magisk-v*.apk' }
  [pscustomobject]@{ Kind='github'; Owner='MindTheGapps'; Repo='10.0.0-arm64';      Pattern='MindTheGapps-10.0.0-arm64-*.zip' }
  [pscustomobject]@{ Kind='github'; Owner='osm0sis';      Repo='PlayIntegrityFork'; Pattern='*.zip' }
  [pscustomobject]@{ Kind='github'; Owner='5ec1cff';      Repo='TrickyStore';       Pattern='*.zip' }
)

$total    = $tasks.Count
$progress = [System.Collections.Concurrent.ConcurrentBag[string]]::new()

Write-Step "downloading $total artifacts (up to $Throttle in parallel)"

$tasks | ForEach-Object -ThrottleLimit $Throttle -Parallel {
  $task     = $_
  $destDir  = $using:DestDir
  $dryRun   = $using:DryRun
  $progress = $using:progress
  $total    = $using:total

  $ErrorActionPreference = 'Stop'
  $ProgressPreference    = 'SilentlyContinue'

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

  Write-Host "[start] $label" -ForegroundColor Cyan
  $sw = [System.Diagnostics.Stopwatch]::StartNew()

  try {
    if ($task.Kind -eq 'direct') {
      $dest = Join-Path $destDir $task.Name
      if (Test-Path $dest) { Tick 'skip' $label "$($task.Name) already downloaded"; return }
      if ($dryRun)         { Tick 'dry-run' $label "$($task.Url) -> $dest"; return }
      Invoke-WebRequest -Uri $task.Url -OutFile $dest
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
      gh release download --repo $slug --pattern $asset.name --dir $destDir | Out-Null
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

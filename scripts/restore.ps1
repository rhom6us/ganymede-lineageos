[CmdletBinding()]
param(
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$DestDir  = Join-Path $RepoRoot "downloads"

function Write-Step([string]$msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok  ([string]$msg) { Write-Host "[ok] $msg" -ForegroundColor Green }
function Write-Skip([string]$msg) { Write-Host "[skip] $msg" -ForegroundColor DarkGray }

if (-not (Test-Path $DestDir)) {
  Write-Step "creating $DestDir"
  if (-not $DryRun) { New-Item -ItemType Directory -Path $DestDir | Out-Null }
}

# ----- platform-tools via winget -----
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

# ----- helper: download from a direct URL -----
function Save-DirectUrl {
  param(
    [Parameter(Mandatory)] [string]$Url,
    [Parameter(Mandatory)] [string]$DestName,
    [string]$Label = $null
  )
  $what = if ($Label) { $Label } else { $DestName }
  Write-Step $what
  $dest = Join-Path $DestDir $DestName
  if (Test-Path $dest) {
    Write-Skip "$DestName already downloaded"
    return $dest
  }
  if ($DryRun) {
    Write-Host "[dry-run] $Url -> $dest"
    return $dest
  }
  Invoke-WebRequest -Uri $Url -OutFile $dest
  $sizeMb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
  Write-Ok "$DestName ($sizeMb MB)"
  return $dest
}

# ----- LineageOS 17.1 ROM (Wasabi S3 — direct mirror from XDA OP) -----
Save-DirectUrl `
  -Url "https://s3.us-west-1.wasabisys.com/rom-release/LineageOS/17.1/TB-X304F/lineage-17.1-20220710-UNOFFICIAL-TBX304F.zip" `
  -DestName "lineage-17.1-20220710-UNOFFICIAL-TBX304F.zip" `
  -Label "LineageOS 17.1 ROM (Wasabi mirror)"

# ----- helper: latest GitHub release asset -----
function Save-LatestAsset {
  param(
    [Parameter(Mandatory)] [string]$Owner,
    [Parameter(Mandatory)] [string]$Repo,
    [Parameter(Mandatory)] [scriptblock]$Match,
    [string]$RenameTo = $null
  )
  Write-Step "$Owner/$Repo"
  $hdrs = @{
    "User-Agent" = "ganymede-lineageos-restore"
    "Accept"     = "application/vnd.github+json"
  }
  $api = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
  try {
    $rel = Invoke-RestMethod -Uri $api -Headers $hdrs
  } catch {
    Write-Warning "GitHub API call failed for $Owner/$Repo — $($_.Exception.Message)"
    return
  }
  $asset = $rel.assets | Where-Object $Match | Select-Object -First 1
  if (-not $asset) {
    Write-Warning "no matching asset in $Owner/$Repo $($rel.tag_name)"
    return
  }
  $name = if ($RenameTo) { $RenameTo } else { $asset.name }
  $dest = Join-Path $DestDir $name
  if (Test-Path $dest) {
    Write-Skip "$name already downloaded"
    return $dest
  }
  if ($DryRun) {
    Write-Host "[dry-run] $($asset.browser_download_url) -> $dest"
    return $dest
  }
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest
  $sizeMb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
  Write-Ok "$name ($sizeMb MB) — $($rel.tag_name)"
  return $dest
}

Save-LatestAsset -Owner "topjohnwu"     -Repo "Magisk"            -Match { $_.name -match "^Magisk-v[\d\.]+\.apk$" }
Save-LatestAsset -Owner "MindTheGapps"  -Repo "10.0.0-arm64"      -Match { $_.name -like "MindTheGapps-10.0.0-arm64-*.zip" }
Save-LatestAsset -Owner "osm0sis"       -Repo "PlayIntegrityFork" -Match { $_.name -like "*.zip" }
Save-LatestAsset -Owner "5ec1cff"       -Repo "TrickyStore"       -Match { $_.name -like "*.zip" }

# ----- Magisk uninstall.zip safety net -----
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

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

$Repo = "lordforcuadd/Overlord"
$ApiUrl = "https://api.github.com/repos/$Repo/releases/latest"
$ReleaseData = Invoke-RestMethod -Uri $ApiUrl -UseBasicParsing

$Asset = $ReleaseData.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1
$DownloadUrl = $Asset.browser_download_url
$FileName = $Asset.name

if ($null -eq $DownloadUrl) {
    exit 1
}

$TempDir = Join-Path $env:TEMP "OverlordSuite"
if (!(Test-Path $TempDir)) {
    New-Item -Path $TempDir -ItemType Directory | Out-Null
}

$ExePath = Join-Path $TempDir $FileName

Invoke-WebRequest -Uri $DownloadUrl -OutFile $ExePath -UseBasicParsing

if (Test-Path $ExePath) {
    Start-Process -FilePath $ExePath -Verb RunAs -Wait
    Remove-Item -Path $TempDir -Recurse -Force
}
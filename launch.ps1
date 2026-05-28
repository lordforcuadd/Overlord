$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = "lordforcuadd/Overlord"
$ApiUrl = "https://api.github.com/repos/$Repo/releases/latest"
$ReleaseData = Invoke-RestMethod -Uri $ApiUrl -UseBasicParsing

$Asset = $ReleaseData.assets | Where-Object { $_.name -eq "Overlord.exe" } | Select-Object -First 1
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
$GlobalLog = "C:\overlord_errors.log"

if (Test-Path $GlobalLog) { Remove-Item $GlobalLog -Force }

Invoke-WebRequest -Uri $DownloadUrl -OutFile $ExePath -UseBasicParsing

if (Test-Path $ExePath) {
    Start-Process -FilePath $ExePath -Wait
    
    if (Test-Path $GlobalLog) {
        Write-Host "`n=======================================================" -ForegroundColor Red
        Write-Host "⚠️  OVERLORD V2.6 - INFORME DE EXCEPCIONES" -ForegroundColor Yellow -BackgroundColor Black
        Write-Host "=======================================================" -ForegroundColor Red
        
        Get-Content $GlobalLog | ForEach-Object {
            Write-Host $_ -ForegroundColor BrightRed
        }
        Write-Host "=======================================================\n" -ForegroundColor Red
        
        Write-Host "Presiona cualquier tecla para limpiar y cerrar la auditoría..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
        Remove-Item $GlobalLog -Force
    }

    Remove-Item -Path $TempDir -Recurse -Force
}
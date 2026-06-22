$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "[*] Conectando con los servidores de GitHub para buscar actualizaciones..." -ForegroundColor Gray

$Repo = "lordforcuadd/Overlord"
$ApiUrl = "https://api.github.com/repos/$Repo/releases/latest"
$ReleaseData = Invoke-RestMethod -Uri $ApiUrl -UseBasicParsing

$Version = if ($null -ne $ReleaseData -and $null -ne $ReleaseData.tag_name) {
    $ReleaseData.tag_name -replace '^v', ''
} else {
    "4.5.0"
}

$Asset = $ReleaseData.assets | Where-Object { $_.name -eq "Overlord.exe" } | Select-Object -First 1
$HashAsset = $ReleaseData.assets | Where-Object { $_.name -eq "Overlord.exe.sha256" } | Select-Object -First 1

$DownloadUrl = $Asset.browser_download_url
$FileName = $Asset.name

if ($null -eq $DownloadUrl) {
    Write-Host "[-] Error critico: No se pudo localizar el binario de produccion en el servidor." -ForegroundColor Red
    exit 1
}

$TempDir = Join-Path $env:TEMP "OverlordSuite"
if (!(Test-Path $TempDir)) {
    New-Item -Path $TempDir -ItemType Directory | Out-Null
}

$ExePath = Join-Path $TempDir $FileName
$HashPath = Join-Path $TempDir "Overlord.exe.sha256"
$GlobalLog = Join-Path $TempDir "overlord_errors.log"

if (Test-Path $GlobalLog) { Remove-Item $GlobalLog -Force }

Write-Host "[*] Descargando la suite Overlord v$Version..." -ForegroundColor Gray
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ExePath -UseBasicParsing

$ExecutionPermitted = $false

if (Test-Path $ExePath) {
    if ($null -ne $HashAsset) {
        Write-Host "[*] Descargando firma digital SHA256 de verificacion..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $HashAsset.browser_download_url -OutFile $HashPath -UseBasicParsing

        if (Test-Path $HashPath) {
            $RawHashContent = (Get-Content $HashPath -Raw).Trim()
            $ExpectedHash = ""
            if ($RawHashContent -match "([a-fA-F0-9]{64})") {
                $ExpectedHash = $Matches[1].ToLower()
            }

            $CalculatedHash = (Get-FileHash -Path $ExePath -Algorithm SHA256).Hash.ToLower()

            if ($CalculatedHash -eq $ExpectedHash) {
                Write-Host "[+] Validacion SHA256 Exitosa. Integridad y procedencia del binario confirmadas [100% Seguro]." -ForegroundColor Green
                $ExecutionPermitted = $true
            } else {
                Write-Host "`n=======================================================" -ForegroundColor Red
                Write-Host "🚨 ¡ALERTA CRÍTICA DE MANIPULACIÓN / CORRUPCIÓN DETECTADA!" -ForegroundColor Red -BackgroundColor Black
                Write-Host "=======================================================" -ForegroundColor Red
                Write-Host "El hash del archivo descargado NO coincide con la firma oficial de GitHub de LordForCuadd." -ForegroundColor Yellow
                Write-Host "El archivo pudo haber sido interceptado, alterado o descargado de forma corrupta." -ForegroundColor Yellow
                Write-Host " -> Hash Esperado: $ExpectedHash" -ForegroundColor Green
                Write-Host " -> Hash Obtenido: $CalculatedHash" -ForegroundColor Red
                Write-Host "=======================================================\n" -ForegroundColor Red
            }
        } else {
            Write-Host "[-] Firma descargada pero ilegible. Abortando ejecucion por seguridad." -ForegroundColor Red
        }
    } else {
        Write-Host "[-] ERROR CRÍTICO: No se encontro el archivo de firma Overlord.exe.sha256 en la release. Abortando ejecucion por seguridad." -ForegroundColor Red
    }

    if ($ExecutionPermitted) {
        Write-Host "[*] Inicializando subproceso de Kernel..." -ForegroundColor Gray
        Start-Process -FilePath $ExePath -Wait
        
        if (Test-Path $GlobalLog) {
            Write-Host "`n=======================================================" -ForegroundColor Red
            Write-Host "⚠️  OVERLORD V$Version - INFORME DE EXCEPCIONES" -ForegroundColor Yellow -BackgroundColor Black
            Write-Host "=======================================================" -ForegroundColor Red
            
            Get-Content $GlobalLog | ForEach-Object {
                Write-Host $_ -ForegroundColor BrightRed
            }
            Write-Host "=======================================================\n" -ForegroundColor Red
            
            Write-Host "Presiona cualquier tecla para limpiar y cerrar la auditoría..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
            Remove-Item $GlobalLog -Force
        }
    }

    Remove-Item -Path $TempDir -Recurse -Force
} else {
    Write-Host "[-] Error critico: No se pudo descargar u obtener el ejecutable de Overlord." -ForegroundColor Red
}
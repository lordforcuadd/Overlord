$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

Write-Host "[*] Conectando con los servidores de GitHub para buscar actualizaciones..." -ForegroundColor Gray

$Repo = "lordforcuadd/Overlord"
$ApiUrl = "https://api.github.com/repos/$Repo/releases/latest"

$ReleaseData = $null
try {
    $ReleaseData = Invoke-RestMethod -Uri $ApiUrl -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "[-] Advertencia: No se pudo conectar con la API de GitHub (posible Rate-Limit): $_" -ForegroundColor Yellow
}

$Version = "latest"
if ($null -ne $ReleaseData -and $null -ne $ReleaseData.tag_name) {
    $Version = $ReleaseData.tag_name -replace '^v', ''
} else {
    $LocalPkg = Join-Path $PSScriptRoot "package.json"
    if (Test-Path $LocalPkg) {
        try {
            $PkgData = Get-Content -Path $LocalPkg -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($null -ne $PkgData -and $null -ne $PkgData.version) {
                $Version = $PkgData.version
            }
        } catch {}
    }
}

$Asset = $null
$HashAsset = $null
if ($null -ne $ReleaseData -and $null -ne $ReleaseData.assets) {
    $Asset = $ReleaseData.assets | Where-Object { $_.name -eq "Overlord.exe" } | Select-Object -First 1
    $HashAsset = $ReleaseData.assets | Where-Object { $_.name -eq "Overlord.exe.sha256" } | Select-Object -First 1
}

$DownloadUrl = if ($null -ne $Asset) { $Asset.browser_download_url } elseif ($null -eq $ReleaseData) { "https://github.com/$Repo/releases/latest/download/Overlord.exe" } else { $null }
$HashDownloadUrl = if ($null -ne $HashAsset) { $HashAsset.browser_download_url } elseif ($null -eq $ReleaseData) { "https://github.com/$Repo/releases/latest/download/Overlord.exe.sha256" } else { $null }
$FileName = if ($null -ne $Asset) { $Asset.name } else { "Overlord.exe" }

$ProgData = $env:ProgramData
if ([string]::IsNullOrWhiteSpace($ProgData)) { $ProgData = "C:\ProgramData" }
$TempDir = Join-Path $ProgData "OverlordSuite"

if (!(Test-Path $TempDir)) {
    try {
        New-Item -Path $TempDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "[-] Error critico: No se pudo crear el directorio de trabajo seguro: $_" -ForegroundColor Red
        exit 1
    }
} else {
    try {
        Get-ChildItem -Path $TempDir -Exclude "Overlord.exe" -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    } catch {}
}

try {
    $Acl = Get-Acl $TempDir
    $Acl.SetAccessRuleProtection($true, $false)
    $SystemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $AdminsRule = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $AdminsRule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administradores", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $UsersRule  = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Users", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
    $UsersRule2  = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Usuarios", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
    
    $Acl.AddAccessRule($SystemRule)
    $Acl.AddAccessRule($AdminsRule)
    try { $Acl.AddAccessRule($AdminsRule2) } catch {}
    $Acl.AddAccessRule($UsersRule)
    try { $Acl.AddAccessRule($UsersRule2) } catch {}
    
    Set-Acl -Path $TempDir -AclObject $Acl | Out-Null
} catch {
    Write-Host "[*] Advertencia: No se pudieron endurecer los permisos NTFS del directorio de trabajo." -ForegroundColor Yellow
}

$ExePath = Join-Path $TempDir $FileName
$HashPath = Join-Path $TempDir "Overlord.exe.sha256"
$GlobalLog = Join-Path $TempDir "overlord_errors.log"

$ExecutionPermitted = $false

if ($null -ne $DownloadUrl) {
    if ($DownloadUrl -notmatch '^https://github\.com/') {
        Write-Host "[-] Error critico: La URL de descarga no pertenece al dominio oficial github.com: $DownloadUrl" -ForegroundColor Red
        exit 1
    }
    try {
        Write-Host "[*] Descargando la suite Overlord v$Version..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ExePath -UseBasicParsing -ErrorAction Stop
        $ExecutionPermitted = $true
    } catch {
        Write-Host "[-] Error critico: Fallo la descarga de la suite Overlord: $_" -ForegroundColor Red
    }
    
    if ($ExecutionPermitted -and $null -ne $HashDownloadUrl) {
        $ExecutionPermitted = $false
        try {
            Write-Host "[*] Descargando firma digital SHA256 de verificacion..." -ForegroundColor Gray
            Invoke-WebRequest -Uri $HashDownloadUrl -OutFile $HashPath -UseBasicParsing -ErrorAction Stop
            
            if (Test-Path $HashPath) {
                $RawHashContent = (Get-Content $HashPath -Raw -ErrorAction Stop).Trim()
                $ExpectedHash = ""
                if ($RawHashContent -match "([a-fA-F0-9]{64})") {
                    $ExpectedHash = $Matches[1].ToLower()
                }

                $CalculatedHash = (Get-FileHash -Path $ExePath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLower()

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
        } catch {
            Write-Host "[-] Error al verificar la firma SHA256: $_. Abortando ejecucion por seguridad." -ForegroundColor Red
            $ExecutionPermitted = $false
        }
    } elseif ($null -eq $HashDownloadUrl -and $null -ne $DownloadUrl) {
        Write-Host "[-] ERROR CRÍTICO: No se encontro el archivo de firma Overlord.exe.sha256 en la release. Abortando ejecucion por seguridad." -ForegroundColor Red
        $ExecutionPermitted = $false
    }
} else {
    # Si no se pudo obtener el link de descarga (por ejemplo, sin internet), buscar si existe una versión descargada previamente
    if (Test-Path $ExePath) {
        Write-Host "[*] Validando integridad del binario local cacheado..." -ForegroundColor Gray
        $Signature = Get-AuthenticodeSignature -FilePath $ExePath -ErrorAction SilentlyContinue
        if ($null -ne $Signature -and $Signature.Status -eq "Valid" -and $Signature.SignerCertificate.Subject -match "CN=Overlord") {
            Write-Host "[+] Binario local validado mediante firma digital." -ForegroundColor Green
            $ExecutionPermitted = $true
        } else {
            Write-Host "[-] ERROR CRÍTICO: El binario local no posee una firma digital válida o está corrupto/manipulado. Abortando por seguridad." -ForegroundColor Red
            $ExecutionPermitted = $false
        }
    } else {
        Write-Host "[-] Error critico: No se pudo localizar el binario en linea y no existe una copia local cacheada." -ForegroundColor Red
    }
}

try {
    if ($ExecutionPermitted -and (Test-Path $ExePath)) {
        Write-Host "[*] Inicializando subproceso de Kernel..." -ForegroundColor Gray
        try {
            Start-Process -FilePath $ExePath -Wait -ErrorAction Stop
        } catch {
            Write-Host "[-] Error al iniciar el subproceso de Overlord: $_" -ForegroundColor Red
        }
        
        if (Test-Path $GlobalLog) {
            Write-Host "`n=======================================================" -ForegroundColor Red
            Write-Host "⚠️  OVERLORD V$Version - INFORME DE EXCEPCIONES" -ForegroundColor Yellow -BackgroundColor Black
            Write-Host "=======================================================" -ForegroundColor Red
            
            try {
                Get-Content $GlobalLog -ErrorAction Stop | ForEach-Object {
                    Write-Host $_ -ForegroundColor BrightRed
                }
            } catch {}
            Write-Host "=======================================================\n" -ForegroundColor Red
            
            Write-Host "Presiona cualquier tecla para limpiar y cerrar la auditoría..." -ForegroundColor Gray
            try {
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            } catch {}
        
            try { Remove-Item $GlobalLog -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
} finally {
    if (Test-Path $TempDir) {
        try {
            Get-ChildItem -Path $TempDir -Exclude "Overlord.exe" -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }
}
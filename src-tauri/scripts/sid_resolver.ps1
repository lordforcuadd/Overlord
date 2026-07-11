# sid_resolver.ps1 â€” ResoluciÃ³n unificada y robusta de SID y HKCU_Path
$UserSID = ""
$Username = $null

# Fallback 1: Buscar dueÃ±o de explorer.exe mediante CIM
try {
    $Explorer = Get-CimInstance -ClassName Win32_Process -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Explorer) {
        $Owner = Invoke-CimMethod -InputObject $Explorer -MethodName GetOwner -ErrorAction SilentlyContinue
        if ($Owner -and $Owner.User) {
            $Username = $Owner.User
        }
    }
} catch { Write-Warning "Fallback SID [1] fallido: $_" }

# Fallback 2: Win32_ComputerSystem
if ([string]::IsNullOrWhiteSpace($Username)) {
    try {
        $Username = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
        if ($Username -match '\\(.+)$') { $Username = $Matches[1] }
    } catch { Write-Warning "Fallback SID [2] fallido: $_" }
}

# Fallback 3: Nombre de usuario desde explorer.exe (proceso secundario)
if ([string]::IsNullOrWhiteSpace($Username)) {
    try {
        $Username = (Get-Process -Name explorer -IncludeUserName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty UserName -First 1)
        if ($Username -match '\\(.+)$') { $Username = $Matches[1] }
    } catch { Write-Warning "Fallback SID [3] fallido: $_" }
}

# Fallback 4: Variable de entorno USERNAME
if ([string]::IsNullOrWhiteSpace($Username)) {
    $Username = $env:USERNAME
}

# Intentar obtener SID de perfil cargado activamente (excluyendo cuentas de sistema)
try {
    $ActiveProfile = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { $_.Loaded -eq $true -and $_.SID -match '^S-1-5-21-' } | Select-Object -First 1
    if ($ActiveProfile) {
        $UserSID = $ActiveProfile.SID
    }
} catch { Write-Warning "Fallback SID [4] fallido: $_" }

# Fallback: Traducir a SID a partir del Username si no se obtuvo
if ([string]::IsNullOrWhiteSpace($UserSID) -and -not [string]::IsNullOrWhiteSpace($Username)) {
    try {
        $NtAccount = New-Object System.Security.Principal.NTAccount($Username)
        $UserSID = $NtAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch { Write-Warning "Fallback SID [5] fallido: $_"
        try {
            $UserSID = (Get-CimInstance -ClassName Win32_UserAccount -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $Username }).SID
        } catch { Write-Warning "Fallback SID [6] fallido: $_" }
    }
}

# Fallback 5: Encontrar subclave de usuario en HKEY_USERS con Volatile Environment
if ([string]::IsNullOrWhiteSpace($UserSID)) {
    try {
        $HKeyUsers = [Microsoft.Win32.Registry]::Users
        foreach ($SubkeyName in $HKeyUsers.GetSubKeyNames()) {
            if ($SubkeyName -match '^S-1-5-21-\d+-\d+-\d+-\d+$') {
                $VolatileKey = "Registry::HKEY_USERS\$SubkeyName\Volatile Environment"
                if (Test-Path $VolatileKey) {
                    $UserSID = $SubkeyName
                    break
                }
            }
        }
    } catch { Write-Warning "Fallback SID [7] fallido: $_" }
}

# Definir la variable global de ruta de usuario
if (-not [string]::IsNullOrWhiteSpace($UserSID)) {
    $global:HKCU_Path = "Registry::HKEY_USERS\$UserSID"
} else {
    $global:HKCU_Path = "HKCU:"
}
$HKCU_Path = $global:HKCU_Path

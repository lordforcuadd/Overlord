# sid_resolver.ps1 - Resolucion unificada y robusta de SID y HKCU_Path
$UserSID = ""
$Username = $null

# Fallback 1: Buscar dueno de explorer.exe mediante CIM
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

# 1. Si tenemos $Username, traducir de forma directa y determinista a SID
if (-not [string]::IsNullOrWhiteSpace($Username)) {
    try {
        $NtAccount = New-Object System.Security.Principal.NTAccount($Username)
        $UserSID = $NtAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch { 
        Write-Warning "Fallback SID [Traducir NTAccount] fallido para ${Username}: $_"
        try {
            $UserSID = (Get-CimInstance -ClassName Win32_UserAccount -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $Username }).SID
        } catch { Write-Warning "Fallback SID [Win32_UserAccount] fallido para ${Username}: $_" }
    }
}

# 2. Si no se obtuvo SID por traducción, buscar perfil cargado activamente vinculando a $Username si está disponible
if ([string]::IsNullOrWhiteSpace($UserSID)) {
    try {
        $LoadedProfiles = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { $_.Loaded -eq $true -and ($_.SID -match '^S-1-5-21-' -or $_.SID -match '^S-1-12-1-') }
        if ($LoadedProfiles) {
            $MatchedProfile = if (-not [string]::IsNullOrWhiteSpace($Username)) {
                $LoadedProfiles | Where-Object { $_.LocalPath -like "*\$Username" } | Select-Object -First 1
            } else { $null }

            $TargetProfile = if ($MatchedProfile) { $MatchedProfile } else { $null }
            if ($TargetProfile) {
                $UserSID = $TargetProfile.SID
            }
        }
    } catch { Write-Warning "Fallback SID [Win32_UserProfile] fallido: $_" }
}

# 3. Fallback: Encontrar subclave de usuario en HKEY_USERS con Volatile Environment
if ([string]::IsNullOrWhiteSpace($UserSID)) {
    try {
        $HKeyUsers = [Microsoft.Win32.Registry]::Users
        foreach ($SubkeyName in $HKeyUsers.GetSubKeyNames()) {
            if (($SubkeyName -match '^S-1-5-21-\d+-\d+-\d+-\d+$' -or $SubkeyName -match '^S-1-12-1-\d+-\d+-\d+-\d+$') -and $SubkeyName -notmatch '_Classes$') {
                $VolatileKey = "Registry::HKEY_USERS\$SubkeyName\Volatile Environment"
                if (Test-Path $VolatileKey) {
                    if (-not [string]::IsNullOrWhiteSpace($Username)) {
                        $VolatileUser = (Get-ItemProperty -Path $VolatileKey -Name "USERNAME" -ErrorAction SilentlyContinue).USERNAME
                        if ($VolatileUser -and $VolatileUser -eq $Username) {
                            $UserSID = $SubkeyName
                            break
                        }
                    } else {
                        $UserSID = $SubkeyName
                        break
                    }
                }
            }
        }
    } catch { Write-Warning "Fallback SID [Volatile Environment] fallido: $_" }
}

# Definir la variable global de ruta de usuario
if (-not [string]::IsNullOrWhiteSpace($UserSID)) {
    $global:HKCU_Path = "Registry::HKEY_USERS\$UserSID"
} else {
    $global:HKCU_Path = "HKCU:"
}
$HKCU_Path = $global:HKCU_Path

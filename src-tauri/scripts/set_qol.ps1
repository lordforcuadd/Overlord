param(
    [string]$ToggleName,
    [string]$IsEnabledStr
)

$ErrorActionPreference = "Continue"

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$AdminToggles = @(
    "disableLockScreen", "disableCopilot", "disableRecall", 
    "detailedBSoD", "disableOneDrive", "disableWidgets", "enableGameMode"
)

if ($AdminToggles -contains $ToggleName -and -not $isAdmin) {
    Write-Error "ERROR: El ajuste '$ToggleName' requiere permisos de administrador para modificar politicas globales de HKLM."
    exit 1
}

$FullUsername = $null
try {
    $FullUsername = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
} catch {}

if ([string]::IsNullOrWhiteSpace($FullUsername)) {
    try {
        $FullUsername = (Get-Process -Name explorer -IncludeUserName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty UserName -First 1)
    } catch {}
}

if ([string]::IsNullOrWhiteSpace($FullUsername)) {
    $FullUsername = "$env:USERDOMAIN\$env:USERNAME"
}

$LeafUsername = $FullUsername
if ($FullUsername -match '\\(.+)$') { $LeafUsername = $Matches[1] }

$UserSID = ""
if (-not [string]::IsNullOrWhiteSpace($FullUsername)) {
    try {
        $NtAccount = New-Object System.Security.Principal.NTAccount($FullUsername)
        $UserSID = $NtAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
        try {
            $NtAccount = New-Object System.Security.Principal.NTAccount($LeafUsername)
            $UserSID = $NtAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
        } catch {
            try {
                $UserSID = (Get-CimInstance -ClassName Win32_UserAccount -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $LeafUsername }).SID
            } catch {}
        }
    }
}

if ([string]::IsNullOrWhiteSpace($UserSID)) {
    try {
        $Explorer = Get-CimInstance -ClassName Win32_Process -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($Explorer) {
            $Owner = Invoke-CimMethod -InputObject $Explorer -MethodName GetOwner -ErrorAction SilentlyContinue
            $NtAccount = if (-not [string]::IsNullOrWhiteSpace($Owner.Domain)) {
                New-Object System.Security.Principal.NTAccount($Owner.Domain, $Owner.User)
            } else {
                New-Object System.Security.Principal.NTAccount($Owner.User)
            }
            $UserSID = $NtAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
        }
    } catch {}
}

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
    } catch {}
}

$Targets = @()
if (-not [string]::IsNullOrWhiteSpace($UserSID)) { $Targets += "Registry::HKEY_USERS\$UserSID" }
$Targets += "HKCU:"

$NormalizedInput = $IsEnabledStr.ToLower().Replace("$", "").Trim()
$Value = if ($NormalizedInput -eq "true") { 1 } else { 0 }
$ToggleName = $ToggleName.Trim().Replace("'", "").Replace('"', "")

function Set-RegistryValue($subPath, $name, $type, $val) {
    foreach ($base in $Targets) {
        $fullPath = Join-Path $base $subPath
        if (!(Test-Path $fullPath)) { New-Item -Path $fullPath -Force | Out-Null }
        Set-ItemProperty -Path $fullPath -Name $name -Type $type -Value $val -Force | Out-Null
    }
}

function Remove-RegistryKey($subPath) {
    foreach ($base in $Targets) {
        $fullPath = Join-Path $base $subPath
        if (Test-Path $fullPath) { Remove-Item -Path $fullPath -Recurse -Force | Out-Null }
    }
}

$RequiresExplorerRestart = $false
$buildVer = [int](Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "CurrentBuildNumber" -ErrorAction SilentlyContinue)

switch ($ToggleName) {
    "darkMode" {
        $themeVal = if ($Value -eq 1) { 0 } else { 1 }
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize") -ValueName "AppsUseLightTheme" -BackupSubFolder "QoL\User"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize") -ValueName "SystemUsesLightTheme" -BackupSubFolder "QoL\User"
        }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" "DWord" $themeVal
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" "DWord" $themeVal
        $RequiresExplorerRestart = $true
    }
    "showExtensions" {
        $extVal = if ($Value -eq 1) { 0 } else { 1 }
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced") -ValueName "HideFileExt" -BackupSubFolder "QoL\User"
        }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" "DWord" $extVal
        $RequiresExplorerRestart = $true
    }
    "classicMenu" {
        if ($buildVer -lt 26000) {
            foreach ($base in $Targets) {
                Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Classes\CLSID\{e56a902a-a584-450e-9022-d7902bc4e017}") -ValueName "ClassicMenuBackup" -BackupSubFolder "QoL\User"
            }
            if ($Value -eq 1) {
                Set-RegistryValue "Software\Classes\CLSID\{e56a902a-a584-450e-9022-d7902bc4e017}\InprocServer32" "" "String" ""
            } else {
                Remove-RegistryKey "Software\Classes\CLSID\{e56a902a-a584-450e-9022-d7902bc4e017}"
            }
            $RequiresExplorerRestart = $true
        }
        else {
            $hasEP = Test-Path "$env:APPDATA\ExplorerPatcher\ep_setup.ini"
            $hasSAB = Test-Path "$env:APPDATA\StartAllBack\Config.cfg"
            if (-not $hasEP -and -not $hasSAB) {
                Write-Output "ADVERTENCIA: Para habilitar el menu clasico en compilaciones >= 26000 se requiere ExplorerPatcher o StartAllBack instalado."
            } else {
                if ($Value -eq 1) {
                    if ($hasEP) {
                        $epConfig = "$env:APPDATA\ExplorerPatcher\ep_setup.ini"
                        if (Test-Path $epConfig) {
                            $content = Get-Content $epConfig -Raw
                            $content = $content -replace 'ControlInterface=.*', 'ControlInterface=1'
                            Set-Content $epConfig -Value $content -Force
                            $RequiresExplorerRestart = $true
                        }
                    }
                } else {
                    if ($hasEP) {
                        $epConfig = "$env:APPDATA\ExplorerPatcher\ep_setup.ini"
                        if (Test-Path $epConfig) {
                            $content = Get-Content $epConfig -Raw
                            $content = $content -replace 'ControlInterface=.*', 'ControlInterface=0'
                            Set-Content $epConfig -Value $content -Force
                            $RequiresExplorerRestart = $true
                        }
                    }
                }
            }
        }
    }
    "disableBing" {
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Policies\Microsoft\Windows\Explorer") -ValueName "DisableSearchBoxSuggestions" -BackupSubFolder "QoL\User"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\Search") -ValueName "BingSearchEnabled" -BackupSubFolder "QoL\User"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\Search") -ValueName "CortanaConsent" -BackupSubFolder "QoL\User"
        }
        Set-RegistryValue "Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" "DWord" $Value
        $searchVal = if ($Value -eq 1) { 0 } else { 1 }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" "DWord" $searchVal
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent" "DWord" $searchVal
    }
    "disableLockScreen" {
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -ValueName "NoLockScreen" -BackupSubFolder "QoL\System"
        $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
        try {
            $OldEAP = $ErrorActionPreference
            $ErrorActionPreference = "Stop"
            if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
            Set-ItemProperty -Path $Path -Name "NoLockScreen" -Type DWord -Value $Value -Force | Out-Null
        } catch {
            Write-Error "[-] Error al escribir la directiva NoLockScreen en HKLM: $_"
            exit 1
        } finally {
            $ErrorActionPreference = $OldEAP
        }
    }
    "disableStickyKeys" {
        $stickyVal = if ($Value -eq 1) { "506" } else { "510" }
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Control Panel\Accessibility\StickyKeys") -ValueName "Flags" -BackupSubFolder "QoL\StickyKeys"
        }
        Set-RegistryValue "Control Panel\Accessibility\StickyKeys" "Flags" "String" $stickyVal
    }
    "cleanAltTab" {
        $altTabVal = if ($Value -eq 1) { 3 } else { 0 }
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced") -ValueName "MultiTaskingAltTabFilter" -BackupSubFolder "QoL\User"
        }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MultiTaskingAltTabFilter" "DWord" $altTabVal
    }
    "taskbarLeft" {
        $taskbarVal = if ($Value -eq 1) { 0 } else { 1 }
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced") -ValueName "TaskbarAl" -BackupSubFolder "QoL\User"
        }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" "DWord" $taskbarVal
    }
    "showHiddenFiles" {
        $hiddenVal = if ($Value -eq 1) { 1 } else { 2 }
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced") -ValueName "Hidden" -BackupSubFolder "QoL\User"
        }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" "DWord" $hiddenVal
        $RequiresExplorerRestart = $true
    }
    "launchToThisPC" {
        $launchVal = if ($Value -eq 1) { 1 } else { 2 }
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced") -ValueName "LaunchTo" -BackupSubFolder "QoL\User"
        }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" "DWord" $launchVal
    }
    "disableExplorerAds" {
        $adsVal = if ($Value -eq 1) { 0 } else { 1 }
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced") -ValueName "ShowSyncProviderNotifications" -BackupSubFolder "QoL\User"
        }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" "DWord" $adsVal
    }
    "disableScoobe" {
        $scoobeVal = if ($Value -eq 1) { 0 } else { 1 }
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement") -ValueName "ScoobeSystemSettingEnabled" -BackupSubFolder "QoL\User"
            $CDM = "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base $CDM) -ValueName "SubscribedContent-310093Enabled" -BackupSubFolder "QoL\User"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base $CDM) -ValueName "SubscribedContent-338387Enabled" -BackupSubFolder "QoL\User"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base $CDM) -ValueName "SubscribedContent-338388Enabled" -BackupSubFolder "QoL\User"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base $CDM) -ValueName "SubscribedContent-338389Enabled" -BackupSubFolder "QoL\User"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base $CDM) -ValueName "SubscribedContent-353696Enabled" -BackupSubFolder "QoL\User"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base $CDM) -ValueName "SubscribedContent-353694Enabled" -BackupSubFolder "QoL\User"
        }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" "DWord" $scoobeVal
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-310093Enabled" "DWord" $scoobeVal
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338387Enabled" "DWord" $scoobeVal
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled" "DWord" $scoobeVal
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" "DWord" $scoobeVal
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353696Enabled" "DWord" $scoobeVal
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353694Enabled" "DWord" $scoobeVal
    }
    "disableFilterKeys" {
        $CurrentFlags = $null
        foreach ($base in $Targets) {
            $fullPath = Join-Path $base "Control Panel\Accessibility\Keyboard Response"
            if (Test-Path $fullPath) {
                $CurrentFlags = (Get-ItemProperty -Path $fullPath -ErrorAction SilentlyContinue).Flags
                if ($null -ne $CurrentFlags) { break }
            }
        }
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Control Panel\Accessibility\Keyboard Response") -ValueName "Flags" -BackupSubFolder "QoL\FilterKeys"
        }
        if ($Value -eq 1) {
            if ($CurrentFlags -eq "59") {
                # Ya está optimizado y con teclas filtro desactivadas. No tocar para no romper latencia de periféricos.
            } else {
                Set-RegistryValue "Control Panel\Accessibility\Keyboard Response" "Flags" "String" "122"
            }
        } else {
            Set-RegistryValue "Control Panel\Accessibility\Keyboard Response" "Flags" "String" "126"
        }
    }
    "disableCopilot" {
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced") -ValueName "ShowCopilotButton" -BackupSubFolder "QoL\User"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Policies\Microsoft\Windows\WindowsCopilot") -ValueName "TurnOffWindowsCopilot" -BackupSubFolder "QoL\User"
        }
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -ValueName "TurnOffWindowsCopilot" -BackupSubFolder "QoL\System"
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" "DWord" $(if ($Value -eq 1) {0} else {1})
        Set-RegistryValue "Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" "DWord" $Value
        $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
        try {
            $OldEAP = $ErrorActionPreference
            $ErrorActionPreference = "Stop"
            if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
            Set-ItemProperty -Path $Path -Name "TurnOffWindowsCopilot" -Type DWord -Value $Value -Force | Out-Null
        } catch {
            Write-Error "[-] Error al desactivar Copilot en HKLM: $_"
            exit 1
        } finally {
            $ErrorActionPreference = $OldEAP
        }
        $RequiresExplorerRestart = $true
    }
    "disableRecall" {
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Policies\Microsoft\Windows\WindowsAI") -ValueName "TurnOffUserCameraCapture" -BackupSubFolder "QoL\User"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Policies\Microsoft\Windows\WindowsAI") -ValueName "DisableAIDataAnalysis" -BackupSubFolder "QoL\User"
        }
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -ValueName "TurnOffUserCameraCapture" -BackupSubFolder "QoL\System"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -ValueName "DisableAIDataAnalysis" -BackupSubFolder "QoL\System"
        Set-RegistryValue "Software\Policies\Microsoft\Windows\WindowsAI" "TurnOffUserCameraCapture" "DWord" $Value
        Set-RegistryValue "Software\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" "DWord" $Value
        $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        try {
            $OldEAP = $ErrorActionPreference
            $ErrorActionPreference = "Stop"
            if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
            Set-ItemProperty -Path $Path -Name "TurnOffUserCameraCapture" -Type DWord -Value $Value -Force | Out-Null
            Set-ItemProperty -Path $Path -Name "DisableAIDataAnalysis" -Type DWord -Value $Value -Force | Out-Null
        } catch {
            Write-Error "[-] Error al desactivar Recall en HKLM: $_"
            exit 1
        } finally {
            $ErrorActionPreference = $OldEAP
        }
    }
    "detailedBSoD" {
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -ValueName "DisplayParameters" -BackupSubFolder "QoL\System"
        $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
        try {
            $OldEAP = $ErrorActionPreference
            $ErrorActionPreference = "Stop"
            Set-ItemProperty -Path $Path -Name "DisplayParameters" -Type DWord -Value $Value -Force | Out-Null
        } catch {
            Write-Error "[-] Error al configurar DisplayParameters (BSoD detallada) en HKLM: $_"
            exit 1
        } finally {
            $ErrorActionPreference = $OldEAP
        }
    }
    "disableOneDrive" {
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -ValueName "DisableFileSyncNGSC" -BackupSubFolder "QoL\System"
        if ($Value -eq 1) {
            Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
            $Paths = @(
                "$env:LOCALAPPDATA\Microsoft\OneDrive\Update\OneDriveSetup.exe",
                "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDriveSetup.exe",
                "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
                "$env:SystemRoot\System32\OneDriveSetup.exe"
            )
            foreach ($Setup in $Paths) {
                if (Test-Path $Setup) {
                    Start-Process -FilePath $Setup -ArgumentList "/uninstall" -NoNewWindow -Wait -ErrorAction SilentlyContinue
                    break
                }
            }
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -ErrorAction SilentlyContinue
            $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
            try {
                $OldEAP = $ErrorActionPreference
                $ErrorActionPreference = "Stop"
                if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
                Set-ItemProperty -Path $Path -Name "DisableFileSyncNGSC" -Type DWord -Value 1 -Force | Out-Null
            } catch {
                Write-Error "[-] Error al desactivar OneDrive en HKLM: $_"
                exit 1
            } finally {
                $ErrorActionPreference = $OldEAP
            }
        } else {
            $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
            try {
                $OldEAP = $ErrorActionPreference
                $ErrorActionPreference = "Stop"
                if (Test-Path $Path) {
                    Remove-ItemProperty -Path $Path -Name "DisableFileSyncNGSC" -ErrorAction SilentlyContinue | Out-Null
                }
            } catch {
                Write-Error "[-] Error al habilitar OneDrive en HKLM: $_"
                exit 1
            } finally {
                $ErrorActionPreference = $OldEAP
            }
            Start-Process "ms-windows-store://pdp/?productid=9wzdncrfj1p3"
        }
    }
    "disableWidgets" {
        $widgetsVal = if ($Value -eq 1) { 0 } else { 1 }
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced") -ValueName "TaskbarMn" -BackupSubFolder "QoL\User"
        }
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Dsh" -ValueName "AllowNewsAndInterests" -BackupSubFolder "QoL\System"
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" "DWord" $widgetsVal
        $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Dsh"
        try {
            $OldEAP = $ErrorActionPreference
            $ErrorActionPreference = "Stop"
            if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
            Set-ItemProperty -Path $Path -Name "AllowNewsAndInterests" -Type DWord -Value $widgetsVal -Force | Out-Null
        } catch {
            Write-Error "[-] Error al desactivar Widgets en HKLM: $_"
            exit 1
        } finally {
            $ErrorActionPreference = $OldEAP
        }
        $RequiresExplorerRestart = $true
    } 
    "zeroStartupDelay" {
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize") -ValueName "StartupDelayInMSec" -BackupSubFolder "QoL\User"
        }
        if ($Value -eq 1) {
            Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" "DWord" 0
        } else {
            Remove-RegistryKey "Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
        }
    }
    "enableGameMode" {
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\GameBar") -ValueName "AllowAutoGameMode" -BackupSubFolder "QoL\User"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\GameBar") -ValueName "AutoGameModeEnabled" -BackupSubFolder "QoL\User"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\GameDVR") -ValueName "AppCaptureEnabled" -BackupSubFolder "QoL\User"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\GameDVR") -ValueName "AudioCaptureEnabled" -BackupSubFolder "QoL\User"
        }
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR" -ValueName "value" -BackupSubFolder "QoL\System"
        Set-RegistryValue "Software\Microsoft\GameBar" "AllowAutoGameMode" "DWord" $Value
        Set-RegistryValue "Software\Microsoft\GameBar" "AutoGameModeEnabled" "DWord" $Value
        
        $dvrVal = if ($Value -eq 1) { 0 } else { 1 }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" "DWord" $dvrVal
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\GameDVR" "AudioCaptureEnabled" "DWord" $dvrVal
        
        $policyPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR"
        try {
            $OldEAP = $ErrorActionPreference
            $ErrorActionPreference = "Stop"
            if (Test-Path $policyPath) {
                Set-ItemProperty -Path $policyPath -Name "value" -Type DWord -Value $dvrVal -Force | Out-Null
            }
        } catch {
            Write-Warning "[-] No se pudo modificar AllowGameDVR en HKLM: $_"
        } finally {
            $ErrorActionPreference = $OldEAP
        }
    }
    "barebonesVisual" {
        $visualVal = if ($Value -eq 1) { "0" } else { "1" }
        foreach ($base in $Targets) {
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Control Panel\Desktop\WindowMetrics") -ValueName "MinAnimate" -BackupSubFolder "QoL\Visuals"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects") -ValueName "VisualFXSetting" -BackupSubFolder "QoL\Visuals"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Control Panel\Desktop") -ValueName "UserPreferencesMask" -BackupSubFolder "QoL\Visuals"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Control Panel\Desktop") -ValueName "FontSmoothing" -BackupSubFolder "QoL\Visuals"
            Backup-OverlordRegistryValue -TargetKey (Join-Path $base "Control Panel\Desktop") -ValueName "FontSmoothingType" -BackupSubFolder "QoL\Visuals"
        }
        Set-RegistryValue "Control Panel\Desktop\WindowMetrics" "MinAnimate" "String" $visualVal
        
        if ($Value -eq 1) {
            Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" "DWord" 2
            $mask = [byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)
            Set-RegistryValue "Control Panel\Desktop" "UserPreferencesMask" "Binary" $mask
            Set-RegistryValue "Control Panel\Desktop" "FontSmoothing" "String" "2"
            Set-RegistryValue "Control Panel\Desktop" "FontSmoothingType" "DWord" 2
        } else {
            Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" "DWord" 0
            $mask = [byte[]](0x9E,0x3E,0x07,0x80,0x12,0x00,0x00,0x00)
            Set-RegistryValue "Control Panel\Desktop" "UserPreferencesMask" "Binary" $mask
            Set-RegistryValue "Control Panel\Desktop" "FontSmoothing" "String" "2"
            Set-RegistryValue "Control Panel\Desktop" "FontSmoothingType" "DWord" 2
        }
        $RequiresExplorerRestart = $true
    }
    default {
        Write-Error "ERROR: Toggle desconocido: $ToggleName"
        exit 1
    }
}

if ($RequiresExplorerRestart) {
    Write-Output "OK: $ToggleName establecido a $($Value -eq 1) (REQUIRES_EXPLORER_RESTART)"
} else {
    if (-not ([System.Management.Automation.PSTypeName]'Win32.User32').Type) {
        Add-Type -MemberDefinition @'
[DllImport("user32.dll", EntryPoint = "SendMessageTimeoutA")]
public static extern System.IntPtr SendMessageTimeout(System.IntPtr hWnd, uint Msg, System.IntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out System.IntPtr lpdwResult);
'@ -Name "User32" -Namespace "Win32" -ErrorAction SilentlyContinue | Out-Null
    }
    $result = [IntPtr]::Zero
    try {
        [Win32.User32]::SendMessageTimeout([IntPtr]0xffff, 0x001a, [IntPtr]::Zero, "Environment", 2, 5000, [ref] $result) | Out-Null
    } catch {}
    Write-Output "OK: $ToggleName establecido a $($Value -eq 1)"
}
exit 0

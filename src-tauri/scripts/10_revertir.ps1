param(
    [bool]$IsLaptop = $false,
    [int]$RamGB = 8
)
$ErrorActionPreference = "Continue"



function Invoke-OverlordSafeRestore {
    param(
        [string]$TargetKey,
        [string]$ValueName,
        [string]$BackupSubFolder
    )
    if ($TargetKey -match "^HKCU:") {
        $HKCU_RestorePath = if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" }
        $TargetKey = $TargetKey -replace '^HKCU:', $HKCU_RestorePath
    }
    
    $BackupKey = "HKLM:\SOFTWARE\Overlord\Backup\$BackupSubFolder"
    if (Test-Path $BackupKey) {
        $BckVal = Get-SafeRegistryValue -Path $BackupKey -Name $ValueName
        if ($null -ne $BckVal) {
            if (Get-Command Restore-OverlordRegistryValue -ErrorAction SilentlyContinue) {
                Restore-OverlordRegistryValue -TargetKey $TargetKey -ValueName $ValueName -BackupSubFolder $BackupSubFolder | Out-Null
            }
        }
    }
}

Try {
    $HKCU_Path = if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" }
    Write-Host "[*] Iniciando reversion simetrica de Overlord con helpers globales..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup"
    $MsiBackupKey = "$BackupPath\MSI"
    $NetBackupKey = "$BackupPath\CPU\NetworkAffinity"
    $GameHooksBackup = "$BackupPath\GameHooks"

    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -ValueName "Win32PrioritySeparation" -BackupSubFolder "Performance" -DefaultValue 2

    $MousePath = "$HKCU_Path\Control Panel\Mouse"
    Invoke-OverlordSafeRestore -TargetKey $MousePath -ValueName "MouseSpeed" -BackupSubFolder "Mouse" -DefaultValue "1" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey $MousePath -ValueName "MouseThreshold1" -BackupSubFolder "Mouse" -DefaultValue "6" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey $MousePath -ValueName "MouseThreshold2" -BackupSubFolder "Mouse" -DefaultValue "10" -DefaultType "String"


    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\StickyKeys" -ValueName "Flags" -BackupSubFolder "Accessibility" -DefaultValue "510" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\ToggleKeys" -ValueName "Flags" -BackupSubFolder "Accessibility" -DefaultValue "62"  -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "Flags" -BackupSubFolder "Accessibility" -DefaultValue "126" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "AutoRepeatDelay" -BackupSubFolder "Accessibility" -DefaultValue "1000" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "AutoRepeatRate" -BackupSubFolder "Accessibility" -DefaultValue "500" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "DelayBeforeAcceptance" -BackupSubFolder "Accessibility" -DefaultValue "1000" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "BounceTime" -BackupSubFolder "Accessibility" -DefaultValue "0" -DefaultType "String"

    $pciKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Enum\PCI", $false)
    if ($pciKey) {
        foreach ($venId in $pciKey.GetSubKeyNames()) {
            $venKey = $pciKey.OpenSubKey($venId, $false)
            if ($venKey) {
                foreach ($devId in $venKey.GetSubKeyNames()) {
                    $devKey = $venKey.OpenSubKey($devId, $false)
                    if ($devKey) {
                        $classGuid = $devKey.GetValue("ClassGUID")
                        $deviceRegID = "PCI_${venId}_${devId}_Device Parameters"
                        $paramPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\$venId\$devId\Device Parameters"

                        if ($classGuid -eq "{4d36e968-e325-11ce-bfc1-08002be10318}" -or $classGuid -eq "{36fc9e60-c465-11cf-8056-444553540000}" -or $classGuid -eq "{4d36e97c-e325-11ce-bfc1-08002be10318}" -or $classGuid -eq "{c166523b-fe0c-4a94-a586-f1a8096b7efe}") {
                            try {
                                if (Test-Path $MsiBackupKey) {
                                    $msiProps = Get-ItemProperty -Path $MsiBackupKey -ErrorAction SilentlyContinue
                                    $savedMsi = if ($null -ne $msiProps -and $null -ne $msiProps.PSObject.Properties[$deviceRegID]) { $msiProps.$deviceRegID } else { $null }
                                    if ($null -ne $savedMsi) {
                                        $MsiSubKey = "$paramPath\Interrupt Management\MessageSignaledInterruptProperties"
                                        if ($savedMsi -eq '_ABSENT_') {
                                            if (Test-Path $MsiSubKey) { Remove-ItemProperty -Path $MsiSubKey -Name "MSISupported" -ErrorAction SilentlyContinue | Out-Null }
                                        } else {
                                            if (!(Test-Path $MsiSubKey)) { New-Item -Path $MsiSubKey -Force | Out-Null }
                                            Set-ItemProperty -Path $MsiSubKey -Name "MSISupported" -Type DWord -Value $savedMsi -Force | Out-Null
                                        }
                                    }
                                    
                                    # Revertir prioridad de interrupcion
                                    $priorityRegID = "PCI_${venId}_${devId}_DevicePriority"
                                    $savedPriority = if ($null -ne $msiProps -and $null -ne $msiProps.PSObject.Properties[$priorityRegID]) { $msiProps.$priorityRegID } else { $null }
                                    if ($null -ne $savedPriority) {
                                        $AffinitySubKey = "$paramPath\Interrupt Management\Affinity Policy"
                                        if ($savedPriority -eq '_ABSENT_') {
                                            if (Test-Path $AffinitySubKey) { Remove-ItemProperty -Path $AffinitySubKey -Name "DevicePriority" -ErrorAction SilentlyContinue | Out-Null }
                                        } else {
                                            if (!(Test-Path $AffinitySubKey)) { New-Item -Path $AffinitySubKey -Force | Out-Null }
                                            Set-ItemProperty -Path $AffinitySubKey -Name "DevicePriority" -Type DWord -Value $savedPriority -Force | Out-Null
                                        }
                                    }
                                }
                            } catch {
                                Write-Error "No se pudieron revertir los parametros MSI para el dispositivo ${deviceRegID}: $_"
                            }
                        }

                        if ($classGuid -eq "{4d36e972-e325-11ce-bfc1-08002be10318}") { # Net
                            try {
                                if (Test-Path $NetBackupKey) {
                                    $netProps = Get-ItemProperty -Path $NetBackupKey -ErrorAction SilentlyContinue
                                    $savedPolicy   = if ($null -ne $netProps -and $null -ne $netProps.PSObject.Properties["${deviceRegID}_Policy"]) { $netProps."${deviceRegID}_Policy" } else { $null }
                                    $savedOverride = if ($null -ne $netProps -and $null -ne $netProps.PSObject.Properties["${deviceRegID}_Override"]) { $netProps."${deviceRegID}_Override" } else { $null }

                                    if ($null -ne $savedPolicy) {
                                        $affinityPath = "$paramPath\Interrupt Management\Affinity Policy"
                                        if ($savedPolicy -eq '_ABSENT_') {
                                            if (Test-Path $affinityPath) {
                                                Remove-ItemProperty -Path $affinityPath -Name "DevicePolicy" -ErrorAction SilentlyContinue | Out-Null
                                                Remove-ItemProperty -Path $affinityPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue | Out-Null
                                            }
                                        } else {
                                            if (!(Test-Path $affinityPath)) { New-Item -Path $affinityPath -Force | Out-Null }
                                            Set-ItemProperty -Path $affinityPath -Name "DevicePolicy" -Type DWord -Value $savedPolicy -Force | Out-Null
                                            if ($null -ne $savedOverride -and $savedOverride -ne '_ABSENT_') {
                                                Set-ItemProperty -Path $affinityPath -Name "AssignmentSetOverride" -Type Binary -Value $savedOverride -Force | Out-Null
                                            } else {
                                                Remove-ItemProperty -Path $affinityPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue | Out-Null
                                            }
                                        }
                                    }
                                }
                            } catch {
                                Write-Error "No se pudieron revertir los parametros de Afinidad de Red para el dispositivo ${deviceRegID}: $_"
                            }
                        }
                        $devKey.Close()
                    }
                }
                $venKey.Close()
            }
        }
        $pciKey.Close()
    }

    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ValueName "AllowTelemetry" -BackupSubFolder "Telemetry" -DefaultValue 3
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -ValueName "Disabled" -BackupSubFolder "Telemetry" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "BingSearchEnabled" -BackupSubFolder "Telemetry" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "CortanaConsent" -BackupSubFolder "Telemetry" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -ValueName "GlobalUserDisabled" -BackupSubFolder "Telemetry" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -ValueName "StartupBoostEnabled" -BackupSubFolder "Telemetry" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -ValueName "BackgroundModeEnabled" -BackupSubFolder "Telemetry" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -ValueName "TurnOffWindowsCopilot" -BackupSubFolder "Telemetry" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -ValueName "TurnOffWindowsCopilot" -BackupSubFolder "Telemetry" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -ValueName "TurnOffUserCameraCapture" -BackupSubFolder "Telemetry" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -ValueName "DisableAIDataAnalysis" -BackupSubFolder "Telemetry" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -ValueName "AllowRecallEnablement" -BackupSubFolder "Telemetry" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ValueName "NoAutoRebootWithLoggedOnUsers" -BackupSubFolder "Telemetry" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -ValueName "TurnOffUserCameraCapture" -BackupSubFolder "Telemetry" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -ValueName "DisableAIDataAnalysis" -BackupSubFolder "Telemetry" -DefaultValue 0

    # --- Reversion de Modulo de Personalizacion y QoL ---
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ValueName "AppsUseLightTheme" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ValueName "SystemUsesLightTheme" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "HideFileExt" -BackupSubFolder "QoL\User" -DefaultValue 1

    $ClassicMenuBck = Get-SafeRegistryValue -Path "HKLM:\SOFTWARE\Overlord\Backup\QoL\User" -Name "ClassicMenuBackup"
    if ($ClassicMenuBck -eq '_ABSENT_') {
        Remove-Item -Path "$HKCU_Path\Software\Classes\CLSID\{e56a902a-a584-450e-9022-d7902bc4e017}" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    } else {
        Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Classes\CLSID\{e56a902a-a584-450e-9022-d7902bc4e017}" -ValueName "ClassicMenuBackup" -BackupSubFolder "QoL\User" -DefaultValue '_ABSENT_'
    }

    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -ValueName "DisableSearchBoxSuggestions" -BackupSubFolder "QoL\User" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "BingSearchEnabled" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "CortanaConsent" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -ValueName "NoLockScreen" -BackupSubFolder "QoL\System" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\StickyKeys" -ValueName "Flags" -BackupSubFolder "QoL\StickyKeys" -DefaultValue "510" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "MultiTaskingAltTabFilter" -BackupSubFolder "QoL\User" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "TaskbarAl" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "Hidden" -BackupSubFolder "QoL\User" -DefaultValue 2
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "LaunchTo" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "ShowSyncProviderNotifications" -BackupSubFolder "QoL\User" -DefaultValue 1

    $EngagementPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
    Invoke-OverlordSafeRestore -TargetKey $EngagementPath -ValueName "ScoobeSystemSettingEnabled" -BackupSubFolder "QoL\User" -DefaultValue 1
    
    $CdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Invoke-OverlordSafeRestore -TargetKey $CdmPath -ValueName "SubscribedContent-310093Enabled" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey $CdmPath -ValueName "SubscribedContent-338387Enabled" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey $CdmPath -ValueName "SubscribedContent-338388Enabled" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey $CdmPath -ValueName "SubscribedContent-338389Enabled" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey $CdmPath -ValueName "SubscribedContent-353696Enabled" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey $CdmPath -ValueName "SubscribedContent-353694Enabled" -BackupSubFolder "QoL\User" -DefaultValue 1


    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "ShowCopilotButton" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -ValueName "TurnOffWindowsCopilot" -BackupSubFolder "QoL\User" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -ValueName "TurnOffWindowsCopilot" -BackupSubFolder "QoL\System" -DefaultValue 0

    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -ValueName "TurnOffUserCameraCapture" -BackupSubFolder "QoL\User" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -ValueName "DisableAIDataAnalysis" -BackupSubFolder "QoL\User" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -ValueName "TurnOffUserCameraCapture" -BackupSubFolder "QoL\System" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -ValueName "DisableAIDataAnalysis" -BackupSubFolder "QoL\System" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -ValueName "AllowRecallEnablement" -BackupSubFolder "QoL\System" -DefaultValue 0

    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -ValueName "DisplayParameters" -BackupSubFolder "QoL\System" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -ValueName "DisableFileSyncNGSC" -BackupSubFolder "QoL\System" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "TaskbarMn" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Dsh" -ValueName "AllowNewsAndInterests" -BackupSubFolder "QoL\System" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" -ValueName "StartupDelayInMSec" -BackupSubFolder "QoL\User" -DefaultValue '_ABSENT_'

    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\GameBar" -ValueName "AllowAutoGameMode" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\GameBar" -ValueName "AutoGameModeEnabled" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -ValueName "AppCaptureEnabled" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -ValueName "AudioCaptureEnabled" -BackupSubFolder "QoL\User" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR" -ValueName "value" -BackupSubFolder "QoL\System" -DefaultValue 1

    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Desktop\WindowMetrics" -ValueName "MinAnimate" -BackupSubFolder "QoL\Visuals" -DefaultValue "1" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -ValueName "VisualFXSetting" -BackupSubFolder "QoL\Visuals" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Desktop" -ValueName "UserPreferencesMask" -BackupSubFolder "QoL\Visuals" -DefaultValue '_ABSENT_' -DefaultType "Binary"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Desktop" -ValueName "FontSmoothing" -BackupSubFolder "QoL\Visuals" -DefaultValue "2" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Desktop" -ValueName "FontSmoothingType" -BackupSubFolder "QoL\Visuals" -DefaultValue 2

    $StartTypeMap = @{ 2 = "Automatic"; 3 = "Manual"; 4 = "Disabled" }
    $ServicesFallback = @{
        "DiagTrack"        = "Automatic"
        "dmwappushservice" = "Manual"
        "Fax"              = "Manual"
        "RetailDemo"       = "Disabled"
        "MapsBroker"       = "Automatic"
        "PhoneSvc"         = "Manual"
        "AJRouter"         = "Manual"
        "WpcMonSvc"        = "Manual"
        "SensorService"    = "Manual"
        "TrkWks"           = "Automatic"
        "RemoteRegistry"   = "Disabled"
        "WdiServiceHost"   = "Manual"
        "WdiSystemHost"    = "Manual"
        "WerSvc"           = "Manual"
        "wuauserv"         = "Manual"
    }
    try {
        foreach ($Svc in $ServicesFallback.Keys) {
            $SavedStart = $null
            $HasBackup = $false
            $WasRunning = $null
            $SvcBackupPath = "$BackupPath\Services\$Svc"
            if (Test-Path $SvcBackupPath) {
                $SavedStart = Get-SafeRegistryValue -Path $SvcBackupPath -Name "Start"
                $WasRunning = Get-SafeRegistryValue -Path $SvcBackupPath -Name "WasRunning"
                if ($null -ne $SavedStart) {
                    $HasBackup = $true
                }
            }
            if ($HasBackup) {
                $StartType = if ($null -ne $SavedStart -and $SavedStart -notmatch '_ABSENT_') { $StartTypeMap[[int]$SavedStart] } else { $ServicesFallback[$Svc] }
                if ($StartType) {
                    Set-Service -Name $Svc -StartupType $StartType -ErrorAction SilentlyContinue | Out-Null
                    
                    if ($null -ne $WasRunning) {
                        if ($WasRunning -eq 1 -and $StartType -ne "Disabled") {
                            Start-Service -Name $Svc -ErrorAction SilentlyContinue | Out-Null
                        } elseif ($WasRunning -eq 0) {
                            Stop-Service -Name $Svc -Force -ErrorAction SilentlyContinue | Out-Null
                        }
                    } else {
                        if ($StartType -ne "Disabled" -and $StartType -ne "Manual") {
                            Start-Service -Name $Svc -ErrorAction SilentlyContinue | Out-Null
                        }
                    }
                }
            }
        }
    } catch {
        Write-Error "No se pudo restaurar el estado de los servicios: $_"
    }

    try {
        Get-NetFirewallRule -DisplayName "Overlord_Block_*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue | Out-Null
    } catch {
        Write-Error "No se pudieron remover las reglas del Firewall de Windows: $_"
    }

    $Tasks = @(
        "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "Microsoft\Windows\Autochk\Proxy",
        "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "Microsoft\Windows\Application Experience\StartupAppTask",
        "Microsoft\Windows\Device Information\Device",
        "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "Microsoft\Windows\Feedback\Siuf\DmClient",
        "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
        "Microsoft\Windows\Windows Error Reporting\QueueReporting",
        "Microsoft\Windows\DiskFootprint\Diagnostics",
        "Microsoft\Windows\Maps\MapsToastTask",
        "Microsoft\Windows\Maps\MapsUpdateTask",
        "Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
        "Microsoft\Windows\Shell\FamilySafetyMonitor",
        "Microsoft\Windows\Shell\FamilySafetyRefreshTask"
    )
    $TasksBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Tasks"
    if (Test-Path $TasksBackupPath) {
        $props = Get-ItemProperty -Path $TasksBackupPath -ErrorAction SilentlyContinue
        foreach ($Task in $Tasks) {
            $TPath = "\" + (Split-Path $Task -Parent)
            $TName = Split-Path $Task -Leaf
            $TaskKeyName = $Task -replace '\\', '_'
            
            $WasEnabled = 1 # Por defecto habilitada si no hay backup (comportamiento seguro de stock)
            $SavedState = if ($null -ne $props -and $null -ne $props.PSObject.Properties[$TaskKeyName]) { $props.PSObject.Properties[$TaskKeyName].Value } else { $null }
            if ($null -ne $SavedState) {
                $WasEnabled = $SavedState
            }
            
            if ($WasEnabled -eq 1) {
                Enable-ScheduledTask -TaskPath $TPath -TaskName $TName -ErrorAction SilentlyContinue | Out-Null
            } else {
                Disable-ScheduledTask -TaskPath $TPath -TaskName $TName -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }

    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ValueName "NetworkThrottlingIndex" -BackupSubFolder "Network" -DefaultValue 10
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ValueName "SystemResponsiveness" -BackupSubFolder "Network" -DefaultValue 20
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -ValueName "InitialRto" -BackupSubFolder "Network" -DefaultValue 3000
    
    $GamesPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    if (Test-Path $GamesPath) {
        Invoke-OverlordSafeRestore -TargetKey $GamesPath -ValueName "Scheduling Category" -BackupSubFolder "Performance" -DefaultValue "Medium" -DefaultType "String"
        Invoke-OverlordSafeRestore -TargetKey $GamesPath -ValueName "SFIO Priority" -BackupSubFolder "Performance" -DefaultValue "Normal" -DefaultType "String"
        Invoke-OverlordSafeRestore -TargetKey $GamesPath -ValueName "Priority" -BackupSubFolder "Performance" -DefaultValue 2 -DefaultType "DWord"
        Invoke-OverlordSafeRestore -TargetKey $GamesPath -ValueName "GPU Priority" -BackupSubFolder "Performance" -DefaultValue 8 -DefaultType "DWord"
        Invoke-OverlordSafeRestore -TargetKey $GamesPath -ValueName "Clock Rate" -BackupSubFolder "Performance" -DefaultValue 10 -DefaultType "DWord"
    }

    # Revertir configuraciones especificas de interfaces de red
    $InterfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    if (Test-Path $InterfacesPath) {
        $InterfaceKeys = Get-ChildItem -Path $InterfacesPath -ErrorAction SilentlyContinue
        foreach ($Key in $InterfaceKeys) {
            if (Get-Command Restore-OverlordRegistryValue -ErrorAction SilentlyContinue) {
                Restore-OverlordRegistryValue -TargetKey $Key.PSPath -ValueName "TcpAckFrequency" -BackupSubFolder "Network\Interfaces\$($Key.PSChildName)" | Out-Null
                Restore-OverlordRegistryValue -TargetKey $Key.PSPath -ValueName "TcpNoDelay" -BackupSubFolder "Network\Interfaces\$($Key.PSChildName)" | Out-Null
            }
        }
    }

    # Revertir ahorros de energia en adaptadores de red advanced
    $NetClassPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
    if (Test-Path $NetClassPath) {
        $NetAdapters = Get-ChildItem -Path $NetClassPath -ErrorAction SilentlyContinue
        foreach ($Adapter in $NetAdapters) {
            if ($Adapter.PSChildName -match "^\d{4}$") {
                $PowerKeys = @("*EEE", "EEE", "*GreenEnergy", "GreenEnergy", "*EEELinkAdvertisement", "EEELinkAdvertisement", "*EnergyEfficientEthernet", "EnergyEfficientEthernet", "*PacketCoalescing", "PacketCoalescing", "*InterruptModeration", "InterruptModeration", "*FlowControl", "FlowControl", "PnPCapabilities")
                foreach ($PKey in $PowerKeys) {
                    if (Get-Command Restore-OverlordRegistryValue -ErrorAction SilentlyContinue) {
                        Restore-OverlordRegistryValue -TargetKey $Adapter.PSPath -ValueName $PKey -BackupSubFolder "Network\Adapters\$($Adapter.PSChildName)" | Out-Null
                    }
                }
            }
        }
    }

    $NetAdapters = Get-NetAdapter -ErrorAction SilentlyContinue
    if ($null -ne $NetAdapters) {
        foreach ($Adapter in $NetAdapters) {
            $AdapterBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Network\Adapters_State\$($Adapter.InterfaceGuid)"
            if (Test-Path $AdapterBackupPath) {
                $props = Get-ItemProperty -Path $AdapterBackupPath -ErrorAction SilentlyContinue
                if ($null -ne $props) {
                    if ($null -ne $props.PSObject.Properties["AllowComputerToTurnOffDevice"]) {
                        $Val = $props.AllowComputerToTurnOffDevice
                        if ($Val -eq 1) { Set-NetAdapterPowerManagement -Name $Adapter.Name -AllowComputerToTurnOffDevice Enabled -ErrorAction SilentlyContinue | Out-Null }
                        else { Set-NetAdapterPowerManagement -Name $Adapter.Name -AllowComputerToTurnOffDevice Disabled -ErrorAction SilentlyContinue | Out-Null }
                        Remove-ItemProperty -Path $AdapterBackupPath -Name "AllowComputerToTurnOffDevice" -ErrorAction SilentlyContinue | Out-Null
                    }
                    if ($null -ne $props.PSObject.Properties["InterruptModerationVal"]) {
                        $Val = $props.InterruptModerationVal
                        Set-NetAdapterAdvancedProperty -Name $Adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue $Val -ErrorAction SilentlyContinue | Out-Null
                        Remove-ItemProperty -Path $AdapterBackupPath -Name "InterruptModerationVal" -ErrorAction SilentlyContinue | Out-Null
                    }
                }
            }
        }
    }

    $NetworkBackupRoot = "$BackupPath\Network"
    if (Test-Path $NetworkBackupRoot) {
        if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
            $Adapters = Get-NetAdapter -ErrorAction SilentlyContinue
            foreach ($Adapter in $Adapters) {
                if ($Adapter.Status -eq "Up" -or $Adapter.HardwareInterface -eq $true) {
                    try {
                        $AdapterBackupPath = "$BackupPath\Network\Adapters_State\$($Adapter.InterfaceGuid)"
                        if (!(Test-Path $AdapterBackupPath)) {
                            $AdapterBackupPath = "$BackupPath\Network\Adapters_State\$($Adapter.Name)"
                        }
                        $HasAdapterBackup = Test-Path $AdapterBackupPath
                        
                        if ($HasAdapterBackup) {
                            $LsoIPv4 = Get-SafeRegistryValue -Path $AdapterBackupPath -Name "LsoIPv4"
                            $LsoIPv6 = Get-SafeRegistryValue -Path $AdapterBackupPath -Name "LsoIPv6"
                            if ($null -ne $LsoIPv4) {
                                if ($LsoIPv4 -eq 1) {
                                    Enable-NetAdapterLso -Name $Adapter.Name -IPv4 -ErrorAction SilentlyContinue | Out-Null
                                } else {
                                    Disable-NetAdapterLso -Name $Adapter.Name -IPv4 -ErrorAction SilentlyContinue | Out-Null
                                }
                            }
                            if ($null -ne $LsoIPv6) {
                                if ($LsoIPv6 -eq 1) {
                                    Enable-NetAdapterLso -Name $Adapter.Name -IPv6 -ErrorAction SilentlyContinue | Out-Null
                                } else {
                                    Disable-NetAdapterLso -Name $Adapter.Name -IPv6 -ErrorAction SilentlyContinue | Out-Null
                                }
                            }

                            $RscIPv4 = Get-SafeRegistryValue -Path $AdapterBackupPath -Name "RscIPv4"
                            $RscIPv6 = Get-SafeRegistryValue -Path $AdapterBackupPath -Name "RscIPv6"
                            if ($null -ne $RscIPv4) {
                                if ($RscIPv4 -eq 1) {
                                    Enable-NetAdapterRsc -Name $Adapter.Name -IPv4 -ErrorAction SilentlyContinue | Out-Null
                                } else {
                                    Disable-NetAdapterRsc -Name $Adapter.Name -IPv4 -ErrorAction SilentlyContinue | Out-Null
                                }
                            }
                            if ($null -ne $RscIPv6) {
                                if ($RscIPv6 -eq 1) {
                                    Enable-NetAdapterRsc -Name $Adapter.Name -IPv6 -ErrorAction SilentlyContinue | Out-Null
                                } else {
                                    Disable-NetAdapterRsc -Name $Adapter.Name -IPv6 -ErrorAction SilentlyContinue | Out-Null
                                }
                            }

                            $RssProfile = Get-SafeRegistryValue -Path $AdapterBackupPath -Name "RssProfile"
                            $RssEnabled = Get-SafeRegistryValue -Path $AdapterBackupPath -Name "RssEnabled"
                            if ($null -ne $RssProfile) {
                                Set-NetAdapterRss -Name $Adapter.Name -Profile $RssProfile -ErrorAction SilentlyContinue | Out-Null
                            }
                            if ($null -ne $RssEnabled) {
                                if ($RssEnabled -eq 1) {
                                    Enable-NetAdapterRss -Name $Adapter.Name -ErrorAction SilentlyContinue | Out-Null
                                } else {
                                    Disable-NetAdapterRss -Name $Adapter.Name -ErrorAction SilentlyContinue | Out-Null
                                }
                            }

                            $ChkIpIPv4 = Get-SafeRegistryValue -Path $AdapterBackupPath -Name "ChecksumIpIPv4"
                            $ChkTcpIPv4 = Get-SafeRegistryValue -Path $AdapterBackupPath -Name "ChecksumTcpIPv4"
                            $ChkTcpIPv6 = Get-SafeRegistryValue -Path $AdapterBackupPath -Name "ChecksumTcpIPv6"
                            $ChkUdpIPv4 = Get-SafeRegistryValue -Path $AdapterBackupPath -Name "ChecksumUdpIPv4"
                            $ChkUdpIPv6 = Get-SafeRegistryValue -Path $AdapterBackupPath -Name "ChecksumUdpIPv6"
                            $ChkOffload = Get-SafeRegistryValue -Path $AdapterBackupPath -Name "ChecksumOffload"

                            $splat = @{}
                            if ($null -ne $ChkIpIPv4) { $splat["IpIPv4Enabled"] = $ChkIpIPv4 }
                            if ($null -ne $ChkTcpIPv4) { $splat["TcpIPv4Enabled"] = $ChkTcpIPv4 }
                            if ($null -ne $ChkTcpIPv6) { $splat["TcpIPv6Enabled"] = $ChkTcpIPv6 }
                            if ($null -ne $ChkUdpIPv4) { $splat["UdpIPv4Enabled"] = $ChkUdpIPv4 }
                            if ($null -ne $ChkUdpIPv6) { $splat["UdpIPv6Enabled"] = $ChkUdpIPv6 }

                            if ($splat.Count -gt 0) {
                                Set-NetAdapterChecksumOffload -Name $Adapter.Name @splat -ErrorAction SilentlyContinue | Out-Null
                            } elseif ($null -ne $ChkOffload) {
                                # Fallback para compatibilidad con backups antiguos (tipo DWord)
                                if ($ChkOffload -eq 1) {
                                    Enable-NetAdapterChecksumOffload -Name $Adapter.Name -ErrorAction SilentlyContinue | Out-Null
                                } else {
                                    Disable-NetAdapterChecksumOffload -Name $Adapter.Name -ErrorAction SilentlyContinue | Out-Null
                                }
                            }
                        } else {
                            Enable-NetAdapterLso -Name $Adapter.Name -IPv4 -IPv6 -ErrorAction SilentlyContinue | Out-Null
                            Enable-NetAdapterRsc -Name $Adapter.Name -IPv4 -IPv6 -ErrorAction SilentlyContinue | Out-Null
                            Set-NetAdapterRss -Name $Adapter.Name -Profile Closest -ErrorAction SilentlyContinue | Out-Null
                        }
                    } catch {
                        Write-Error "No se pudo restaurar la configuracion del adaptador de red $($Adapter.Name): $_"
                    }
                }
            }
        }
    }

    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    $ControlPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
    Invoke-OverlordSafeRestore -TargetKey $MemPath -ValueName "FeatureSettingsOverride" -BackupSubFolder "Performance" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey $MemPath -ValueName "FeatureSettingsOverrideMask" -BackupSubFolder "Performance" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\System\GameConfigStore" -ValueName "GameDVR_Enabled" -BackupSubFolder "Performance" -DefaultValue 1
    
    try {
        if (Get-Command Get-MMAgent -ErrorAction SilentlyContinue) {
            $PerfBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Performance"
            $HasPerfBackup = Test-Path $PerfBackupPath
            
            $SavedMC = Get-SafeRegistryValue -Path $PerfBackupPath -Name "MemoryCompression"
            $SavedPC = Get-SafeRegistryValue -Path $PerfBackupPath -Name "PageCombining"
            
            if ($null -ne $SavedMC) {
                if ($SavedMC -eq 1) { Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null } else { Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null }
            } else {
                Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
            }
            
            if ($null -ne $SavedPC) {
                if ($SavedPC -eq 1) { Enable-MMAgent -PageCombining -ErrorAction SilentlyContinue | Out-Null } else { Disable-MMAgent -PageCombining -ErrorAction SilentlyContinue | Out-Null }
            } else {
                Enable-MMAgent -PageCombining -ErrorAction SilentlyContinue | Out-Null
            }
        }
    } catch {
        Write-Error "No se pudo restaurar MMAgent: $_"
    }

    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ValueName "HwSchMode" -BackupSubFolder "GPU" -DefaultValue 2
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ValueName "EnableTransparency" -BackupSubFolder "GPU" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -ValueName "AllowGameDVR" -BackupSubFolder "GPU" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -ValueName "AppCaptureEnabled" -BackupSubFolder "GPU" -DefaultValue 1

    $NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    $PrefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    $FastStartPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"

    Invoke-OverlordSafeRestore -TargetKey $NtfsPath -ValueName "NtfsDisableLastAccessUpdate" -BackupSubFolder "Storage" -DefaultValue 2
    Invoke-OverlordSafeRestore -TargetKey $NtfsPath -ValueName "NtfsDisable8dot3NameCreation" -BackupSubFolder "Storage" -DefaultValue 2
    Invoke-OverlordSafeRestore -TargetKey $NtfsPath -ValueName "NtfsMemoryUsage" -BackupSubFolder "Storage" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey $NtfsPath -ValueName "DisableDeleteNotify" -BackupSubFolder "Storage" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey $FastStartPath -ValueName "HiberbootEnabled" -BackupSubFolder "Storage" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -ValueName "SystemRestorePointCreationFrequency" -BackupSubFolder "Storage" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\VSS" -ValueName "Start" -BackupSubFolder "Storage" -DefaultValue 3
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\vmicvss" -ValueName "Start" -BackupSubFolder "Storage" -DefaultValue 3
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\DoSvc" -ValueName "Start" -BackupSubFolder "Services\DoSvc" -DefaultValue 2

    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -ValueName "PublishUserActivities" -BackupSubFolder "Telemetry" -DefaultValue 1

    $LoggersPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger"
    $Loggers = @("AutoLogger-Diagtrack-Listener", "SQMLogger", "DiagLog", "AitEventLog")
    foreach ($Logger in $Loggers) {
        Invoke-OverlordSafeRestore -TargetKey "$LoggersPath\$Logger" -ValueName "Start" -BackupSubFolder "Telemetry\Loggers\$Logger" -DefaultValue 1
    }

    $PowerBackup = "$BackupPath\Power"
    if (Test-Path $PowerBackup) {
        $Data = Get-ItemProperty -Path $PowerBackup -ErrorAction SilentlyContinue
        $SavedActiveGuid = Get-SafeRegistryValue -Path $PowerBackup -Name "ActivePowerPlan"
        $CustomPlanGuid = Get-SafeRegistryValue -Path $PowerBackup -Name "CustomPowerPlan"

        # Restaurar indices de configuracion de energia originales        
        $SubGroupMap = @{
            "94d3a615-a899-4ac5-ae2b-e4d8f634367f" = "54533251-82be-4824-96c1-47b60b740d00"
            "ee12f906-d277-404b-b6da-e5fa1a576df5" = "501a4d13-42af-4429-9fd1-a8218c268e20"
            "d4e00550-747f-4ddb-bf3e-9b6c97a522a4" = "2a737441-1930-4402-8d77-b2bea128a440"
            "0cc5b647-c1df-4637-891a-dec35c318583" = "54533251-82be-4824-96c1-47b60b740d00"
            "ea062031-0e34-4ff1-9b6d-eb1059334028" = "54533251-82be-4824-96c1-47b60b740d00"
            "ea0653f5-eab4-474c-8a0f-1ba102244432" = "54533251-82be-4824-96c1-47b60b740d00"
            "6733a230-cd1a-4929-94d4-540b4ddecbeb" = "0012ee47-9041-4b5d-9b77-535fba8b1442"
            "3668a66e-6856-4221-b530-747f2d53e4c6" = "54533251-82be-4824-96c1-47b60b740d00"
            "be337238-0d82-4146-a960-4f3749d470c7" = "54533251-82be-4824-96c1-47b60b740d00"
            "d874b2c9-943b-47dd-9190-25e0e3c95a12" = "2a8713cd-255e-4fc5-a639-12b87a5b3e8a"
        }
        if ($null -ne $Data) {
            foreach ($Prop in $Data.PSObject.Properties) {
                if ($Prop.Name -match "^Power_([a-f0-9-]{36})_([a-f0-9-]{36})$") {
                    $SchemeGuid = $Matches[1]
                    $SettingGuid = $Matches[2]
                    $SubGroupGuid = $SubGroupMap[$SettingGuid]
                    $Val = $Prop.Value
                    if ($SubGroupGuid -and $null -ne $Val) {
                        if ($Val -eq '_ABSENT_') {
                            $SettingPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$SchemeGuid\$SubGroupGuid\$SettingGuid"
                            if (Test-Path $SettingPath) {
                                Remove-ItemProperty -Path $SettingPath -Name "ACSettingIndex" -ErrorAction SilentlyContinue | Out-Null
                                Remove-ItemProperty -Path $SettingPath -Name "DCSettingIndex" -ErrorAction SilentlyContinue | Out-Null
                                
                                # Si la clave ya no tiene propiedades ni subclaves, eliminarla por completo
                                $key = Get-Item -Path $SettingPath -ErrorAction SilentlyContinue
                                if ($null -ne $key -and $key.ValueCount -eq 0 -and $key.SubKeyCount -eq 0) {
                                    Remove-Item -Path $SettingPath -Force -ErrorAction SilentlyContinue | Out-Null
                                }
                                
                                # Tambien verificar si la clave de subgrupo queda vacia
                                $SubGroupPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$SchemeGuid\$SubGroupGuid"
                                if (Test-Path $SubGroupPath) {
                                    $subKey = Get-Item -Path $SubGroupPath -ErrorAction SilentlyContinue
                                    if ($null -ne $subKey -and $subKey.ValueCount -eq 0 -and $subKey.SubKeyCount -eq 0) {
                                        Remove-Item -Path $SubGroupPath -Force -ErrorAction SilentlyContinue | Out-Null
                                    }
                                }
                            }
                        } else {
                            & powercfg /SETACVALUEINDEX $SchemeGuid $SubGroupGuid $SettingGuid $Val 2>$null | Out-Null
                        }
                    }
                }
            }
        }

        
        if (![string]::IsNullOrWhiteSpace($CustomPlanGuid)) {
            try {
                
                $current = powercfg /getactivescheme
                if ($current -match $CustomPlanGuid) {
                    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
                }
                powercfg /delete $CustomPlanGuid 2>$null | Out-Null
            } catch {
                Write-Host "[!] Aviso: No se pudo borrar el plan custom, posiblemente ya no existe."
            }
        }

        
        if (![string]::IsNullOrWhiteSpace($SavedActiveGuid)) {
            try {
                powercfg /setactive $SavedActiveGuid 2>$null | Out-Null
            } catch {
                powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null | Out-Null
            }
        }


    }
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -ValueName "PowerThrottlingOff" -BackupSubFolder "Power" -DefaultValue 0

    $PerfBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Performance"
    if (Test-Path $PerfBackupPath) {
        $perfProps = Get-ItemProperty -Path $PerfBackupPath -ErrorAction SilentlyContinue
        if ($null -ne $perfProps -and $null -ne $perfProps.PSObject.Properties["DynamicTickWasDisabled"]) {
            $wasDisabled = $perfProps.DynamicTickWasDisabled
            if ($wasDisabled -eq 0) {
                try { & bcdedit /deletevalue disabledynamictick 2>$null } catch {}
                Remove-ItemProperty -Path $PerfBackupPath -Name "DynamicTickWasDisabled" -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }

    $StorageBackup = "HKLM:\SOFTWARE\Overlord\Backup\Storage"
    $SavedHibernate = Get-SafeRegistryValue -Path $StorageBackup -Name "HibernateEnabled"
    if ($null -ne $SavedHibernate) {
        if ($SavedHibernate -eq 0) { powercfg.exe /hibernate off | Out-Null } else { powercfg.exe /hibernate on | Out-Null }
    }

    if (Test-Path $GameHooksBackup) {
        Write-Host "[*] Revirtiendo capas de compatibilidad grafica y configuraciones de juegos..."
        $SubKeys = Get-ChildItem -Path $GameHooksBackup -ErrorAction SilentlyContinue
        foreach ($Key in $SubKeys) {
            $GamePath = Get-SafeRegistryValue -Path $Key.PSPath -Name "Path"
            $PreviousLayers = Get-SafeRegistryValue -Path $Key.PSPath -Name "PreviousLayers"
            
            if (![string]::IsNullOrWhiteSpace($GamePath)) {
                $LayersPath = "$HKCU_Path\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
                if (Test-Path $LayersPath) {
                    if (![string]::IsNullOrWhiteSpace($PreviousLayers)) {
                        Set-ItemProperty -Path $LayersPath -Name $GamePath -Type String -Value $PreviousLayers -Force | Out-Null
                    } else {
                        Remove-ItemProperty -Path $LayersPath -Name $GamePath -ErrorAction SilentlyContinue | Out-Null
                    }
                }
            }

            # Restaurar IFEO original
            $IfeoBackup = "HKLM:\SOFTWARE\Overlord\Backup\GameHooks\$($Key.PSChildName)\IFEORegacy"
            $IfeoTarget = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($Key.PSChildName)"
            if (Test-Path $IfeoBackup) {
                $StatusVal = Get-SafeRegistryValue -Path $IfeoBackup -Name "Status"
                if ($StatusVal -eq "_ABSENT_") {
                    if (Test-Path $IfeoTarget) {
                        Remove-Item -Path $IfeoTarget -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                } else {
                    if (Test-Path $IfeoTarget) {
                        Remove-Item -Path $IfeoTarget -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    Copy-Item -Path $IfeoBackup -Destination $IfeoTarget -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }

            # Restaurar preferencias originales de pantalla en GameUserSettings.ini
            $IniPath = Get-SafeRegistryValue -Path $Key.PSPath -Name "IniPath"
            if ($IniPath -and (Test-Path $IniPath)) {
                $KeysToRestore = @("FullscreenMode", "LastConfirmedFullscreenMode", "PreferredFullscreenMode")
                $RestoredValues = @{}
                foreach ($K in $KeysToRestore) {
                    $PropVal = Get-SafeRegistryValue -Path $Key.PSPath -Name "Original_$K"
                    if ($null -ne $PropVal) {
                        $RestoredValues[$K] = $PropVal
                    }
                }
                
                if ($RestoredValues.Count -gt 0) {
                    if ((Get-Item $IniPath).IsReadOnly) { Set-ItemProperty -Path $IniPath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue | Out-Null }
                    $content = Get-Content $IniPath
                    $newContent = [System.Collections.Generic.List[string]]::new()
                    $changed = $false
                    foreach ($line in $content) {
                        $keepLine = $true
                        $modified = $line
                        foreach ($K in $RestoredValues.Keys) {
                            if ($line -match "^\s*$K\s*=") {
                                if ($RestoredValues[$K] -eq '_ABSENT_') {
                                    $keepLine = $false
                                    $changed = $true
                                } else {
                                    $targetValue = "$K=$($RestoredValues[$K])"
                                    if ($line.Trim() -notmatch "^\s*$K\s*=\s*$($RestoredValues[$K])\s*$") {
                                        $modified = $targetValue
                                        $changed = $true
                                    }
                                }
                                break
                            }
                        }
                        if ($keepLine) {
                            $newContent.Add($modified)
                        }
                    }
                    if ($changed) {
                        Set-Content -Path $IniPath -Value $newContent -Force | Out-Null
                        Write-Host "    -> Preferencias de pantalla originales restauradas en: $IniPath"
                    }
                    $OrigReadOnly = Get-SafeRegistryValue -Path $Key.PSPath -Name "Original_IsReadOnly"
                    if ($OrigReadOnly -eq 1) {
                        Set-ItemProperty -Path $IniPath -Name IsReadOnly -Value $true -ErrorAction SilentlyContinue | Out-Null
                    }
                }
            }
        }
    }



    Uninstall-OverlordPriorityDaemon

    # Restauracion dinamica de USB Selective Suspend delegada al bucle general

    # Intento de re-registro de aplicaciones AppX provisionadas del sistema eliminadas durante el debloat
    $AppsToRestore = @(
        "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.GetHelp",
        "Microsoft.Getstarted", "Microsoft.Messaging", "Microsoft.3DBuilder",
        "Microsoft.People", "Microsoft.SkypeApp", "Microsoft.StickyNotes",
        "Microsoft.Wallet", "Microsoft.YourPhone", "Microsoft.ZuneVideo",
        "Microsoft.ZuneMusic", "Microsoft.MixedReality.Portal",
        "Microsoft.549981C3F5F10", "Microsoft.Windows.Ai.Copilot.Provider",
        "Microsoft.BingSearch", "Clipchamp.Clipchamp", "Microsoft.MicrosoftSolitaireCollection", "Microsoft.Todos",
        "Microsoft.PowerAutomateDesktop", "Microsoft.Cortana", "Microsoft.BingFinance",
        "Microsoft.BingSports", "Microsoft.MicrosoftMahjong", "Microsoft.WindowsFeedbackHub",
        "Microsoft.Print3D", "Microsoft.Microsoft3DViewer", "Microsoft.WindowsMaps"
    )
    $WindowsAppsPath = Join-Path $env:ProgramFiles "WindowsApps"
    if (Test-Path $WindowsAppsPath) {
        foreach ($App in $AppsToRestore) {
            try {
                $AppDirs = Get-ChildItem -Path $WindowsAppsPath -Directory -Filter "$App*" -ErrorAction SilentlyContinue
                foreach ($Dir in $AppDirs) {
                    $ManifestPath = Join-Path $Dir.FullName "AppXManifest.xml"
                    if (Test-Path $ManifestPath) {
                        Add-AppxPackage -DisableDevelopmentMode -Register $ManifestPath -ErrorAction SilentlyContinue | Out-Null
                        if (Get-Command Add-AppxProvisionedPackage -ErrorAction SilentlyContinue) {
                            Add-AppxProvisionedPackage -Online -PackagePath $Dir.FullName -DependencyPackagePath @() -LicensePath "" -ErrorAction SilentlyContinue | Out-Null
                        }
                    }
                }
            } catch {}
        }
    }

    # Revertir exclusiones de Windows Defender agregadas por Overlord
    $DefenderBackup = "HKLM:\SOFTWARE\Overlord\Backup\DefenderExclusions"
    if (Test-Path $DefenderBackup) {
        $AddedExclusions = Get-SafeRegistryValue -Path $DefenderBackup -Name "AddedExclusions"
        if (![string]::IsNullOrWhiteSpace($AddedExclusions)) {
            $Paths = $AddedExclusions -split ";" | Where-Object { $_ -ne "" }
            foreach ($Path in $Paths) {
                Remove-MpPreference -ExclusionPath $Path -ErrorAction SilentlyContinue | Out-Null
                Write-Host "    [-] Exclusion de Windows Defender removida: $Path"
            }
        }
        Remove-Item -Path $DefenderBackup -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }



    if (Test-Path $BackupPath) {
        $RemainingFiles = Get-ChildItem -Path $BackupPath -Recurse -ErrorAction SilentlyContinue
        if ($null -eq $RemainingFiles -or @($RemainingFiles).Count -eq 0) {
            Remove-Item -Path $BackupPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        } else {
            Write-Warning "No se borraron todos los respaldos, la carpeta $BackupPath no est vaca."
        }
    }

    # Eliminar la clave padre principal si queda vacia tras la reversion para no dejar huella
    $OverlordKey = "HKLM:\SOFTWARE\Overlord"
    if (Test-Path $OverlordKey) {
        $Subkeys = Get-ChildItem -Path $OverlordKey -ErrorAction SilentlyContinue
        if ($null -eq $Subkeys -or @($Subkeys).Count -eq 0) {
            Remove-Item -Path $OverlordKey -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
    Write-Host "Reiniciando el entorno del Explorador de Windows..."
    if (Get-Process -Name explorer -ErrorAction SilentlyContinue) {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe | Out-Null
    }
    Write-Host "[+] Reversion completa de Overlord finalizada con exito."
    exit 0

} Catch {
    Write-Error "[-] Error fatal durante la ejecucion de la reversion: $($_.Exception.Message)"
    exit 1
}

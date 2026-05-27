param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Aplicando optimizaciones de rendimiento general y Kernel..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Performance"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    if (Test-Path $MemPath) {
        $OrigPaging = (Get-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -ErrorAction SilentlyContinue).DisablePagingExecutive
        if ($OrigPaging -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "DisablePagingExecutive" -ErrorAction SilentlyContinue) -eq $null) {
            Set-ItemProperty -Path $BackupPath -Name "DisablePagingExecutive" -Type DWord -Value $OrigPaging -Force
        }
    }

    if ($RamGB -ge 16 -and -not $IsLaptop) {
        Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value 1 -Force
    } else {
        Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value 0 -Force
    }

    Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue

    $MitigationsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    $OrigSpec = (Get-ItemProperty -Path $MitigationsPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue).FeatureSettingsOverride
    $OrigMask = (Get-ItemProperty -Path $MitigationsPath -Name "FeatureSettingsOverrideMask" -ErrorAction SilentlyContinue).FeatureSettingsOverrideMask

    if ($OrigSpec -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue) -eq $null) {
        Set-ItemProperty -Path $BackupPath -Name "FeatureSettingsOverride" -Type DWord -Value $OrigSpec -Force
    }
    if ($OrigMask -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "FeatureSettingsOverrideMask" -ErrorAction SilentlyContinue) -eq $null) {
        Set-ItemProperty -Path $BackupPath -Name "FeatureSettingsOverrideMask" -Type DWord -Value $OrigMask -Force
    }

    Set-ItemProperty -Path $MitigationsPath -Name "FeatureSettingsOverride" -Type DWord -Value 3 -Force
    Set-ItemProperty -Path $MitigationsPath -Name "FeatureSettingsOverrideMask" -Type DWord -Value 3 -Force

    $StorePath = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $StorePath)) { New-Item -Path $StorePath -Force | Out-Null }
    Set-ItemProperty -Path $StorePath -Name "GameDVR_Enabled" -Type DWord -Value 0 -Force

    $FthPath = "HKLM:\Software\Microsoft\FTH"
    if (!(Test-Path $FthPath)) { New-Item -Path $FthPath -Force | Out-Null }
    Set-ItemProperty -Path $FthPath -Name "Enabled" -Type DWord -Value 0 -Force

    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Rendimiento: $_"
    exit 1
}

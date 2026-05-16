param([string]$Action = "")
$ErrorActionPreference = "SilentlyContinue"

switch ($Action) {
    "PurgeRAM" {
        $PInvokeCode = @"
        using System;
        using System.Runtime.InteropServices;
        public class RamPurger {
            [DllImport("ntdll.dll")]
            public static extern int NtSetSystemInformation(int SystemInformationClass, IntPtr SystemInformation, int SystemInformationLength);
        }
"@
        Add-Type -TypeDefinition $PInvokeCode -Language CSharp
        $Size = [System.Runtime.InteropServices.Marshal]::SizeOf([System.Int32])
        $Ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($Size)
        [System.Runtime.InteropServices.Marshal]::WriteInt32($Ptr, 4)
        [RamPurger]::NtSetSystemInformation(80, $Ptr, $Size) | Out-Null
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($Ptr)
        Write-Output "RAM purgada."
        exit 0
    }
    "DeepClean" {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c cleanmgr.exe /sagerun:1" -WindowStyle Hidden -Wait
        Write-Output "Limpieza finalizada."
        exit 0
    }
    "FlushNet" {
        ipconfig /flushdns | Out-Null
        netsh winsock reset | Out-Null
        netsh int ip reset | Out-Null
        Write-Output "Red reiniciada."
        exit 0
    }
    "RepairOS" {
        DISM /Online /Cleanup-Image /RestoreHealth | Out-Null
        sfc /scannow | Out-Null
        Write-Output "OS Reparado."
        exit 0
    }
}
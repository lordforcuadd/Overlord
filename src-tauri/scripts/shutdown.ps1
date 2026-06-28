param([string]$IsLaptop, [string]$RamGb, [string]$Arguments)
$ErrorActionPreference = "SilentlyContinue"
shutdown.exe /r /t 10 /c "Overlord reiniciara su sistema en 10 segundos..."
exit 0
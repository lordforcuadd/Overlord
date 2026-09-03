# shutdown.ps1
& shutdown.exe /r /t 10 /c "Overlord reiniciara su sistema en 10 segundos..."
if ($LASTEXITCODE -ne 0) {
    Write-Warning "No se pudo programar el reinicio del sistema (codigo de salida: $LASTEXITCODE)"
    exit $LASTEXITCODE
}
exit 0

# REPARA el PATH de sistema:
#   1. Restaura el backup original (por si quedo roto)
#   2. Pone C:\msys64\ucrt64\bin en el indice 0 (antes de PostgreSQL 18,
#      Android SDK y ProgramData\mingw64, que traen DLLs MinGW viejas que
#      rompen GTK4: libwinpthread sin clock_gettime64, libstdc++ antiguo)
#   3. Valida ANTES y DESPUES de escribir; no toca nada si algo falla.
# Requiere PowerShell elevado (el .bat lanza el UAC).

$ucrt  = 'C:\msys64\ucrt64\bin'
$old   = 'C:\ProgramData\mingw64\mingw64\bin'
$backup = 'C:\Users\punks\AppData\Local\Temp\opencode\path-machine-backup.txt'
$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'

function Test-ValidPathValue([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $false }
    if ($s.Contains('Collections')) { return $false }          # el ArrayList roto
    if ($s.Length -lt 200) { return $false }                    # sospechosamente corto
    if (-not $s.Contains('System32')) { return $false }         # todo PATH de sistema lo lleva
    return $true
}

# --- 1. Leer backup ---
if (-not (Test-Path $backup)) {
    Write-Host "ERROR: no existe el backup $backup"
    Read-Host "Pulsa Enter para salir"; exit 1
}
$restored = Get-Content -Raw $backup
if ($restored.Length -gt 0 -and $restored[0] -eq [char]0xFEFF) { $restored = $restored.Substring(1) }
$restored = $restored.TrimEnd([char[]]@("`r", "`n"))

if (-not (Test-ValidPathValue $restored)) {
    Write-Host "ERROR: el backup NO parece un PATH valido. No se toca nada."
    Read-Host "Pulsa Enter para salir"; exit 1
}
Write-Host "Backup valido ($($restored.Length) caracteres)."

# --- 2. Estado actual del registro ---
$current = (Get-ItemProperty -Path $regPath -Name Path -ErrorAction SilentlyContinue).Path
Write-Host "Registro actual: $(if ([string]::IsNullOrEmpty($current)) { '<vacio>' } else { if (Test-ValidPathValue $current) { 'OK' } else { 'ROTO: ' + $current.Substring(0, [Math]::Min(60, $current.Length)) } })"

# --- 3. Construir el PATH final: desde el backup (original) + ucrt64 al PRINCIPIO ---
# Motivo: el cargador de Windows busca system32 antes que el PATH, pero dentro
# del PATH gana el primero. PostgreSQL 18 y Android SDK traen un libwinpthread-1.dll
# viejo que rompe GTK4 (falta clock_gettime64). Con ucrt64 en el indice 0 gana siempre
# sin tocar system32 (vulkan-1.dll de system32 sigue ganando por orden del cargador).
$result = New-Object System.Collections.ArrayList
foreach ($x in ($restored -split ';')) {
    $t = $x.TrimEnd('\')
    if ($t -ieq $ucrt) { continue }   # quitamos ucrt64 de donde estuviera
    [void]$result.Add($x)
}
[void]$result.Insert(0, $ucrt)

$newPath = [string]::Join(';', [string[]]$result)

# --- 4. VALIDACION pre-escritura (critica) ---
if (-not (Test-ValidPathValue $newPath)) {
    Write-Host "ERROR: el PATH construido no valida. NO se escribio nada."
    Read-Host "Pulsa Enter para salir"; exit 1
}
foreach ($must in @($ucrt, $old, 'System32')) {
    if (-not $newPath.Contains($must)) {
        Write-Host "ERROR: falta '$must' en el PATH construido. NO se escribio nada."
        Read-Host "Pulsa Enter para salir"; exit 1
    }
}
Write-Host "Validacion pre-escritura OK ($($newPath.Length) caracteres, $($result.Count) entradas)."

# --- 5. Escribir ---
try {
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'Machine')
} catch {
    Write-Host "ERROR al escribir (permisos?): $($_.Exception.Message)"
    Read-Host "Pulsa Enter para salir"; exit 1
}

# --- 6. Verificacion post-escritura ---
$check = (Get-ItemProperty -Path $regPath -Name Path).Path
if (-not (Test-ValidPathValue $check)) {
    Write-Host "ALERTA: la verificacion post-escritura fallo. Intenta restaurar solo el backup..."
    try { [Environment]::SetEnvironmentVariable('Path', $restored, 'Machine') } catch {}
    Read-Host "Pulsa Enter para salir"; exit 1
}
$parts = @($check -split ';' | ForEach-Object { $_.TrimEnd('\') })
$iU = [array]::IndexOf($parts, $ucrt)
$iO = [array]::IndexOf($parts, $old)

Write-Host ""
Write-Host "RESULTADO:"
Write-Host "  entradas: $($parts.Count) | indice ucrt64: $iU | indice toolchain viejo: $iO"
if ($iU -eq 0) {
    Write-Host "  VERIFICADO: ucrt64 en el indice 0 (gana a PostgreSQL/Android/ProgramData). TODO OK"
} else {
    Write-Host "  AVISO: ucrt64 deberia estar en el indice 0 y esta en $iU."
}
Write-Host ""
Write-Host "Abre una terminal NUEVA para que el cambio surta efecto."
Read-Host "Pulsa Enter para salir"
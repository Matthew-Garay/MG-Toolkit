<# : NO BORRAR ESTA LINEA - parte batch que lanza el programa en PowerShell
@echo off
title MG Toolkit - Herramientas de Limpieza y Optimizacion de Windows - por Matthew Garay
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Solicitando permisos de administrador...
    if "%~1"=="" (
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    ) else (
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    )
    exit /b
)
set "OPT_SELF=%~f0"
set "OPT_ARGS=%*"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText($env:OPT_SELF))"
if errorlevel 1 if /i not "%~1"=="--mantenimiento" pause
exit /b
#>

# =====================================================================
#   MG Toolkit - Herramientas de Limpieza y Optimizacion de Windows 7 / 8 / 8.1 / 10 / 11
#   Creado por Matthew Garay
#   Uso:  "MG Toolkit.bat"                    (normal, con menu)
#         "MG Toolkit.bat" --dry-run          (simulacion: no cambia nada)
#         "MG Toolkit.bat" --mantenimiento    (lo usa la tarea semanal, sin menu)
# =====================================================================

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
$global:AppName   = 'MG Toolkit - Herramientas de Limpieza y Optimizacion de Windows'
$global:AppAuthor = 'Matthew Garay'
$global:AppVer    = '1.0'
try { $Host.UI.RawUI.WindowTitle = $global:AppName + ' v' + $global:AppVer + ' - por ' + $global:AppAuthor } catch {}

# ---------- Verificacion de privilegios de administrador ----------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'ERROR: Este programa debe ejecutarse como Administrador.' -ForegroundColor Red
    Read-Host 'Presiona ENTER para salir' | Out-Null
    exit 1
}

# ---------- Compatibilidad: Windows 7 / 8 / 8.1 / 10 / 11 ----------
$global:WinBuild = [int](Get-WmiObject Win32_OperatingSystem).BuildNumber
$global:IsWin8   = ($global:WinBuild -ge 9200)     # Windows 8 o superior
$global:IsWin81  = ($global:WinBuild -ge 9600)     # Windows 8.1 o superior
$global:IsWin10  = ($global:WinBuild -ge 10240)    # Windows 10 o superior
$global:WinName  = 'Windows 11'
if ($global:WinBuild -lt 22000) { $global:WinName = 'Windows 10' }
if ($global:WinBuild -lt 10240) { $global:WinName = 'Windows 8.1' }
if ($global:WinBuild -lt 9600)  { $global:WinName = 'Windows 8' }
if ($global:WinBuild -lt 9200)  { $global:WinName = 'Windows 7' }
$global:Is64 = ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'AMD64' -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64')
$global:Win7StartupStore = 'HKLM:\SOFTWARE\MGToolkit\InicioDesactivado'

# PowerShell 2.0 (Windows 7) no tiene Get-CimInstance: se usa WMI y se convierten las fechas
if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
    function Get-CimInstance {
        [CmdletBinding()]
        param([Parameter(Position = 0)][string]$ClassName, [string]$Filter, [string]$Namespace = 'root\cimv2')
        $p = @{ Class = $ClassName; Namespace = $Namespace }
        if ($Filter) { $p['Filter'] = $Filter }
        foreach ($o in @(Get-WmiObject @p)) {
            $h = @{}
            foreach ($prop in $o.PSObject.Properties) {
                if ($prop.Name -like '__*') { continue }
                $v = $prop.Value
                if ($v -is [string] -and $v -match '^\d{14}\.\d{6}[\+\-]\d{3}$') { try { $v = [Management.ManagementDateTimeConverter]::ToDateTime($v) } catch {} }
                $h[$prop.Name] = $v
            }
            New-Object PSObject -Property $h
        }
    }
}

# PowerShell 2.0 no tiene Get-ChildItem -File / -Directory
if ($PSVersionTable.PSVersion.Major -lt 3) {
    function Get-ChildItem {
        [CmdletBinding()]
        param([Parameter(Position = 0)][string[]]$Path, [string[]]$LiteralPath, [Parameter(Position = 1)][string]$Filter,
              [switch]$Recurse, [switch]$Force, [switch]$File, [switch]$Directory)
        $p = @{}
        if ($Path) { $p['Path'] = $Path }
        if ($LiteralPath) { $p['LiteralPath'] = $LiteralPath }
        if ($Filter) { $p['Filter'] = $Filter }
        if ($Recurse) { $p['Recurse'] = $true }
        if ($Force) { $p['Force'] = $true }
        if ($File) { Microsoft.PowerShell.Management\Get-ChildItem @p | Where-Object { -not $_.PSIsContainer } }
        elseif ($Directory) { Microsoft.PowerShell.Management\Get-ChildItem @p | Where-Object { $_.PSIsContainer } }
        else { Microsoft.PowerShell.Management\Get-ChildItem @p }
    }
}

function Test-Cmd([string]$name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Show-NotSupported([string]$what) {
    Write-Host ('  ' + $what + ' no esta disponible en ' + $global:WinName + '.') -ForegroundColor Yellow
    Write-Log ('[NO DISPONIBLE] ' + $what + ' en ' + $global:WinName)
}

function Get-FreeBytes([string]$drive = $env:SystemDrive) {
    $d = @(Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='" + $drive.TrimEnd('\') + "'"))
    if ($d.Count -gt 0) { return [double]$d[0].FreeSpace }
    return [double]0
}

# Tipo de inicio de un servicio (funciona en todas las versiones): Automatic / Manual / Disabled
function Get-SvcStartMode([string]$name) {
    $s = @(Get-CimInstance Win32_Service -Filter ("Name='" + $name + "'"))
    if ($s.Count -eq 0) { return '' }
    switch ([string]$s[0].StartMode) { 'Auto' { return 'Automatic' } 'Manual' { return 'Manual' } 'Disabled' { return 'Disabled' } default { return [string]$s[0].StartMode } }
}

# Discos en Windows 7 (no existe Get-PhysicalDisk). Status = "Pred Fail" cuando el disco avisa que va a fallar.
function Get-Win7Disks {
    foreach ($d in @(Get-CimInstance Win32_DiskDrive)) {
        $bad = ([string]$d.Status -ne 'OK')
        $salud = 'Saludable'; if ($bad) { $salud = 'CON PROBLEMAS (' + $d.Status + ')' }
        New-Object PSObject -Property @{ Disco = [string]$d.Model; 'Tamano (GB)' = [math]::Round([double]$d.Size / 1GB); Salud = $salud; Falla = $bad }
    }
}

# Antivirus de Microsoft por linea de comandos (Microsoft Security Essentials en Windows 7, Defender en 8)
function Get-MpCmdRun {
    foreach ($p in @("$env:ProgramFiles\Microsoft Security Client\MpCmdRun.exe", "$env:ProgramFiles\Windows Defender\MpCmdRun.exe")) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

# ---------- Configuracion global y log ----------
$global:DryRun   = ($env:OPT_ARGS -match '(--dry-run|/dry-run|--simular|/simular)')
$global:Freed    = [int64]0
$global:Errors   = 0
$global:Warnings = 0
$global:Maint    = ($env:OPT_ARGS -match '--mantenimiento')
if ($global:Maint) { $global:LogDir = Join-Path $env:ProgramData 'MGToolkit\Logs' }
else { $global:LogDir = Join-Path ([Environment]::GetFolderPath('Desktop')) 'MG Toolkit - Informes' }
if (-not (Test-Path -LiteralPath $global:LogDir)) { New-Item -ItemType Directory -Path $global:LogDir -Force | Out-Null }
$global:LogFile  = Join-Path $global:LogDir ('log_' + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + '.txt')
$global:Auto     = $false
$global:YesAll   = $false
$global:Results  = @{}
$global:StepLog  = New-Object System.Collections.ArrayList
$global:Checks   = New-Object System.Collections.ArrayList
$global:Missing  = New-Object System.Collections.ArrayList
$global:LastLive = $null

function Write-Log([string]$msg) {
    $line = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $msg
    try { Add-Content -LiteralPath $global:LogFile -Value $line } catch {}
}

$osInfo = Get-CimInstance Win32_OperatingSystem
Write-Log ($global:AppName + ' v' + $global:AppVer + ' (por ' + $global:AppAuthor + ') - Equipo: ' + $env:COMPUTERNAME + ' - Usuario: ' + $env:USERNAME)
Write-Log ('Sistema: ' + $osInfo.Caption + ' build ' + $osInfo.BuildNumber)
Write-Log ('Modo simulacion: ' + $global:DryRun)

# =====================================================================
#   FUNCIONES DE APOYO
# =====================================================================
function Format-Size([double]$b) {
    if ($b -ge 1GB) { return ('{0:N2} GB' -f ($b / 1GB)) }
    return ('{0:N1} MB' -f ($b / 1MB))
}

function Write-Section([string]$t) {
    Write-Host ''
    Write-Host ('--- ' + $t + ' ---') -ForegroundColor Cyan
    Write-Log ('--- ' + $t + ' ---')
}

# $risky = $true: accion delicada, se pregunta siempre aunque se haya elegido "si a todo"
function Confirm-Action([string]$q, [bool]$autoAnswer = $false, [bool]$risky = $false) {
    if ($global:Auto) {
        $txt = 'NO'; if ($autoAnswer) { $txt = 'SI' }
        Write-Host ('  ' + $q + ' -> [automatico: ' + $txt + ']') -ForegroundColor DarkGray
        Write-Log ('[AUTO] ' + $q + ' -> ' + $txt)
        return $autoAnswer
    }
    if ($global:YesAll -and -not $risky) {
        Write-Host ('  ' + $q + ' -> [si a todo]') -ForegroundColor DarkGray
        Write-Log ('[SI A TODO] ' + $q)
        return $true
    }
    $opts = '(S = si / N = no / T = si a todo)'
    if ($risky) { $opts = '(S = si / N = no)' }
    while ($true) {
        $r = Read-Host ('  ' + $q + ' ' + $opts)
        if (-not $risky -and $r -match '^\s*[tT]') {
            $global:YesAll = $true
            Write-Host '  OK: se hara todo lo que queda sin volver a preguntar (salvo acciones delicadas).' -ForegroundColor Green
            Write-Log ('[SI A TODO] activado en: ' + $q)
            return $true
        }
        if ($r -match '^\s*[sSyY]') { return $true }
        if ($r -match '^\s*[nN]') { return $false }
    }
}

function Add-Result([string]$st, [string]$desc, [string]$msg) {
    [void]$global:StepLog.Add((New-Object PSObject -Property @{ Estado = $st; Tarea = $desc; Detalle = $msg }))
}

function Wait-Enter { Write-Host ''; Read-Host '  Presiona ENTER para continuar' | Out-Null }

function Show-Table { $input | Format-Table -AutoSize -Wrap | Out-String -Width 220 | Write-Host }

function Set-Reg([string]$path, [string]$name, $value, [string]$type = 'DWord') {
    if (-not (Test-Path -Path $path)) { New-Item -Path $path -Force | Out-Null }
    New-ItemProperty -Path $path -Name $name -Value $value -PropertyType $type -Force | Out-Null
}

# Ejecuta un paso: respeta el modo simulacion, captura errores y escribe en el log
function Step([string]$desc, [scriptblock]$action) {
    if ($global:DryRun) {
        Write-Host ('  [SIM] ' + $desc) -ForegroundColor DarkYellow
        Write-Log ('[SIMULACION] ' + $desc)
        return
    }
    Write-Host ('  -> ' + $desc)
    $global:LASTEXITCODE = 0
    try {
        $res  = & $action 2>&1
        $text = ($res | Out-String).Trim()
        if ($text) { Write-Log ('   salida: ' + $text) }
        $errs = @($res | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] -and $_.FullyQualifiedErrorId -notlike 'NativeCommandError*' })
        if ($errs.Count -gt 0) {
            $global:Warnings++
            Write-Host ('     aviso: ' + $errs[0].Exception.Message) -ForegroundColor Yellow
            Write-Log ('[AVISO] ' + $desc + ' : ' + $errs[0].Exception.Message)
            Add-Result 'AVISO' $desc $errs[0].Exception.Message
        } elseif ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
            $global:Warnings++
            Write-Host ('     aviso: termino con codigo ' + $LASTEXITCODE) -ForegroundColor Yellow
            Write-Log ('[AVISO] ' + $desc + ' (codigo ' + $LASTEXITCODE + ')')
            Add-Result 'AVISO' $desc ('codigo ' + $LASTEXITCODE)
        } else {
            Write-Log ('[OK] ' + $desc)
            Add-Result 'OK' $desc ''
        }
    } catch {
        $global:Errors++
        Write-Host ('     ERROR: ' + $_.Exception.Message) -ForegroundColor Red
        Write-Log ('[ERROR] ' + $desc + ' : ' + $_.Exception.Message)
        Add-Result 'ERROR' $desc $_.Exception.Message
    }
}

# Ejecuta un programa mostrando su salida en pantalla (DISM, SFC, CHKDSK...)
function Invoke-Live([string]$desc, [string]$exe, [string]$arguments) {
    $global:LastLive = $null
    if ($global:DryRun) {
        Write-Host ('  [SIM] ' + $desc + '  ->  ' + $exe + ' ' + $arguments) -ForegroundColor DarkYellow
        Write-Log ('[SIMULACION] ' + $desc + ' : ' + $exe + ' ' + $arguments)
        return
    }
    Write-Host ('  -> ' + $desc) -ForegroundColor White
    Write-Log ('[EJECUTANDO] ' + $exe + ' ' + $arguments)
    try {
        $p = Start-Process -FilePath $exe -ArgumentList $arguments -NoNewWindow -Wait -PassThru
        $global:LastLive = $p.ExitCode
        if ($p.ExitCode -eq 0) { Write-Log ('[OK] ' + $desc); Add-Result 'OK' $desc '' }
        else {
            $global:Warnings++
            Write-Host ('     Termino con codigo ' + $p.ExitCode + ' (revisa el mensaje de arriba)') -ForegroundColor Yellow
            Write-Log ('[AVISO] ' + $desc + ' termino con codigo ' + $p.ExitCode)
            Add-Result 'AVISO' $desc ('codigo ' + $p.ExitCode)
        }
    } catch {
        $global:LastLive = -1
        $global:Errors++
        Write-Host ('     ERROR: ' + $_.Exception.Message) -ForegroundColor Red
        Write-Log ('[ERROR] ' + $desc + ' : ' + $_.Exception.Message)
        Add-Result 'ERROR' $desc $_.Exception.Message
    }
}

# Borra el contenido de carpetas (acepta comodines) y cuenta el espacio liberado
# $olderDays > 0: solo borra archivos sin modificar en esos dias (no toca lo que un programa esta usando ahora)
function Clear-Folder([string]$desc, [string[]]$paths, [string]$filter = '*', [int]$olderDays = 0) {
    $roots = @()
    foreach ($p in $paths) {
        foreach ($r in @(Resolve-Path -Path $p -ErrorAction SilentlyContinue)) { $roots += $r.ProviderPath }
    }
    $roots = @($roots | Select-Object -Unique)
    $files = @()
    foreach ($r in $roots) {
        $files += @(Get-ChildItem -LiteralPath $r -Filter $filter -Recurse -Force -File -ErrorAction SilentlyContinue)
    }
    if ($olderDays -gt 0) {
        $lim = (Get-Date).AddDays(-$olderDays)
        $files = @($files | Where-Object { $_.LastWriteTime -lt $lim })
    }
    $size = [int64](($files | Measure-Object -Property Length -Sum).Sum)

    if ($global:DryRun) {
        Write-Host ('  [SIM] {0}: se borrarian {1} archivos ({2})' -f $desc, $files.Count, (Format-Size $size)) -ForegroundColor DarkYellow
        Write-Log ('[SIMULACION] {0}: {1} archivos ({2})' -f $desc, $files.Count, (Format-Size $size))
        foreach ($f in ($files | Select-Object -First 500)) { Write-Log ('      borraria: ' + $f.FullName) }
        if ($files.Count -gt 500) { Write-Log ('      ... y ' + ($files.Count - 500) + ' archivos mas') }
        $global:Freed += $size
        return
    }

    $freed = [int64]0; $fail = 0
    foreach ($f in $files) {
        try { $len = $f.Length; Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; $freed += $len }
        catch { $fail++ }
    }
    if ($filter -eq '*') {
        foreach ($r in $roots) {
            Get-ChildItem -LiteralPath $r -Directory -Recurse -Force -ErrorAction SilentlyContinue |
                Sort-Object { $_.FullName.Length } -Descending |
                ForEach-Object {
                    if (-not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue)) {
                        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                    }
                }
        }
    }
    $global:Freed += $freed
    $extra = ''
    if ($fail -gt 0) { $extra = ' (' + $fail + ' en uso, omitidos)' }
    Write-Host ('  -> {0}: {1} liberados{2}' -f $desc, (Format-Size $freed), $extra)
    Write-Log ('[OK] {0}: {1} liberados, {2} archivos borrados, {3} omitidos' -f $desc, (Format-Size $freed), ($files.Count - $fail), $fail)
}

function Start-ExplorerIfNeeded {
    Start-Sleep -Seconds 3
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}

function Get-RamStatus {
    $os = Get-CimInstance Win32_OperatingSystem
    (New-Object PSObject -Property @{
        Total = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        Libre = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    })
}

function Get-StandbyMB {
    try {
        $m = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory
        return [math]::Round(([double]$m.StandbyCacheNormalPriorityBytes + [double]$m.StandbyCacheReserveBytes + [double]$m.StandbyCacheCoreBytes) / 1MB)
    } catch { return -1 }
}

# Herramienta nativa para vaciar listas de memoria (igual que RAMMap / EmptyStandbyList)
$memToolSrc = @'
using System;
using System.Runtime.InteropServices;
public class MemTool {
    [DllImport("ntdll.dll")] static extern uint NtSetSystemInformation(int infoClass, ref int info, int length);
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool OpenProcessToken(IntPtr h, uint acc, out IntPtr tok);
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool LookupPrivilegeValue(string sys, string name, out long luid);
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool AdjustTokenPrivileges(IntPtr tok, bool disAll, ref TokPriv newSt, int len, IntPtr prev, IntPtr relen);
    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [StructLayout(LayoutKind.Sequential, Pack = 1)] struct TokPriv { public int Count; public long Luid; public int Attr; }
    static void Enable(string p) {
        IntPtr t; OpenProcessToken(GetCurrentProcess(), 0x28, out t);
        TokPriv tp; tp.Count = 1; tp.Attr = 2; LookupPrivilegeValue(null, p, out tp.Luid);
        AdjustTokenPrivileges(t, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }
    // 2 = vaciar working sets, 3 = vaciar lista modificada, 4 = vaciar lista standby
    public static uint Purge(int cmd) {
        Enable("SeProfileSingleProcessPrivilege"); Enable("SeIncreaseQuotaPrivilege");
        int c = cmd; return NtSetSystemInformation(80, ref c, 4);
    }
}
'@
function Initialize-MemTool { if (-not ('MemTool' -as [type])) { Add-Type -TypeDefinition $memToolSrc } }

# =====================================================================
#   MODULO 1: LIMPIEZA PROFUNDA DE ARCHIVOS BASURA Y CACHE
# =====================================================================
# Temporales: solo archivos de mas de 1 dia, para no romper instalaciones o programas abiertos
function M1-WinTemp  { Clear-Folder 'Temporales de Windows (C:\Windows\Temp)' @("$env:SystemRoot\Temp") '*' 1 }

function M1-UserTemp { Clear-Folder 'Temporales de usuarios (AppData\Local\Temp)' @("$env:SystemDrive\Users\*\AppData\Local\Temp") '*' 1 }

function M1-Recycle {
    $paths = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { $_.DeviceID + '\$Recycle.Bin' })
    Clear-Folder 'Papelera de reciclaje (todas las unidades)' $paths
}

function M1-Prefetch {
    Write-Section 'Cache de Prefetch'
    Write-Host '  NOTA: Windows usa Prefetch para abrir los programas mas rapido. Despues de borrarlo,' -ForegroundColor Yellow
    Write-Host '        el arranque y la primera apertura de cada programa seran algo mas lentos.' -ForegroundColor Yellow
    if (Confirm-Action 'Borrar la cache de Prefetch?' $false $true) { Clear-Folder 'Prefetch' @("$env:SystemRoot\Prefetch") '*.pf' }
    else { Write-Log '[OMITIDO] Prefetch' }
}

function M1-Store {
    Clear-Folder 'Cache de apps de la Tienda (Windows Apps)' @(
        "$env:SystemDrive\Users\*\AppData\Local\Packages\*\AC\INetCache",
        "$env:SystemDrive\Users\*\AppData\Local\Packages\*\AC\Temp",
        "$env:SystemDrive\Users\*\AppData\Local\Packages\Microsoft.WindowsStore_*\LocalCache")
}

function M1-WUCache {
    Step 'Detener Windows Update y BITS' { Stop-Service -Name wuauserv, bits -Force -ErrorAction SilentlyContinue }
    Clear-Folder 'Cache de Windows Update (SoftwareDistribution\Download)' @("$env:SystemRoot\SoftwareDistribution\Download")
    Step 'Iniciar Windows Update y BITS' { Start-Service -Name bits, wuauserv -ErrorAction SilentlyContinue }
}

function M1-Dumps {
    Clear-Folder 'Volcados de memoria (Minidump) y reportes de error' @(
        "$env:SystemRoot\Minidump", "$env:SystemRoot\MEMORY.DMP", "$env:SystemRoot\LiveKernelReports",
        "$env:ProgramData\Microsoft\Windows\WER", "$env:SystemDrive\Users\*\AppData\Local\CrashDumps")
}

function M1-EventLogs {
    Write-Section 'Registros de eventos'
    Write-Host '  NOTA: los registros de eventos sirven para diagnosticar fallos (pantallas azules, apagados).' -ForegroundColor Yellow
    Write-Host '        Si el equipo tiene un problema sin resolver, revisalos antes de borrarlos.' -ForegroundColor Yellow
    if (-not (Confirm-Action 'Vaciar los registros Aplicacion, Sistema e Instalacion?')) { Write-Log '[OMITIDO] Registros de eventos'; return }
    $logs = @('Application', 'System', 'Setup')
    if (Confirm-Action 'Vaciar tambien el registro de SEGURIDAD? (borra el historial de auditoria)' $false $true) { $logs += 'Security' }
    foreach ($l in $logs) { Step ('Vaciar registro de eventos: ' + $l) { wevtutil cl $l } }
}

function M1-Installers {
    Write-Section 'Restos de instaladores'
    Write-Host '  NOTA: MSOCache es la copia de instalacion de Office. Sin ella, "Reparar Office" necesitara internet.' -ForegroundColor Yellow
    Clear-Folder 'Restos de instaladores (MSOCache, cache multimedia de Adobe)' @(
        "$env:SystemDrive\MSOCache",
        "$env:SystemDrive\Users\*\AppData\Roaming\Adobe\Common\Media Cache Files",
        "$env:SystemDrive\Users\*\AppData\Roaming\Adobe\Common\Media Cache")
}

function M1-Browsers {
    Write-Section 'Cache de navegadores (no borra contrasenas, favoritos ni historial)'
    $u = "$env:SystemDrive\Users\*\AppData\Local"
    $chromium = @('Cache', 'Code Cache', 'GPUCache', 'Service Worker\CacheStorage')
    $browsers = @(
        @{ N = 'Google Chrome';  P = 'chrome';  Paths = @($chromium | ForEach-Object { "$u\Google\Chrome\User Data\*\$_" }) },
        @{ N = 'Microsoft Edge'; P = 'msedge';  Paths = @($chromium | ForEach-Object { "$u\Microsoft\Edge\User Data\*\$_" }) },
        @{ N = 'Brave';          P = 'brave';   Paths = @($chromium | ForEach-Object { "$u\BraveSoftware\Brave-Browser\User Data\*\$_" }) },
        @{ N = 'Opera';          P = 'opera';   Paths = @("$u\Opera Software\Opera Stable\Cache", "$u\Opera Software\Opera GX Stable\Cache") },
        @{ N = 'Firefox';        P = 'firefox'; Paths = @("$u\Mozilla\Firefox\Profiles\*\cache2") }
    )
    foreach ($b in $browsers) {
        if (Get-Process -Name $b.P -ErrorAction SilentlyContinue) {
            if ($global:DryRun -or (Confirm-Action ($b.N + ' esta abierto. Cerrarlo para limpiar su cache?'))) {
                if (-not $global:DryRun) { Stop-Process -Name $b.P -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 }
            } else { Write-Host ('  -> ' + $b.N + ': omitido (abierto)'); Write-Log ('[OMITIDO] ' + $b.N + ' abierto'); continue }
        }
        Clear-Folder ('Cache de ' + $b.N) $b.Paths
    }
}

function M1-Thumbs {
    if (-not $global:DryRun) { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1 }
    Clear-Folder 'Cache de miniaturas' @("$env:SystemDrive\Users\*\AppData\Local\Microsoft\Windows\Explorer") 'thumbcache_*.db'
    Clear-Folder 'Cache de iconos'     @("$env:SystemDrive\Users\*\AppData\Local\Microsoft\Windows\Explorer") 'iconcache_*.db'
    if (-not $global:DryRun) { Start-ExplorerIfNeeded }
}

function M1-DNS { Step 'Limpiar cache DNS' { ipconfig /flushdns } }

# =====================================================================
#   MODULO 2: OPTIMIZACION Y LIBERACION DE MEMORIA RAM
# =====================================================================
function M2-Standby {
    Write-Section 'Liberar memoria en espera (Standby)'
    $b = Get-RamStatus
    Write-Host ('  Antes: RAM libre {0} GB de {1} GB  |  En espera: {2} MB' -f $b.Libre, $b.Total, (Get-StandbyMB))
    Step 'Vaciar lista de memoria modificada' { Initialize-MemTool; $r = [MemTool]::Purge(3); if ($r -ne 0) { throw ('NTSTATUS 0x{0:X8}' -f $r) } }
    Step 'Vaciar lista de memoria en espera (EmptyStandbyList)' { Initialize-MemTool; $r = [MemTool]::Purge(4); if ($r -ne 0) { throw ('NTSTATUS 0x{0:X8}' -f $r) } }
    if (-not $global:DryRun) {
        $a = Get-RamStatus
        Write-Host ('  Ahora: RAM libre {0} GB' -f $a.Libre) -ForegroundColor Green
        Write-Log ('RAM libre: ' + $b.Libre + ' GB -> ' + $a.Libre + ' GB')
    }
}

function M2-WorkingSets {
    Write-Section 'Vaciar memoria de trabajo de los procesos'
    Write-Host '  NOTA: Windows ya descarga solo las DLL que ningun programa usa; no existe un comando real' -ForegroundColor DarkGray
    Write-Host '        para "DLL huerfanas". Lo equivalente que si funciona es vaciar la memoria de trabajo:' -ForegroundColor DarkGray
    $b = Get-RamStatus
    Step 'Vaciar memoria de trabajo de todos los procesos' { Initialize-MemTool; $r = [MemTool]::Purge(2); if ($r -ne 0) { throw ('NTSTATUS 0x{0:X8}' -f $r) } }
    if (-not $global:DryRun) {
        $a = Get-RamStatus
        Write-Host ('  RAM libre: {0} GB -> {1} GB' -f $b.Libre, $a.Libre) -ForegroundColor Green
        Write-Log ('RAM libre: ' + $b.Libre + ' GB -> ' + $a.Libre + ' GB')
    }
}

function M2-Pagefile {
    Write-Section 'Archivo de paginacion (pagefile.sys)'
    $cs = Get-CimInstance Win32_ComputerSystem
    $u  = @(Get-CimInstance Win32_PageFileUsage)
    foreach ($p in $u) { Write-Host ('  {0}: tamano {1} MB, en uso {2} MB, pico {3} MB' -f $p.Name, $p.AllocatedBaseSize, $p.CurrentUsage, $p.PeakUsage) }
    if ($u.Count -eq 0) { Write-Host '  ATENCION: no hay archivo de paginacion. Los programas pueden cerrarse por falta de memoria.' -ForegroundColor Red }
    if ($cs.AutomaticManagedPagefile) {
        Write-Host '  Ya esta administrado automaticamente por Windows (configuracion recomendada).' -ForegroundColor Green
        Write-Log '[OK] Pagefile ya automatico'
        return
    }
    Write-Host '  Tiene un tamano manual. Lo recomendado es que Windows lo ajuste segun la necesidad.' -ForegroundColor Yellow
    if (Confirm-Action 'Cambiar a tamano administrado por Windows? (se aplica al reiniciar)' $true) {
        Step 'Paginacion administrada automaticamente' { $w = Get-WmiObject Win32_ComputerSystem; $w.AutomaticManagedPagefile = $true; [void]$w.Put() }
    }
}

$global:BloatProcs = @('CompatTelRunner', 'YourPhone', 'PhoneExperienceHost', 'GameBar', 'GameBarFTServer', 'Cortana',
    'SkypeApp', 'SkypeBackgroundHost', 'AdobeARM', 'AdobeCollabSync', 'CCXProcess', 'jusched', 'jucheck',
    'GoogleUpdate', 'MicrosoftEdgeUpdate', 'EpicGamesLauncher', 'EADesktop', 'Origin', 'Battle.net',
    'UbisoftConnect', 'upc', 'RiotClientServices', 'steam', 'Discord', 'Spotify')

function M2-KillBloat {
    Write-Section 'Cerrar procesos en segundo plano innecesarios'
    $names = $global:BloatProcs
    if ($global:Auto) {
        # En modo automatico no se cierran programas que el usuario puede estar usando
        $userApps = @('steam', 'Discord', 'Spotify', 'EpicGamesLauncher', 'EADesktop', 'Origin', 'Battle.net', 'UbisoftConnect', 'upc', 'RiotClientServices')
        $names = @($names | Where-Object { ($userApps) -notcontains ($_) })
    }
    $running = @(Get-Process -Name $names -ErrorAction SilentlyContinue | Group-Object ProcessName)
    if ($running.Count -eq 0) { Write-Host '  No hay procesos innecesarios abiertos.' -ForegroundColor Green; Write-Log 'Sin procesos bloatware'; return }
    foreach ($g in $running) {
        $mb = [math]::Round((($g.Group | Measure-Object WorkingSet64 -Sum).Sum) / 1MB)
        Write-Host ('   - {0,-25} {1,6} MB' -f $g.Name, $mb)
    }
    Write-Host '  NOTA: si el usuario esta usando alguno (Steam, Discord, Spotify...) responde N.' -ForegroundColor Yellow
    if (-not (Confirm-Action 'Cerrar todos los procesos de la lista?' $true)) { Write-Log '[OMITIDO] Cierre de procesos'; return }
    foreach ($g in $running) { $n = $g.Name; Step ('Cerrar ' + $n) { Stop-Process -Name $n -Force -ErrorAction Stop } }
}

function M2-ForegroundBoost {
    Step 'Dar mas tiempo de CPU al programa en primer plano' { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38 }
}

function M2-Priority {
    Write-Section 'Prioridad de procesos'
    M2-ForegroundBoost
    $apps = @(Get-Process | Where-Object { $_.MainWindowTitle -and $_.Id -ne $PID -and $_.ProcessName -ne 'explorer' } | Sort-Object WorkingSet64 -Descending)
    if ($apps.Count -eq 0) { return }
    Write-Host ''
    Write-Host '  Programas abiertos:'
    for ($i = 0; $i -lt $apps.Count; $i++) {
        $t = $apps[$i].MainWindowTitle; if ($t.Length -gt 45) { $t = $t.Substring(0, 45) + '...' }
        $pc = ''; try { $pc = $apps[$i].PriorityClass } catch {}
        Write-Host ('  {0,2}. {1,-22} {2,-50} {3}' -f ($i + 1), $apps[$i].ProcessName, $t, $pc)
    }
    $sel = Read-Host '  Numero del programa para subirle la prioridad a ALTA (ENTER para omitir)'
    $n = 0
    if ([int]::TryParse($sel, [ref]$n) -and $n -ge 1 -and $n -le $apps.Count) {
        $p = $apps[$n - 1]
        Step ('Prioridad ALTA para ' + $p.ProcessName + ' (hasta que se cierre)') { $p.PriorityClass = 'High' }
    }
}

function M2-Hibernate {
    Write-Section 'Hibernacion (hiberfil.sys)'
    $hf = "$env:SystemDrive\hiberfil.sys"
    if (Test-Path -LiteralPath $hf) {
        $size = (Get-Item -LiteralPath $hf -Force).Length
        Write-Host ('  hiberfil.sys ocupa ' + (Format-Size $size))
    } else { Write-Host '  La hibernacion esta desactivada (no existe hiberfil.sys).' }
    Write-Host '   1. Desactivar (libera todo el espacio, se pierde el "inicio rapido")'
    Write-Host '   2. Reducir (libera ~60% y mantiene el "inicio rapido")'
    Write-Host '   3. Activar completa'
    Write-Host '   0. No cambiar'
    switch (Read-Host '  Opcion') {
        '1' { Step 'Desactivar hibernacion' { powercfg /h off } }
        '2' { if (-not $global:IsWin10) { Show-NotSupported 'La hibernacion reducida'; return }; Step 'Hibernacion reducida' { powercfg /h on; powercfg /h /type reduced } }
        '3' { Step 'Activar hibernacion completa' { powercfg /h on; if ($global:IsWin10) { powercfg /h /type full } } }
        default { Write-Log '[OMITIDO] Hibernacion' }
    }
}

function M2-Timer {
    Write-Section 'Temporizador del sistema (HPET / PlatformClock)'
    Write-Host '  Forzar HPET (useplatformclock) AUMENTA la latencia en equipos modernos. Lo optimo es' -ForegroundColor DarkGray
    Write-Host '  quitar los valores forzados y dejar el temporizador por defecto de Windows.' -ForegroundColor DarkGray
    $cur = bcdedit /enum '{current}' | Out-String
    $found = $false
    foreach ($v in @('useplatformclock', 'useplatformtick', 'disabledynamictick')) {
        if ($cur -match $v) { $found = $true; Step ('bcdedit: quitar valor forzado ' + $v) { bcdedit /deletevalue $v } }
    }
    if (-not $found) { Write-Host '  Ya esta en la configuracion optima (sin valores forzados).' -ForegroundColor Green; Write-Log '[OK] Temporizador ya optimo' }
}

function M2-Clipboard {
    Step 'Vaciar portapapeles' { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::Clear() }
    if ($global:IsWin10) {
        Step 'Borrar historial del portapapeles (Win+V)' {
            $null = [Windows.ApplicationModel.DataTransfer.Clipboard, Windows.ApplicationModel.DataTransfer, ContentType = WindowsRuntime]
            $null = [Windows.ApplicationModel.DataTransfer.Clipboard]::ClearHistory()
        }
    }
}

function M2-Explorer {
    Step 'Reiniciar el Explorador de Windows' { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Start-ExplorerIfNeeded }
}

function M2-Leak {
    Write-Section 'Monitor de consumo de RAM (detector de fugas)'
    $total = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $rows = Get-Process | Group-Object ProcessName | ForEach-Object {
        $ws = ($_.Group | Measure-Object WorkingSet64 -Sum).Sum
        $pv = ($_.Group | Measure-Object PrivateMemorySize64 -Sum).Sum
        (New-Object PSObject -Property @{
            'Proceso'      = $_.Name
            'Instancias'   = $_.Count
            'RAM (MB)'     = [math]::Round($ws / 1MB)
            'Privada (MB)' = [math]::Round($pv / 1MB)
            '% RAM'        = [math]::Round($ws * 100 / $total, 1)
        })
    } | Sort-Object 'RAM (MB)' -Descending
    $rows | Select-Object -First 12 | Select-Object Proceso, Instancias, 'RAM (MB)', 'Privada (MB)', '% RAM' | Show-Table
    $heavy = @($rows | Where-Object { $_.'% RAM' -ge 20 })
    if ($heavy.Count -gt 0) {
        foreach ($h in $heavy) {
            Write-Host ('  ALERTA: {0} esta usando el {1}% de la RAM' -f $h.Proceso, $h.'% RAM') -ForegroundColor Red
            Write-Log ('[ALERTA] ' + $h.Proceso + ' usa ' + $h.'% RAM' + '% de RAM')
        }
    } else { Write-Host '  Ningun programa supera el 20% de la RAM.' -ForegroundColor Green }
    $os  = Get-CimInstance Win32_OperatingSystem
    $cpu = (Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
    $used = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
    Write-Host ('  Uso actual -> CPU: {0}%   RAM: {1} GB de {2} GB' -f $cpu, $used, [math]::Round($os.TotalVisibleMemorySize / 1MB, 1))
}

# =====================================================================
#   MODULO 3: REPARACION Y SALUD DEL SISTEMA
# =====================================================================
function M3-DISM {
    if (-not $global:IsWin8) { Show-NotSupported 'La reparacion con DISM'; Write-Host '  En Windows 7 se usa SFC, que es el siguiente paso.' -ForegroundColor DarkGray; return }
    Invoke-Live 'DISM: reparar imagen de Windows (10-30 min)' 'dism.exe' '/Online /Cleanup-Image /RestoreHealth'
    if (-not $global:DryRun) { $global:Results['DISM'] = $global:LastLive }
}
function M3-SFC {
    Invoke-Live 'SFC: verificar archivos del sistema' 'sfc.exe' '/scannow'
    if (-not $global:DryRun) { $global:Results['SFC'] = $global:LastLive }
}
function M3-Components {
    if (-not $global:IsWin8) { Show-NotSupported 'La limpieza de componentes de Windows'; return }
    Invoke-Live 'DISM: limpiar almacen de componentes' 'dism.exe' '/Online /Cleanup-Image /StartComponentCleanup'
}

function M3-Chkdsk {
    if ($global:IsWin8) { Invoke-Live 'CHKDSK: escaneo en linea de C: (sin reiniciar)' 'chkdsk.exe' "$env:SystemDrive /scan" }
    else { Invoke-Live 'CHKDSK: revision de solo lectura de C: (puede tardar)' 'chkdsk.exe' "$env:SystemDrive" }
    $code = $global:LastLive
    if (-not $global:DryRun) { $global:Results['CHKDSK'] = $code }
    $needs = ($null -ne $code -and $code -ge 3)
    if (($global:Auto -or $global:YesAll) -and -not $needs) { Write-Host '  Sin errores pendientes: no hace falta la reparacion completa.' -ForegroundColor Green; return }
    Write-Host '  NOTA: la reparacion completa se hace al reiniciar y puede tardar de 30 min a varias horas en discos grandes.' -ForegroundColor DarkGray
    Write-Host '        No apagues el equipo mientras se ejecuta.' -ForegroundColor DarkGray
    if (Confirm-Action 'Programar reparacion completa de sectores (chkdsk /f /r) en el proximo reinicio?' $needs) {
        $key = 'S'; if ((Get-UICulture).TwoLetterISOLanguageName -ne 'es') { $key = 'Y' }
        Step 'Programar CHKDSK /f /r al reiniciar' { cmd /c "echo $key| chkdsk $env:SystemDrive /f /r" }
        if (-not $global:DryRun) { $global:Results['CHKDSK_Programado'] = $true }
    }
}

function M3-Defrag {
    if ($global:IsWin8) { Invoke-Live 'Optimizar todas las unidades (SSD = TRIM, HDD = desfragmentar)' 'defrag.exe' '/C /O /U'; return }
    # Windows 7 no distingue los SSD al desfragmentar a mano: solo se analiza, para no desgastar un SSD
    Invoke-Live 'Analizar la fragmentacion de las unidades (Windows 7: solo analisis)' 'defrag.exe' '/C /A /U'
    Write-Host '  En Windows 7 solo se analiza. Si el disco es mecanico (HDD) y sale muy fragmentado,' -ForegroundColor DarkGray
    Write-Host '  desfragmentalo desde Propiedades del disco > Herramientas. NUNCA desfragmentes un SSD.' -ForegroundColor DarkGray
}

function M3-Network {
    Write-Section 'Restaurar la pila de red'
    Write-Host '  NOTA: si estas conectado por acceso remoto (AnyDesk, TeamViewer...) la conexion se cortara.' -ForegroundColor Yellow
    # Proteccion: "netsh int ip reset" BORRA las IP fijas. Si hay alguna, se guardan y NO se resetea TCP/IP.
    $static = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = TRUE' -ErrorAction SilentlyContinue |
                Where-Object { -not $_.DHCPEnabled -and @($_.IPAddress).Count -gt 0 })
    if ($static.Count -gt 0) {
        $ipFile = Join-Path $global:LogDir ('IP_fija_' + $env:COMPUTERNAME + '_' + (Get-Date -Format 'yyyy-MM-dd_HH-mm') + '.txt')
        ipconfig /all | Out-File -FilePath $ipFile -Encoding ASCII
        Write-Host '  ATENCION: este equipo tiene IP FIJA en:' -ForegroundColor Yellow
        foreach ($s in $static) {
            Write-Host ('   - {0}: IP {1}  Puerta de enlace {2}  DNS {3}' -f $s.Description, (@($s.IPAddress) -join ', '), (@($s.DefaultIPGateway) -join ', '), (@($s.DNSServerSearchOrder) -join ', ')) -ForegroundColor Yellow
        }
        Write-Host ('  Se guardo la configuracion en: ' + $ipFile) -ForegroundColor Yellow
        Write-Host '  Para no perder la IP fija, se hara solo la reparacion segura (DNS, Winsock), sin resetear TCP/IP.' -ForegroundColor Yellow
    }
    if (-not (Confirm-Action 'Continuar con el reinicio de red?' $false $true)) { Write-Log '[OMITIDO] Reinicio de red'; return }
    if ($static.Count -eq 0) { Step 'Liberar IP' { ipconfig /release } }
    Step 'Limpiar cache DNS'       { ipconfig /flushdns }
    Step 'Limpiar cache ARP'       { arp -d '*' }
    Step 'Limpiar cache NetBIOS'   { nbtstat -R }
    Step 'Reiniciar Winsock'       { netsh winsock reset }
    if ($static.Count -eq 0) {
        Step 'Reiniciar TCP/IP v4' { netsh int ip reset }
        Step 'Reiniciar TCP/IP v6' { netsh int ipv6 reset }
    }
    Step 'Ajuste automatico TCP'   { netsh int tcp set global autotuninglevel=normal }
    if ($static.Count -eq 0) { Step 'Renovar IP' { ipconfig /renew } }
    Write-Host '  Reinicia el equipo para completar el reinicio de red.' -ForegroundColor Yellow
}

function M3-Firewall {
    Write-Section 'Firewall de Windows'
    Write-Host '  NOTA: borra TODAS las reglas agregadas por programas (juegos, impresoras de red, sistemas' -ForegroundColor Yellow
    Write-Host '        de facturacion, servidores). Windows volvera a preguntar al abrirlos.' -ForegroundColor Yellow
    if (Confirm-Action 'Restablecer el firewall a valores de fabrica?' $false $true) { Step 'Restablecer firewall' { netsh advfirewall reset } }
    else { Write-Log '[OMITIDO] Firewall' }
}

function M3-Activation {
    Write-Section 'Estado de activacion de Windows'
    $map = @{ 0 = 'Sin licencia'; 1 = 'ACTIVADO'; 2 = 'Periodo de gracia'; 3 = 'Gracia adicional'; 4 = 'Gracia (no original)'; 5 = 'NO ACTIVADO (notificacion)'; 6 = 'Gracia extendida' }
    $lic = @(Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" -ErrorAction SilentlyContinue)
    foreach ($l in $lic) {
        $st = $map[[int]$l.LicenseStatus]
        $color = 'Yellow'; if ($l.LicenseStatus -eq 1) { $color = 'Green' }
        Write-Host ('  ' + $l.Name) ; Write-Host ('  Estado: ' + $st + '   Clave parcial: ' + $l.PartialProductKey) -ForegroundColor $color
        Write-Log ('Activacion: ' + $l.Name + ' - ' + $st)
    }
    if ($lic.Count -eq 0) { Write-Host '  No se encontro una licencia de Windows instalada.' -ForegroundColor Red; Write-Log 'Activacion: sin licencia' }
    cscript //nologo "$env:SystemRoot\System32\slmgr.vbs" /xpr | Out-String | Write-Host
}

function M3-GPUpdate {
    if (Get-Command gpupdate.exe -ErrorAction SilentlyContinue) { Invoke-Live 'Actualizar directivas de grupo' 'gpupdate.exe' '/force' }
    else { Write-Host '  gpupdate no esta disponible en esta edicion de Windows.'; Write-Log 'gpupdate no disponible' }
}

function M3-Services {
    Write-Section 'Reiniciar servicios esenciales'
    $list = @(
        @('Spooler', 'Cola de impresion'), @('wuauserv', 'Windows Update'), @('bits', 'Transferencia inteligente (BITS)'),
        @('cryptsvc', 'Servicios de cifrado'), @('Dhcp', 'Cliente DHCP'), @('NlaSvc', 'Reconocimiento de ubicacion de red'),
        @('Netman', 'Conexiones de red'), @('WlanSvc', 'WiFi'), @('Audiosrv', 'Audio de Windows'), @('Themes', 'Temas'))
    foreach ($s in $list) {
        $n = $s[0]
        $svc = Get-Service -Name $n -ErrorAction SilentlyContinue
        if ($svc -and (Get-SvcStartMode $n) -ne 'Disabled') { Step ('Reiniciar ' + $s[1]) { Restart-Service -Name $n -Force -ErrorAction Stop } }
    }
}

# =====================================================================
#   MODULO 4: RENDIMIENTO, CPU Y ARRANQUE
# =====================================================================
function M4-Power {
    Write-Section 'Plan de energia Maximo rendimiento'
    Step 'Activar plan de energia' {
        $guidRx = '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})'
        $guid = $null
        $line = powercfg /list | Where-Object { $_ -match 'Optimizador' } | Select-Object -First 1
        if ($line -and ($line -match $guidRx)) { $guid = $matches[1] }
        if (-not $guid) {
            $o = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-String
            if ($o -match $guidRx) { $guid = $matches[1]; powercfg -changename $guid 'Maximo rendimiento (Optimizador)' | Out-Null }
        }
        if ($guid) { powercfg -setactive $guid; Write-Host '     Plan "Maximo rendimiento" activado' -ForegroundColor Green }
        else { powercfg -setactive 8c5e7fd1-ce92-466d-be6a-fc4b47ae8f80; Write-Host '     Plan "Alto rendimiento" activado (este equipo no admite Maximo)' -ForegroundColor Green }
    }
    Step 'Procesador al 100% (enchufado)' {
        powercfg -setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 100
        powercfg -setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 100
    }
    Step 'No apagar discos, USB ni PCIe por ahorro' {
        powercfg -change -disk-timeout-ac 0
        powercfg -setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        powercfg -setacvalueindex scheme_current 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
        powercfg -setactive scheme_current
    }
    Step 'Quitar apps en segundo plano' { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1 }
    $bcd = bcdedit /enum '{current}' | Out-String
    if ($bcd -match 'numproc') { Step 'Usar todos los nucleos al arrancar' { bcdedit /deletevalue numproc } }
    M2-ForegroundBoost
}

function M4-Visual {
    Write-Section 'Efectos visuales en modo rendimiento'
    Step 'Efectos visuales: mejor rendimiento' {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2
        Set-Reg 'HKCU:\Control Panel\Desktop' 'UserPreferencesMask' ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) 'Binary'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
    }
    Step 'Quitar transparencias, animaciones y sombras' {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' 0
    }
    Write-Host '  Se aplica por completo al cerrar sesion o reiniciar.' -ForegroundColor DarkGray
}

function Get-StartupEntries {
    $base = 'HKCU:\Software\Microsoft\Windows\CurrentVersion'
    $lm   = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion'
    $src = @(
        @{ O = 'Usuario';        K = "$base\Run"; A = "$base\Explorer\StartupApproved\Run" },
        @{ O = 'Equipo';         K = "$lm\Run";   A = "$lm\Explorer\StartupApproved\Run" },
        @{ O = 'Equipo 32 bits'; K = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; A = "$lm\Explorer\StartupApproved\Run32" }
    )
    $list = @()
    foreach ($s in $src) {
        if (Test-Path $s.K) {
            $key = Get-Item -Path $s.K
            foreach ($n in $key.GetValueNames()) {
                if ($n) { $list += (New-Object PSObject -Property @{ Nombre = $n; Origen = $s.O; Comando = [string]$key.GetValue($n); Aprob = $s.A; Estado = 'Activo'; Tipo = 'Reg'; K = $s.K }) }
            }
        }
    }
    $folders = @(
        @{ O = 'Carpeta Inicio';         P = [Environment]::GetFolderPath('Startup');                                         A = "$base\Explorer\StartupApproved\StartupFolder" },
        @{ O = 'Carpeta Inicio (todos)'; P = (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\StartUp'); A = "$lm\Explorer\StartupApproved\StartupFolder" }
    )
    foreach ($f in $folders) {
        if ($f.P -and (Test-Path -LiteralPath $f.P)) {
            foreach ($file in @(Get-ChildItem -LiteralPath $f.P -File -Force -ErrorAction SilentlyContinue)) {
                if ($file.Name -ne 'desktop.ini') { $list += (New-Object PSObject -Property @{ Nombre = $file.Name; Origen = $f.O; Comando = $file.FullName; Aprob = $f.A; Estado = 'Activo'; Tipo = 'File'; K = $f.P }) }
            }
            # Windows 7: lo desactivado por MG Toolkit se guarda en una subcarpeta (Windows no la ejecuta)
            $off = Join-Path $f.P 'MGToolkit_Desactivados'
            if (-not $global:IsWin8 -and (Test-Path -LiteralPath $off)) {
                foreach ($file in @(Get-ChildItem -LiteralPath $off -File -Force -ErrorAction SilentlyContinue)) {
                    $list += (New-Object PSObject -Property @{ Nombre = $file.Name; Origen = $f.O; Comando = $file.FullName; Aprob = ''; Estado = 'DESACTIVADO'; Tipo = 'File'; K = $f.P })
                }
            }
        }
    }
    if ($global:IsWin8) {
        foreach ($e in $list) {
            $v = $null
            try { $v = (Get-ItemProperty -Path $e.Aprob -Name $e.Nombre -ErrorAction Stop).($e.Nombre) } catch {}
            if ($v -and $v.Length -gt 0 -and ($v[0] % 2) -eq 1) { $e.Estado = 'DESACTIVADO' }
        }
    } elseif (Test-Path $global:Win7StartupStore) {
        # Windows 7: entradas del registro desactivadas por MG Toolkit (guardadas para poder reactivarlas)
        $key = Get-Item -Path $global:Win7StartupStore
        foreach ($n in $key.GetValueNames()) {
            $parts = ([string]$key.GetValue($n)).Split([char]'|', 2)
            if ($parts.Length -eq 2) {
                $list += (New-Object PSObject -Property @{ Nombre = $n; Origen = 'Registro'; Comando = $parts[1]; Aprob = ''; Estado = 'DESACTIVADO'; Tipo = 'Reg'; K = $parts[0] })
            }
        }
    }
    return $list
}

function Set-StartupApproved($e, [bool]$enable) {
    if (($enable -and $e.Estado -eq 'Activo') -or (-not $enable -and $e.Estado -eq 'DESACTIVADO')) { return }
    if ($global:IsWin8) {
        if (-not (Test-Path $e.Aprob)) { New-Item -Path $e.Aprob -Force | Out-Null }
        $first = 3; if ($enable) { $first = 2 }
        New-ItemProperty -Path $e.Aprob -Name $e.Nombre -Value ([byte[]]@($first, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)) -PropertyType Binary -Force | Out-Null
        return
    }
    # Windows 7: se mueve la entrada a un lugar seguro y se puede devolver con "A numero"
    if ($e.Tipo -eq 'File') {
        $off = Join-Path $e.K 'MGToolkit_Desactivados'
        if ($enable) { Move-Item -LiteralPath $e.Comando -Destination (Join-Path $e.K $e.Nombre) -Force -ErrorAction Stop }
        else {
            if (-not (Test-Path -LiteralPath $off)) { New-Item -ItemType Directory -Path $off | Out-Null }
            Move-Item -LiteralPath $e.Comando -Destination (Join-Path $off $e.Nombre) -Force -ErrorAction Stop
        }
    } elseif ($enable) {
        New-ItemProperty -Path $e.K -Name $e.Nombre -Value $e.Comando -PropertyType String -Force -ErrorAction Stop | Out-Null
        Remove-ItemProperty -Path $global:Win7StartupStore -Name $e.Nombre -ErrorAction SilentlyContinue
    } else {
        if (-not (Test-Path $global:Win7StartupStore)) { New-Item -Path $global:Win7StartupStore -Force | Out-Null }
        New-ItemProperty -Path $global:Win7StartupStore -Name $e.Nombre -Value ($e.K + '|' + $e.Comando) -PropertyType String -Force -ErrorAction Stop | Out-Null
        Remove-ItemProperty -Path $e.K -Name $e.Nombre -ErrorAction Stop
    }
}
function Get-StartupTasks {
    if (-not (Test-Cmd 'Get-ScheduledTask')) { return @() }
    @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        $_.TaskPath -notlike '\Microsoft\*' -and
        @($_.Triggers | Where-Object { (@('MSFT_TaskLogonTrigger', 'MSFT_TaskBootTrigger')) -contains ($_.CimClass.CimClassName) }).Count -gt 0
    })
}

function M4-Startup {
    while ($true) {
        $entries = @(Get-StartupEntries)
        $tasks   = @(Get-StartupTasks)
        Write-Section 'Programas que arrancan con Windows'
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $e = $entries[$i]; $nm = $e.Nombre; if ($nm.Length -gt 40) { $nm = $nm.Substring(0, 40) }
            $color = 'White'; if ($e.Estado -ne 'Activo') { $color = 'DarkGray' }
            Write-Host ('  {0,3}. [{1,-11}] {2,-41} {3}' -f ($i + 1), $e.Estado, $nm, $e.Origen) -ForegroundColor $color
        }
        Write-Host ''
        Write-Host '  Tareas programadas que se ejecutan al iniciar (no son de Microsoft):' -ForegroundColor Cyan
        for ($j = 0; $j -lt $tasks.Count; $j++) {
            $t = $tasks[$j]
            $color = 'White'; if ($t.State -eq 'Disabled') { $color = 'DarkGray' }
            Write-Host ('  T{0,-2}. [{1,-11}] {2,-41} {3}' -f ($j + 1), $t.State, $t.TaskName, $t.TaskPath) -ForegroundColor $color
        }
        foreach ($ro in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce')) {
            if (Test-Path $ro) { foreach ($n in (Get-Item $ro).GetValueNames()) { if ($n) { Write-Host ('  RunOnce (se ejecuta una sola vez): ' + $n) -ForegroundColor DarkGray } } }
        }
        Write-Host ''
        Write-Host '  Comandos:  D 3  = desactivar el 3        A 3  = activar el 3       V 3 = ver comando'
        Write-Host '             TD 2 = desactivar la tarea 2  TA 2 = activar la tarea 2'
        Write-Host '             ENTER = volver'
        $c = Read-Host '  Comando'
        if (-not $c) { return }
        if ($c -match '^\s*(TD|TA|D|A|V)\s*(\d+)\s*$') {
            $cmd = $matches[1].ToUpper(); $n = [int]$matches[2]
            if ((@('D', 'A', 'V')) -contains ($cmd) -and ($n -lt 1 -or $n -gt $entries.Count)) { continue }
            if ((@('TD', 'TA')) -contains ($cmd) -and ($n -lt 1 -or $n -gt $tasks.Count)) { continue }
            switch ($cmd) {
                'D'  { $e = $entries[$n - 1]; Step ('Desactivar inicio: ' + $e.Nombre) { Set-StartupApproved $e $false } }
                'A'  { $e = $entries[$n - 1]; Step ('Activar inicio: ' + $e.Nombre) { Set-StartupApproved $e $true } }
                'V'  { Write-Host ('  ' + $entries[$n - 1].Comando) -ForegroundColor Yellow; Wait-Enter }
                'TD' { $t = $tasks[$n - 1]; Step ('Desactivar tarea: ' + $t.TaskName) { Disable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction Stop | Out-Null } }
                'TA' { $t = $tasks[$n - 1]; Step ('Activar tarea: ' + $t.TaskName) { Enable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction Stop | Out-Null } }
            }
        }
    }
}

function M4-Game {
    Write-Section 'Modo Juego y prioridad de GPU'
    if (-not $global:IsWin10) { Write-Host '  El Modo Juego y la programacion de GPU son de Windows 10/11: se omiten.' -ForegroundColor DarkGray }
    if ($global:IsWin10) {
    Step 'Activar Modo Juego' {
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
    }
    Step 'Programacion de GPU acelerada por hardware (si la tarjeta lo soporta)' {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2
    }
    }
    Step 'Prioridad alta de CPU y GPU para juegos y apps exigentes' {
        $mm = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        Set-Reg $mm 'SystemResponsiveness' 10
        Set-Reg "$mm\Tasks\Games" 'GPU Priority' 8
        Set-Reg "$mm\Tasks\Games" 'Priority' 6
        Set-Reg "$mm\Tasks\Games" 'Scheduling Category' 'High' 'String'
        Set-Reg "$mm\Tasks\Games" 'SFIO Priority' 'High' 'String'
    }
}

function M4-Telemetry {
    Write-Section 'Telemetria y diagnosticos'
    foreach ($s in @('DiagTrack', 'dmwappushservice')) {
        if (Get-Service -Name $s -ErrorAction SilentlyContinue) {
            Step ('Detener y deshabilitar servicio ' + $s) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue; Set-Service -Name $s -StartupType Disabled -ErrorAction Stop }
        }
    }
    Step 'Directiva: telemetria al minimo' { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0 }
    Step 'Desactivar Cortana' { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0 }
    Step 'Desactivar ID de publicidad' { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0 }
    Step 'Desactivar sugerencias y anuncios de Windows' {
        $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        foreach ($v in @('SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-353694Enabled', 'SystemPaneSuggestionsEnabled', 'SilentInstalledAppsEnabled')) { Set-Reg $cdm $v 0 }
    }
    $tasks = @(
        @('\Microsoft\Windows\Application Experience\', 'Microsoft Compatibility Appraiser'),
        @('\Microsoft\Windows\Application Experience\', 'ProgramDataUpdater'),
        @('\Microsoft\Windows\Customer Experience Improvement Program\', 'Consolidator'),
        @('\Microsoft\Windows\Customer Experience Improvement Program\', 'UsbCeip'),
        @('\Microsoft\Windows\DiskDiagnostic\', 'Microsoft-Windows-DiskDiagnosticDataCollector'))
    foreach ($t in $tasks) {
        $tp = $t[0]; $tn = $t[1]
        $null = schtasks.exe /Query /TN ($tp + $tn) 2>&1
        if ($LASTEXITCODE -eq 0) {
            Step ('Desactivar tarea de telemetria: ' + $tn) { schtasks.exe /Change /TN ($tp + $tn) /Disable }
        }
    }
}

function M4-Services {
    $svcs = @(
        @('XblAuthManager', 'Xbox Live: autenticacion'),
        @('XblGameSave', 'Xbox Live: partidas guardadas'),
        @('XboxNetApiSvc', 'Xbox Live: red'),
        @('XboxGipSvc', 'Xbox: accesorios'),
        @('DiagTrack', 'Telemetria de Microsoft'),
        @('dmwappushservice', 'Telemetria WAP Push'),
        @('MapsBroker', 'Mapas descargados'),
        @('RetailDemo', 'Modo demostracion de tienda'),
        @('Fax', 'Fax'),
        @('RemoteRegistry', 'Registro remoto'),
        @('lfsvc', 'Geolocalizacion'),
        @('PhoneSvc', 'Telefonia'),
        @('wisvc', 'Programa Windows Insider'),
        @('WSearch', 'Indexado de busqueda (pesado en HDD)'),
        @('SysMain', 'SysMain / Superfetch (pesado en HDD)'),
        @('Spooler', 'Cola de impresion (NO tocar si hay impresora)'),
        @('TabletInputService', 'Teclado tactil y escritura a mano'))
    while ($true) {
        Write-Section 'Control de servicios opcionales'
        for ($i = 0; $i -lt $svcs.Count; $i++) {
            $s = Get-Service -Name $svcs[$i][0] -ErrorAction SilentlyContinue
            if ($s) { $est = [string]$s.Status; $ini = Get-SvcStartMode $svcs[$i][0] } else { $est = 'No existe'; $ini = '' }
            Write-Host ('  {0,2}. {1,-46} {2,-10} {3}' -f ($i + 1), $svcs[$i][1], $est, $ini)
        }
        Write-Host ''
        Write-Host '  Comandos: 3 D = Deshabilitar   3 M = Manual   3 A = Automatico   ENTER = volver'
        Write-Host '  Si dudas, usa MANUAL: el servicio solo arranca cuando un programa lo necesita.' -ForegroundColor DarkGray
        $c = Read-Host '  Comando'
        if (-not $c) { return }
        if ($c -match '^\s*(\d+)\s*([DMAdma])\s*$') {
            $n = [int]$matches[1]; $m = $matches[2].ToUpper()
            if ($n -lt 1 -or $n -gt $svcs.Count) { continue }
            $name = $svcs[$n - 1][0]
            $type = 'Manual'; if ($m -eq 'D') { $type = 'Disabled' } elseif ($m -eq 'A') { $type = 'Automatic' }
            Step ('Servicio ' + $name + ' -> ' + $type) {
                if ($type -eq 'Disabled') { Stop-Service -Name $name -Force -ErrorAction SilentlyContinue }
                Set-Service -Name $name -StartupType $type -ErrorAction Stop
            }
        }
    }
}

# =====================================================================
#   EXTRAS
# =====================================================================
function X-Restore {
    Write-Section 'Punto de restauracion'
    Step 'Crear punto de restauracion del sistema' {
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 0
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description ('MG Toolkit ' +(Get-Date -Format 'yyyy-MM-dd HH:mm')) -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    }
}

function X-Info {
    Write-Section 'Informacion del equipo'
    $cs   = Get-CimInstance Win32_ComputerSystem
    $os   = Get-CimInstance Win32_OperatingSystem
    $cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
    $bios = Get-CimInstance Win32_BIOS
    $gpu  = (Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name }) -join ', '
    $slots = (Get-CimInstance Win32_PhysicalMemoryArray | Measure-Object MemoryDevices -Sum).Sum
    $mods = @(Get-CimInstance Win32_PhysicalMemory)
    $lines = @(
        ('  Equipo        : ' + $cs.Manufacturer + ' ' + $cs.Model),
        ('  No. de serie  : ' + $bios.SerialNumber),
        ('  Windows       : ' + $os.Caption + ' (build ' + $os.BuildNumber + ')'),
        ('  Procesador    : ' + $cpu.Name.Trim() + ' - ' + $cpu.NumberOfCores + ' nucleos / ' + $cpu.NumberOfLogicalProcessors + ' hilos'),
        ('  RAM total     : ' + [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) + ' GB  (' + $mods.Count + ' modulo(s) en ' + $slots + ' ranura(s))'),
        ('  Grafica       : ' + $gpu),
        ('  Encendido desde: ' + $os.LastBootUpTime))
    foreach ($l in $lines) { Write-Host $l; Write-Log $l }
    foreach ($m in $mods) { Write-Host ('     - {0} GB  {1} MHz  {2}' -f ($m.Capacity / 1GB), $m.Speed, $m.Manufacturer) }
    Write-Host ''
    Write-Host '  Discos fisicos:' -ForegroundColor Cyan
    if (Test-Cmd 'Get-PhysicalDisk') {
        Get-PhysicalDisk | Select-Object FriendlyName, MediaType, @{ n = 'Tamano (GB)'; e = { [math]::Round($_.Size / 1GB) } }, HealthStatus | Show-Table
    } else {
        Get-Win7Disks | Select-Object Disco, 'Tamano (GB)', Salud | Show-Table
    }
    try {
        Get-PhysicalDisk | Get-StorageReliabilityCounter -ErrorAction Stop |
            Select-Object @{ n = 'Disco'; e = { $_.DeviceId } }, @{ n = 'Desgaste %'; e = { $_.Wear } }, @{ n = 'Temp C'; e = { $_.Temperature } }, @{ n = 'Errores lectura'; e = { $_.ReadErrorsUncorrected } }, @{ n = 'Horas uso'; e = { $_.PowerOnHours } } | Show-Table
    } catch {}
    Write-Host '  Espacio en unidades:' -ForegroundColor Cyan
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Select-Object DeviceID,
        @{ n = 'Total (GB)'; e = { [math]::Round($_.Size / 1GB, 1) } },
        @{ n = 'Libre (GB)'; e = { [math]::Round($_.FreeSpace / 1GB, 1) } },
        @{ n = '% libre'; e = { [math]::Round($_.FreeSpace * 100 / $_.Size) } } | Show-Table
}

function X-Battery {
    Write-Section 'Reporte de bateria'
    if (-not (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)) { Write-Host '  Este equipo no tiene bateria.'; return }
    try {
        $design = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity
        $full   = (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
        if ($design -gt 0) {
            $health = [math]::Round($full * 100 / $design)
            $color = 'Green'; if ($health -lt 80) { $color = 'Yellow' }; if ($health -lt 50) { $color = 'Red' }
            Write-Host ('  Salud de la bateria: {0}%  (capacidad actual {1} mWh de {2} mWh de fabrica)' -f $health, $full, $design) -ForegroundColor $color
            Write-Log ('Bateria: ' + $health + '%')
        }
    } catch {}
    $out = Join-Path $global:LogDir ('reporte_bateria_' + (Get-Date -Format 'yyyy-MM-dd_HH-mm') + '.html')
    if (-not $global:IsWin8) { Show-NotSupported 'El reporte completo de bateria'; return }
    powercfg /batteryreport /output "$out" | Out-Null
    if (Test-Path -LiteralPath $out) { Write-Host ('  Reporte completo: ' + $out); Start-Process $out }
}

function X-Winget {
    Write-Section 'Actualizar todos los programas'
    if (-not $global:IsWin10) {
        Show-NotSupported 'La actualizacion automatica de programas (winget)'
        Write-Host '  Actualiza cada programa desde su menu Ayuda > Buscar actualizaciones o desde su pagina oficial.' -ForegroundColor DarkGray
        return
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host '  winget no esta instalado. Instala "Instalador de aplicacion" (App Installer) desde la Microsoft Store.' -ForegroundColor Yellow
        return
    }
    if ($global:DryRun) { winget upgrade --accept-source-agreements | Out-Host; Write-Log '[SIMULACION] winget upgrade --all'; return }
    Invoke-Live 'Actualizar programas con winget' 'winget' 'upgrade --all --accept-source-agreements --accept-package-agreements --silent'
}

function X-RamDiag {
    Write-Host '  Se abrira el Diagnostico de memoria. Elige "Reiniciar ahora y comprobar si hay problemas".'
    Write-Host '  El resultado aparece al volver a iniciar Windows.'
    Step 'Abrir diagnostico de memoria' { Start-Process mdsched.exe }
}

function X-Revert {
    Write-Section 'Deshacer cambios de rendimiento'
    Step 'Plan de energia Equilibrado' { powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e }
    Step 'Restaurar efectos visuales' {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 0
        Set-Reg 'HKCU:\Control Panel\Desktop' 'UserPreferencesMask' ([byte[]](0x9E, 0x1E, 0x07, 0x80, 0x12, 0x00, 0x00, 0x00)) 'Binary'
        Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '1' 'String'
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 1
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 1
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' 1
        Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' 1
    }
    Step 'Permitir apps en segundo plano' { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 0 }
    Step 'Programacion de GPU a valor de fabrica' { Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -ErrorAction SilentlyContinue }
    Step 'Reactivar servicio de telemetria (DiagTrack)' {
        Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -ErrorAction SilentlyContinue
        Set-Service -Name DiagTrack -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name DiagTrack -ErrorAction SilentlyContinue
    }
    Write-Host '  Los servicios cambiados en "Control de servicios" se restauran desde ese mismo menu.' -ForegroundColor DarkGray
}

# =====================================================================
#   ACCIONES RAPIDAS (PRESETS)
# =====================================================================
function Preset-Quick  { M1-UserTemp; M1-WinTemp; M1-WUCache; M1-Dumps; M1-Store; M1-Browsers; M1-Recycle; M1-DNS }
function Preset-RAM    { M2-KillBloat; M2-Clipboard; M2-Explorer; M2-WorkingSets; M2-Standby; M2-Leak }
function Preset-Repair { X-Restore; M3-DISM; M3-Components; M3-SFC; M3-Chkdsk; M3-Services; M3-Network; M3-Defrag }
# Todo en uno PREGUNTANDO: pregunta antes de cada paso (S / N / T = si a todo) y termina con el informe
function Preset-Guided {
    $global:Results = @{}
    $global:StepLog.Clear()
    $global:Results['Inicio']     = Get-Date
    $global:Results['LibreAntes'] = (Get-FreeBytes)
    $global:Results['RamAntes']   = (Get-RamStatus).Libre
    Write-Host ''
    Write-Host '  Se preguntara antes de cada paso. Responde:' -ForegroundColor Cyan
    Write-Host '     S = si     N = no (saltar este paso)     T = si a TODO lo que queda' -ForegroundColor Cyan
    Write-Host '  Las acciones delicadas (Prefetch, red, registro de seguridad, reiniciar) se preguntan siempre.' -ForegroundColor DarkGray
    $steps = @(
        @{ F = 'Analisis';        N = 'Analizar errores de los ultimos 30 dias';                     A = { Get-EventSummary } },
        @{ F = 'Respaldo';        N = 'Crear punto de restauracion';                                  A = { X-Restore } },
        @{ F = 'Seguridad';       N = 'Buscar virus con Defender (analisis rapido, 5-15 min)';        A = { T-DefenderQuick } },
        @{ F = 'Limpieza';        N = 'Borrar temporales de usuarios y de Windows';                   A = { M1-UserTemp; M1-WinTemp } },
        @{ F = 'Limpieza';        N = 'Borrar cache de Windows Update';                               A = { M1-WUCache } },
        @{ F = 'Limpieza';        N = 'Borrar volcados de memoria y reportes de error';               A = { M1-Dumps } },
        @{ F = 'Limpieza';        N = 'Borrar cache de apps de la Tienda';                            A = { M1-Store } },
        @{ F = 'Limpieza';        N = 'Borrar cache de navegadores';                                  A = { M1-Browsers } },
        @{ F = 'Limpieza';        N = 'Borrar cache de miniaturas e iconos (reinicia el Explorador)'; A = { M1-Thumbs } },
        @{ F = 'Limpieza';        N = 'Vaciar papelera de reciclaje';                                 A = { M1-Recycle } },
        @{ F = 'Limpieza';        N = 'Limpiar cache DNS';                                            A = { M1-DNS } },
        @{ F = 'Limpieza';        N = 'Borrar restos de instaladores (MSOCache, Adobe)';              A = { M1-Installers } },
        @{ F = 'Limpieza';        N = 'Borrar cache de Prefetch';                                     A = { M1-Prefetch } },
        @{ F = 'Limpieza';        N = 'Vaciar registros de eventos';                                  A = { M1-EventLogs } },
        @{ F = 'Memoria RAM';     N = 'Cerrar procesos innecesarios en segundo plano';                A = { M2-KillBloat } },
        @{ F = 'Memoria RAM';     N = 'Limpiar portapapeles e historial';                             A = { M2-Clipboard } },
        @{ F = 'Memoria RAM';     N = 'Liberar memoria RAM (procesos y memoria en espera)';           A = { M2-WorkingSets; M2-Standby } },
        @{ F = 'Rendimiento';     N = 'Plan de energia Maximo rendimiento + CPU al 100%';             A = { M4-Power } },
        @{ F = 'Rendimiento';     N = 'Quitar efectos visuales pesados';                              A = { M4-Visual } },
        @{ F = 'Rendimiento';     N = 'Modo Juego y prioridad de GPU';                                A = { M4-Game } },
        @{ F = 'Rendimiento';     N = 'Desactivar telemetria y anuncios';                             A = { M4-Telemetry } },
        @{ F = 'Rendimiento';     N = 'Revisar archivo de paginacion';                                A = { M2-Pagefile } },
        @{ F = 'Rendimiento';     N = 'Optimizar temporizador del sistema';                           A = { M2-Timer } },
        @{ F = 'Reparacion';      N = 'DISM: reparar imagen de Windows (10-30 min)';                  A = { M3-DISM } },
        @{ F = 'Reparacion';      N = 'Limpiar almacen de componentes de Windows';                    A = { M3-Components } },
        @{ F = 'Reparacion';      N = 'SFC: reparar archivos del sistema';                            A = { M3-SFC } },
        @{ F = 'Reparacion';      N = 'CHKDSK: revisar errores del disco';                            A = { M3-Chkdsk } },
        @{ F = 'Reparacion';      N = 'Reiniciar servicios (impresion, Update, red, audio)';          A = { M3-Services } },
        @{ F = 'Reparacion';      N = 'Optimizar discos (TRIM / desfragmentar)';                      A = { M3-Defrag } },
        @{ F = 'Reparacion';      N = 'Restaurar la pila de red (corta internet unos segundos)';      A = { M3-Network } },
        @{ F = 'Actualizaciones'; N = 'Instalar actualizaciones de Windows';                          A = { X-WindowsUpdate } },
        @{ F = 'Actualizaciones'; N = 'Actualizar todos los programas (winget)';                      A = { X-Winget } }
    )
    $fase = ''; $num = 0
    foreach ($s in $steps) {
        $num++
        if ($s.F -ne $fase) { $fase = $s.F; Write-Host ''; Write-Host ('>>> ' + $fase.ToUpper()) -ForegroundColor Magenta }
        if (Confirm-Action ('[' + $num + '/' + $steps.Count + '] ' + $s.N + '?')) { & $s.A }
        else { Write-Host '     (omitido)' -ForegroundColor DarkGray; Write-Log ('[OMITIDO] ' + $s.N) }
    }
    Complete-Run
}

# Cierre comun: informe final, instalar lo que falta y ofrecer reinicio
function Complete-Run {
    $global:Results['LibreDespues'] = (Get-FreeBytes)
    $global:Results['RamDespues']   = (Get-RamStatus).Libre
    New-Report
    Install-Missing
    if (-not $global:DryRun -and (Confirm-Action 'Reiniciar el equipo ahora para terminar de aplicar todo? (en 60 segundos)' $false $true)) {
        shutdown /r /t 60 /c "Reinicio de MG Toolkit. Para cancelar: shutdown /a"
        Write-Host '  El equipo se reiniciara en 60 segundos. Para cancelar escribe: shutdown /a' -ForegroundColor Yellow
    }
}

# =====================================================================
#   MENUS
# =====================================================================
# =====================================================================
#   WINDOWS UPDATE
# =====================================================================
$global:UpgradeCat = '3689bdc8-b205-4af4-8d4a-a63924c5e9d5'   # categoria "Upgrades" (cambios de version)

function Get-PendingUpdates {
    $s = New-Object -ComObject Microsoft.Update.Session
    $r = $s.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0 and Type='Software'")
    $list = @()
    foreach ($u in $r.Updates) {
        $isUpgrade = $false
        foreach ($c in $u.Categories) { if ($c.CategoryID -eq $global:UpgradeCat) { $isUpgrade = $true } }
        if (-not $isUpgrade) { $list += $u }
    }
    return $list
}

function X-WindowsUpdate {
    Write-Section 'Windows Update'
    Write-Host '  Buscando actualizaciones de Windows (puede tardar varios minutos)...'
    try { $ups = @(Get-PendingUpdates) }
    catch {
        $global:Errors++
        Write-Host ('  ERROR al buscar actualizaciones: ' + $_.Exception.Message) -ForegroundColor Red
        Write-Log ('[ERROR] Windows Update: ' + $_.Exception.Message)
        Add-Result 'ERROR' 'Buscar actualizaciones de Windows' $_.Exception.Message
        $global:Results['WU_Error'] = $_.Exception.Message
        return
    }
    if ($ups.Count -eq 0) { Write-Host '  Windows esta al dia.' -ForegroundColor Green; $global:Results['WU_Restantes'] = @(); return }
    foreach ($u in $ups) { Write-Host ('   - ' + $u.Title) }
    if ($global:DryRun) {
        Write-Host ('  [SIM] Se instalarian ' + $ups.Count + ' actualizacion(es)') -ForegroundColor DarkYellow
        $global:Results['WU_Restantes'] = @($ups | ForEach-Object { $_.Title })
        return
    }
    $coll = New-Object -ComObject Microsoft.Update.UpdateColl
    $skipped = @()
    foreach ($u in $ups) {
        if ($u.InstallationBehavior.CanRequestUserInput) { $skipped += $u.Title; continue }
        try { if (-not $u.EulaAccepted) { $u.AcceptEula() } } catch {}
        [void]$coll.Add($u)
    }
    if ($coll.Count -eq 0) { $global:Results['WU_Restantes'] = $skipped; return }
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        Write-Host ('  Descargando ' + $coll.Count + ' actualizacion(es)...')
        $d = $session.CreateUpdateDownloader(); $d.Updates = $coll; [void]$d.Download()
        Write-Host '  Instalando...'
        $i = $session.CreateUpdateInstaller(); $i.Updates = $coll; $r = $i.Install()
        $ok = @(); $fail = @()
        for ($k = 0; $k -lt $coll.Count; $k++) {
            $rc = $r.GetUpdateResult($k).ResultCode
            if ($rc -eq 2 -or $rc -eq 3) { $ok += $coll.Item($k).Title } else { $fail += $coll.Item($k).Title }
        }
        $global:Results['WU_Instaladas'] = $ok
        $global:Results['WU_Restantes']  = @($fail + $skipped)
        $global:Results['WU_Reinicio']   = [bool]$r.RebootRequired
        Write-Host ('  Instaladas: ' + $ok.Count + '   Fallidas: ' + $fail.Count) -ForegroundColor Green
        foreach ($t in $ok) { Write-Log ('[OK] Actualizacion instalada: ' + $t) }
        foreach ($t in $fail) { Write-Log ('[AVISO] Actualizacion fallida: ' + $t); Add-Result 'AVISO' 'Actualizacion de Windows' $t }
    } catch {
        $global:Errors++
        Write-Host ('  ERROR instalando actualizaciones: ' + $_.Exception.Message) -ForegroundColor Red
        Write-Log ('[ERROR] Windows Update: ' + $_.Exception.Message)
        Add-Result 'ERROR' 'Instalar actualizaciones de Windows' $_.Exception.Message
        $global:Results['WU_Restantes'] = @($ups | ForEach-Object { $_.Title })
    }
}

# =====================================================================
#   DIAGNOSTICO E INFORME FINAL
# =====================================================================
function Get-SiNo([bool]$b) { if ($b) { return 'Si' } return 'No' }

function Get-SevRank([string]$s) {
    switch ($s) { 'CRITICO' { return 0 } 'ATENCION' { return 1 } 'INFO' { return 2 } default { return 3 } }
}

function Add-Check([string]$cat, [string]$item, [string]$status, [string]$detail, [string]$rec = '') {
    [void]$global:Checks.Add((New-Object PSObject -Property @{ Categoria = $cat; Elemento = $item; Estado = $status; Detalle = $detail; Recomendacion = $rec }))
}

function Add-Missing([string]$name, [string]$id, [string]$rec) {
    [void]$global:Missing.Add((New-Object PSObject -Property @{ Nombre = $name; Id = $id; Rec = $rec }))
}

function Get-Ev([hashtable]$h) { try { return @(Get-WinEvent -FilterHashtable $h -ErrorAction Stop) } catch { return @() } }

function Get-EventSummary {
    Write-Host '  Analizando registros de eventos de los ultimos 30 dias...'
    $since = (Get-Date).AddDays(-30)
    $global:Results['Ev_BSOD']  = @(Get-Ev @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; Id = 1001; StartTime = $since }).Count
    $global:Results['Ev_Power'] = @(Get-Ev @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 41; StartTime = $since }).Count
    $disk = @(Get-Ev @{ LogName = 'System'; ProviderName = 'disk'; Id = @(7, 11, 51, 153); StartTime = $since })
    $disk += @(Get-Ev @{ LogName = 'System'; ProviderName = 'Ntfs'; Id = 55; StartTime = $since })
    $disk += @(Get-Ev @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Ntfs'; Id = 55; StartTime = $since })
    $global:Results['Ev_Disk']  = $disk.Count
    $global:Results['Ev_WHEA']  = @(Get-Ev @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'; Level = @(1, 2); StartTime = $since }).Count
    $crash = @(Get-Ev @{ LogName = 'Application'; ProviderName = 'Application Error'; Id = 1000; StartTime = $since })
    $global:Results['Ev_AppCount'] = $crash.Count
    $global:Results['Ev_AppTop'] = (@($crash | ForEach-Object { [string]$_.Properties[0].Value } | Group-Object | Sort-Object Count -Descending | Select-Object -First 4 | ForEach-Object { $_.Name + ' (' + $_.Count + ')' }) -join ', ')
    $global:Results['Ev_Done'] = $true
}

function Get-BatteryHealth {
    try {
        if (-not (Get-CimInstance Win32_Battery -ErrorAction Stop)) { return $null }
        $design = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity
        $full   = (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
        if ($design -gt 0) { return [math]::Round($full * 100 / $design) }
    } catch {}
    return $null
}

function Get-Diagnostics {
    $global:Checks  = New-Object System.Collections.ArrayList
    $global:Missing = New-Object System.Collections.ArrayList
    if (-not $global:Results.ContainsKey('Ev_Done')) { Get-EventSummary }
    Write-Host '  Revisando Windows, seguridad, hardware, drivers y programas...'
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int]$os.BuildNumber
    $ver = [string]$cv.DisplayVersion; if (-not $ver) { $ver = [string]$cv.ReleaseId }; if (-not $ver) { $ver = [string]$os.CSDVersion }
    $ubr = ''; if ($cv.UBR) { $ubr = '.' + $cv.UBR }
    $verTxt = $os.Caption + ' ' + $ver + ' (build ' + $build + $ubr + ')'

    # ------------------------- WINDOWS -------------------------
    if ($build -lt 22000) {
        $why = 'Windows 10 ya no recibe parches de seguridad gratuitos (fin de soporte oct. 2025; ESU hogar hasta oct. 2026). Pasar a Windows 11 si el equipo es compatible.'
        if ($build -lt 10240) { $why = $global:WinName + ' no recibe parches de seguridad desde hace anos (Windows 7: 2020, Windows 8/8.1: 2023). Es peligroso usarlo en internet: pasar a Windows 11 si el equipo es compatible, o renovar el equipo.' }
        Add-Check 'Windows' 'Version de Windows' 'CRITICO' $verTxt $why
        $tpm2 = $false
        try {
            $tpm = Get-CimInstance -Namespace 'root\cimv2\security\microsofttpm' -ClassName Win32_Tpm -ErrorAction Stop
            if ($tpm -and ([string]$tpm.SpecVersion).StartsWith('2.0')) { $tpm2 = $true }
        } catch {}
        $uefi = $false; $secBoot = $false
        try { $secBoot = [bool](Confirm-SecureBootUEFI -ErrorAction Stop); $uefi = $true } catch {}
        $ram4 = ($cs.TotalPhysicalMemory -ge 3.8GB)
        $det = 'TPM 2.0: ' + (Get-SiNo $tpm2) + ' | UEFI: ' + (Get-SiNo $uefi) + ' | Secure Boot activo: ' + (Get-SiNo $secBoot) + ' | RAM 4 GB+: ' + (Get-SiNo $ram4)
        if ($tpm2 -and $uefi -and $ram4) {
            Add-Check 'Windows' 'Compatibilidad con Windows 11' 'INFO' $det 'Cumple TPM/UEFI/RAM. Confirmar el procesador con la app "Comprobacion de estado del PC" y actualizar desde Windows Update.'
        } else {
            Add-Check 'Windows' 'Compatibilidad con Windows 11' 'ATENCION' $det 'No cumple todos los requisitos. Revisar si TPM o UEFI se pueden activar en la BIOS; si no, considerar renovar el equipo.'
        }
    } elseif ($build -lt 26200) {
        Add-Check 'Windows' 'Version de Windows' 'ATENCION' $verTxt 'Version de Windows 11 antigua, puede estar fuera de soporte. Instalar la ultima version desde Windows Update.'
    } else {
        Add-Check 'Windows' 'Version de Windows' 'OK' $verTxt
    }

    $lic = @(Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" -ErrorAction SilentlyContinue)
    if (@($lic | Where-Object { $_.LicenseStatus -eq 1 }).Count -gt 0) { Add-Check 'Windows' 'Activacion' 'OK' 'Windows activado' }
    else { Add-Check 'Windows' 'Activacion' 'CRITICO' 'Windows NO esta activado' 'Activar Windows con una licencia original (Configuracion > Activacion).' }

    $wu = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
    if ($wu -and (Get-SvcStartMode 'wuauserv') -eq 'Disabled') { Add-Check 'Windows' 'Servicio Windows Update' 'CRITICO' 'Deshabilitado' 'Volver a habilitarlo: sin el, Windows no recibe parches de seguridad.' }
    if (-not $global:Results.ContainsKey('WU_Restantes') -and -not $global:Results.ContainsKey('WU_Error')) {
        Write-Host '  Consultando actualizaciones pendientes (puede tardar)...'
        try { $global:Results['WU_Restantes'] = @(Get-PendingUpdates | ForEach-Object { $_.Title }) }
        catch { $global:Results['WU_Error'] = $_.Exception.Message }
    }
    if ($global:Results.ContainsKey('WU_Error')) {
        Add-Check 'Windows' 'Actualizaciones' 'ATENCION' ('No se pudo consultar Windows Update: ' + $global:Results['WU_Error']) 'Abrir Configuracion > Windows Update y buscar actualizaciones manualmente.'
    } else {
        $rest = @($global:Results['WU_Restantes'])
        if ($rest.Count -eq 0) { Add-Check 'Windows' 'Actualizaciones' 'OK' 'Al dia' }
        else { Add-Check 'Windows' 'Actualizaciones' 'ATENCION' ([string]$rest.Count + ' pendiente(s): ' + ($rest -join '; ')) 'Instalar desde Configuracion > Windows Update (o volver a ejecutar el modo automatico).' }
    }

    $pend = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
            (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
            [bool](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
    if ($pend -or $global:Results['WU_Reinicio']) { Add-Check 'Windows' 'Reinicio pendiente' 'ATENCION' 'Hay cambios esperando un reinicio' 'Reiniciar el equipo para terminar de aplicar actualizaciones y reparaciones.' }

    $rp = @(Get-ComputerRestorePoint -ErrorAction SilentlyContinue)
    if ($rp.Count -gt 0) { Add-Check 'Windows' 'Puntos de restauracion' 'OK' ([string]$rp.Count + ' punto(s) disponibles') }
    else { Add-Check 'Windows' 'Puntos de restauracion' 'ATENCION' 'No hay puntos de restauracion' 'Activar Proteccion del sistema en C: y crear un punto (menu Extras).' }

    # ------------------------- SEGURIDAD -------------------------
    $avList = @()
    foreach ($a in @(Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue)) {
        $hex = '{0:X6}' -f [int]$a.productState
        $avList += (New-Object PSObject -Property @{ N = $a.displayName; On = ((@('10', '11')) -contains ($hex.Substring(2, 2))); Upd = ($hex.Substring(4, 2) -eq '00') })
    }
    $good = @($avList | Where-Object { $_.On -and $_.Upd })
    $on   = @($avList | Where-Object { $_.On })
    if ($good.Count -gt 0) { $d = (($good | ForEach-Object { $_.N }) -join ', ') + ' (activo y actualizado)'; Add-Check 'Seguridad' 'Antivirus' 'OK' $d }
    elseif ($on.Count -gt 0) { $d = (($on | ForEach-Object { $_.N }) -join ', ') + ' (desactualizado)'; Add-Check 'Seguridad' 'Antivirus' 'ATENCION' $d 'Actualizar las firmas del antivirus.' }
    else { Add-Check 'Seguridad' 'Antivirus' 'CRITICO' 'Ningun antivirus activo' 'Activar Microsoft Defender (Seguridad de Windows) o instalar un antivirus.' }
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        if ($mp.AntivirusEnabled -and $mp.AntivirusSignatureAge -gt 3) { Add-Check 'Seguridad' 'Firmas de Defender' 'ATENCION' ('Firmas con ' + $mp.AntivirusSignatureAge + ' dias de antiguedad') 'Actualizar Defender desde Windows Update.' }
        if ($mp.AntivirusEnabled -and -not $mp.RealTimeProtectionEnabled) { Add-Check 'Seguridad' 'Proteccion en tiempo real' 'CRITICO' 'Desactivada' 'Activarla en Seguridad de Windows > Proteccion antivirus.' }
    } catch {}
    try {
        $det = @(Get-MpThreatDetection -ErrorAction Stop | Where-Object { $_.InitialDetectionTime -ge (Get-Date).AddDays(-30) })
        $notOk = @($det | Where-Object { -not $_.ActionSuccess })
        if ($notOk.Count -gt 0) { Add-Check 'Seguridad' 'Virus (30 dias)' 'CRITICO' ([string]$notOk.Count + ' amenaza(s) que Defender NO pudo eliminar') 'Ejecutar "Buscar virus" > Analisis sin conexion.' }
        elseif ($det.Count -gt 0) { Add-Check 'Seguridad' 'Virus (30 dias)' 'INFO' ([string]$det.Count + ' amenaza(s) detectada(s) y eliminada(s)') 'Revisar de donde vinieron (descargas, USB) y hacer un analisis completo.' }
        else { Add-Check 'Seguridad' 'Virus (30 dias)' 'OK' 'No se detectaron amenazas' }
    } catch {}
    $fwOff = @()
    foreach ($fp in @(@('Dominio', 'DomainProfile'), @('Privado', 'StandardProfile'), @('Publico', 'PublicProfile'))) {
        $en = (Get-ItemProperty ('HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\' + $fp[1]) -Name EnableFirewall -ErrorAction SilentlyContinue).EnableFirewall
        if ($en -eq 0) { $fwOff += (New-Object PSObject -Property @{ Name = $fp[0] }) }
    }
    if ($fwOff.Count -gt 0) { $d = 'Desactivado en: ' + (($fwOff | ForEach-Object { $_.Name }) -join ', '); Add-Check 'Seguridad' 'Firewall' 'ATENCION' $d 'Activar el firewall de Windows (salvo que haya otro firewall instalado).' }
    else { Add-Check 'Seguridad' 'Firewall' 'OK' 'Activo en todos los perfiles' }
    $hostsN = @(Get-HostsEntries).Count
    if ($hostsN -gt 0) { Add-Check 'Seguridad' 'Archivo hosts' 'ATENCION' ([string]$hostsN + ' redireccion(es) en el archivo hosts') 'Revisar con la opcion 46: algunos virus lo usan para llevar a paginas falsas.' }
    else { Add-Check 'Seguridad' 'Archivo hosts' 'OK' 'Sin redirecciones' }
    $px = Get-ProxyState
    if ($px.Enabled -or $px.Pac) { Add-Check 'Seguridad' 'Proxy' 'ATENCION' ('Proxy activo: ' + $px.Server + ' ' + $px.Pac) 'Si el equipo no es de una empresa, puede ser publicidad (adware): quitarlo con la opcion 47.' }
    if (Get-SafeBootState) { Add-Check 'Windows' 'Modo seguro' 'ATENCION' 'El equipo arranca siempre en modo seguro' 'Volver al inicio normal con la opcion 52 > 3.' }
    $lua = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -ErrorAction SilentlyContinue).EnableLUA
    if ($lua -eq 0) { Add-Check 'Seguridad' 'Control de cuentas (UAC)' 'CRITICO' 'Desactivado' 'Activar UAC: protege contra programas maliciosos.' }

    # ------------------------- HARDWARE -------------------------
    $ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    $mods  = @(Get-CimInstance Win32_PhysicalMemory)
    $slots = (Get-CimInstance Win32_PhysicalMemoryArray | Measure-Object MemoryDevices -Sum).Sum
    $ramDet = ('{0} GB ({1} modulo(s) en {2} ranura(s))' -f $ramGB, $mods.Count, $slots)
    $slotTip = ''; if ($slots -gt $mods.Count) { $slotTip = ' Hay ranuras libres para ampliar.' }
    if ($ramGB -lt 3.8)     { Add-Check 'Hardware' 'Memoria RAM' 'CRITICO'  $ramDet ('Muy poca RAM: ampliar a 8 GB como minimo.' + $slotTip) }
    elseif ($ramGB -lt 7.5) { Add-Check 'Hardware' 'Memoria RAM' 'ATENCION' $ramDet ('Se recomiendan 8 GB o mas (16 GB para uso exigente).' + $slotTip) }
    else                    { Add-Check 'Hardware' 'Memoria RAM' 'OK' $ramDet }

    $sysDisk = $null
    try { $sysDisk = (Get-Partition -DriveLetter ($env:SystemDrive.TrimEnd(':')) -ErrorAction Stop).DiskNumber } catch {}
    $pdList = @(); if (Test-Cmd 'Get-PhysicalDisk') { $pdList = @(Get-PhysicalDisk -ErrorAction SilentlyContinue) }
    foreach ($pd in $pdList) {
        $type = [string]$pd.MediaType
        if ($type -ne 'HDD' -and $type -ne 'SSD') { if ([string]$pd.BusType -eq 'NVMe' -or $pd.SpindleSpeed -eq 0) { $type = 'SSD' } else { $type = 'desconocido' } }
        $dn = $pd.FriendlyName + ' (' + $type + ', ' + [math]::Round($pd.Size / 1GB) + ' GB)'
        if ([string]$pd.HealthStatus -ne 'Healthy') { Add-Check 'Hardware' 'Salud del disco' 'CRITICO' ($dn + ': ' + $pd.HealthStatus) 'El disco esta fallando: respaldar los datos YA y reemplazarlo.' }
        else { Add-Check 'Hardware' 'Salud del disco' 'OK' ($dn + ': saludable') }
        if ($null -ne $sysDisk -and [string]$pd.DeviceId -eq [string]$sysDisk) {
            if ($type -eq 'HDD') { Add-Check 'Hardware' 'Disco de Windows' 'CRITICO' ($dn + ' - disco mecanico') 'Windows esta en un disco mecanico (HDD). Cambiarlo por un SSD es la mejora de velocidad mas grande posible.' }
            else { Add-Check 'Hardware' 'Disco de Windows' 'OK' $dn }
        }
        try {
            $rc = $pd | Get-StorageReliabilityCounter -ErrorAction Stop
            if ($rc.Wear -ge 80) { Add-Check 'Hardware' 'Desgaste del SSD' 'CRITICO' ($pd.FriendlyName + ': ' + $rc.Wear + '% de vida usada') 'Planificar el reemplazo del disco y mantener respaldos.' }
            elseif ($rc.Wear -ge 50) { Add-Check 'Hardware' 'Desgaste del SSD' 'ATENCION' ($pd.FriendlyName + ': ' + $rc.Wear + '% de vida usada') 'Mantener respaldos al dia.' }
            if ($rc.Temperature -ge 60) { Add-Check 'Hardware' 'Temperatura del disco' 'ATENCION' ($pd.FriendlyName + ': ' + $rc.Temperature + ' C') 'Mejorar la ventilacion del equipo.' }
        } catch {}
    }

    if ($pdList.Count -eq 0) {
        foreach ($d in @(Get-Win7Disks)) {
            $dn = $d.Disco + ' (' + $d.'Tamano (GB)' + ' GB)'
            if ($d.Falla) { Add-Check 'Hardware' 'Salud del disco' 'CRITICO' ($dn + ': ' + $d.Salud) 'El disco esta fallando: respaldar los datos YA y reemplazarlo.' }
            else { Add-Check 'Hardware' 'Salud del disco' 'OK' ($dn + ': saludable') }
        }
        Add-Check 'Hardware' 'Tipo de disco' 'INFO' ('En ' + $global:WinName + ' no se puede saber si es SSD o HDD') 'Usa "Medir velocidad del disco": si sale LENTO es un disco mecanico y conviene cambiarlo por un SSD.'
    }
    $c = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='" + $env:SystemDrive + "'")
    $pct = [math]::Round($c.FreeSpace * 100 / $c.Size); $freeGB = [math]::Round($c.FreeSpace / 1GB, 1)
    $d = ('{0} GB libres ({1}%)' -f $freeGB, $pct)
    if ($freeGB -lt 10 -or $pct -lt 5)       { Add-Check 'Hardware' ('Espacio en ' + $env:SystemDrive) 'CRITICO'  $d 'Liberar espacio: desinstalar programas, mover archivos a otro disco o usar un disco mas grande.' }
    elseif ($freeGB -lt 25 -or $pct -lt 15)  { Add-Check 'Hardware' ('Espacio en ' + $env:SystemDrive) 'ATENCION' $d 'Poco espacio: Windows necesita al menos 15-20% libre para actualizarse y funcionar bien.' }
    else                                     { Add-Check 'Hardware' ('Espacio en ' + $env:SystemDrive) 'OK' $d }

    $bad = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.ConfigManagerErrorCode -and (@(0, 22, 45)) -notcontains ($_.ConfigManagerErrorCode) })
    $noDrv = @($bad | Where-Object { $_.ConfigManagerErrorCode -eq 28 })
    $other = @($bad | Where-Object { $_.ConfigManagerErrorCode -ne 28 })
    if ($noDrv.Count -gt 0) {
        $d = (($noDrv | ForEach-Object { if ($_.Name) { $_.Name } else { $_.DeviceID } }) -join '; ')
        Add-Check 'Drivers' 'Drivers faltantes' 'CRITICO' $d 'Instalar los drivers desde la web de soporte del fabricante (buscar el modelo) o con su utilidad: Lenovo Vantage, HP Support Assistant, Dell SupportAssist, MyASUS, Acer Care Center.'
    }
    if ($other.Count -gt 0) {
        $d = (($other | ForEach-Object { $_.Name + ' (codigo ' + $_.ConfigManagerErrorCode + ')' }) -join '; ')
        Add-Check 'Drivers' 'Dispositivos con error' 'ATENCION' $d 'Revisar en el Administrador de dispositivos y reinstalar el driver.'
    }
    if ($bad.Count -eq 0) { Add-Check 'Drivers' 'Dispositivos' 'OK' 'Todos los dispositivos tienen driver y funcionan' }

    foreach ($g in @(Get-CimInstance Win32_VideoController)) {
        if ($g.Name -match 'Basic Display|Basic Render|pantalla b.sico|Standard VGA|VGA est.ndar') {
            Add-Check 'Drivers' 'Driver de video' 'CRITICO' $g.Name 'Falta el driver de la tarjeta grafica: instalarlo desde Intel / AMD / NVIDIA o desde la web del fabricante del equipo.'
        } elseif ($g.DriverDate -and $g.DriverDate -lt (Get-Date).AddYears(-2)) {
            Add-Check 'Drivers' 'Driver de video' 'ATENCION' ($g.Name + ' - driver del ' + $g.DriverDate.ToString('dd/MM/yyyy')) 'Driver de video antiguo: actualizarlo desde la web del fabricante.'
        } else {
            Add-Check 'Drivers' 'Driver de video' 'OK' ($g.Name + ' - driver ' + $g.DriverVersion)
        }
    }

    $bios = Get-CimInstance Win32_BIOS
    if ($bios.ReleaseDate -and $bios.ReleaseDate -lt (Get-Date).AddYears(-4)) {
        Add-Check 'Drivers' 'BIOS / UEFI' 'INFO' ('Version ' + $bios.SMBIOSBIOSVersion + ' del ' + $bios.ReleaseDate.ToString('dd/MM/yyyy')) 'BIOS antigua: revisar si el fabricante tiene una actualizacion (mejoras de estabilidad y seguridad).'
    }

    $bh = Get-BatteryHealth
    if ($null -ne $bh) {
        $d = 'Capacidad al ' + $bh + '% de la original'
        if ($bh -lt 50)     { Add-Check 'Hardware' 'Bateria' 'CRITICO'  $d 'Bateria muy desgastada: reemplazarla.' }
        elseif ($bh -lt 80) { Add-Check 'Hardware' 'Bateria' 'ATENCION' $d 'Bateria desgastada: considerar reemplazo.' }
        else                { Add-Check 'Hardware' 'Bateria' 'OK' $d }
    }

    # ------------------------- ESTABILIDAD -------------------------
    $n = [int]$global:Results['Ev_BSOD']
    if ($n -gt 0) { Add-Check 'Estabilidad' 'Pantallas azules (30 dias)' 'CRITICO' ([string]$n + ' pantalla(s) azul(es)') 'Revisar drivers, RAM (diagnostico de memoria) y temperatura. Analizar los .dmp con BlueScreenView o WinDbg.' }
    else { Add-Check 'Estabilidad' 'Pantallas azules (30 dias)' 'OK' 'Ninguna' }
    $n = [int]$global:Results['Ev_Power']
    if ($n -gt 2)     { Add-Check 'Estabilidad' 'Apagados inesperados (30 dias)' 'ATENCION' ([string]$n + ' apagado(s) sin cerrar Windows') 'Cortes de luz, apagado forzado con el boton o fallas de fuente/temperatura. Considerar un UPS o regulador.' }
    elseif ($n -gt 0) { Add-Check 'Estabilidad' 'Apagados inesperados (30 dias)' 'INFO' ([string]$n + ' apagado(s) sin cerrar Windows') 'Evitar apagar con el boton de encendido.' }
    else              { Add-Check 'Estabilidad' 'Apagados inesperados (30 dias)' 'OK' 'Ninguno' }
    $n = [int]$global:Results['Ev_Disk']
    if ($n -gt 0) { Add-Check 'Estabilidad' 'Errores de disco (30 dias)' 'CRITICO' ([string]$n + ' error(es) de lectura/escritura o del sistema de archivos') 'Si hay memorias USB o discos externos, pueden venir de ellos (desconectarlos sin expulsar). Si no, respaldar los datos, ejecutar CHKDSK /f /r y revisar la salud del disco: puede estar fallando.' }
    else { Add-Check 'Estabilidad' 'Errores de disco (30 dias)' 'OK' 'Ninguno' }
    $n = [int]$global:Results['Ev_WHEA']
    if ($n -gt 0) { Add-Check 'Estabilidad' 'Errores de hardware WHEA (30 dias)' 'CRITICO' ([string]$n + ' error(es) de procesador/RAM/PCIe') 'Revisar temperaturas, probar la RAM y quitar cualquier overclock.' }
    $n = [int]$global:Results['Ev_AppCount']
    if ($n -gt 10)    { Add-Check 'Estabilidad' 'Programas que se cierran solos' 'ATENCION' ([string]$n + ' cierres: ' + $global:Results['Ev_AppTop']) 'Actualizar o reinstalar esos programas.' }
    elseif ($n -gt 0) { Add-Check 'Estabilidad' 'Programas que se cierran solos' 'INFO' ([string]$n + ' cierres: ' + $global:Results['Ev_AppTop']) }

    if ($global:Results.ContainsKey('DISM')) {
        if ($global:Results['DISM'] -eq 0) { Add-Check 'Estabilidad' 'Imagen de Windows (DISM)' 'OK' 'Sin danos o reparada' }
        else { Add-Check 'Estabilidad' 'Imagen de Windows (DISM)' 'CRITICO' ('DISM termino con codigo ' + $global:Results['DISM']) 'Revisar internet y repetir; si sigue fallando, reparar Windows con una actualizacion en sitio desde la ISO oficial (conserva archivos y programas).' }
    }
    if ($global:Results.ContainsKey('SFC')) {
        $today = Get-Date -Format 'yyyy-MM-dd'
        $lines = @(Get-Content -LiteralPath "$env:SystemRoot\Logs\CBS\CBS.log" -Tail 30000 -ErrorAction SilentlyContinue | Where-Object { $_.StartsWith($today) -and $_.Contains('[SR]') })
        $cannot   = @($lines | Where-Object { $_.Contains('Cannot repair') }).Count
        $repaired = @($lines | Where-Object { $_.Contains('Repairing corrupted file') -or $_.Contains('Repaired file') }).Count
        if ($cannot -gt 0)       { Add-Check 'Estabilidad' 'Archivos del sistema (SFC)' 'CRITICO' ([string]$cannot + ' archivo(s) danado(s) sin reparar') 'Reiniciar y volver a ejecutar DISM + SFC; si persiste, actualizacion en sitio desde la ISO oficial.' }
        elseif ($repaired -gt 0) { Add-Check 'Estabilidad' 'Archivos del sistema (SFC)' 'INFO' ([string]$repaired + ' archivo(s) danado(s) reparado(s)') 'Reiniciar para completar la reparacion.' }
        else                     { Add-Check 'Estabilidad' 'Archivos del sistema (SFC)' 'OK' 'Sin archivos danados' }
    }
    if ($global:Results.ContainsKey('CHKDSK')) {
        if ($global:Results['CHKDSK_Programado']) { Add-Check 'Estabilidad' 'Sistema de archivos (CHKDSK)' 'ATENCION' 'Se encontraron errores; reparacion programada' 'Reiniciar y dejar que CHKDSK termine (puede tardar).' }
        elseif ($global:Results['CHKDSK'] -le 2) { Add-Check 'Estabilidad' 'Sistema de archivos (CHKDSK)' 'OK' 'Sin errores' }
        else { Add-Check 'Estabilidad' 'Sistema de archivos (CHKDSK)' 'ATENCION' ('CHKDSK termino con codigo ' + $global:Results['CHKDSK']) 'Programar chkdsk /f /r (Modulo 3).' }
    }

    # ------------------------- RENDIMIENTO -------------------------
    $plan = (powercfg /getactivescheme | Out-String).Trim()
    $planName = $plan; if ($plan -match '\((.+)\)') { $planName = $matches[1] }
    if ($planName -match 'ahorro|saver') { Add-Check 'Rendimiento' 'Plan de energia' 'ATENCION' $planName 'El modo ahorro limita el procesador: usar Modulo 4 > Maximo rendimiento.' }
    else { Add-Check 'Rendimiento' 'Plan de energia' 'OK' $planName }
    $st = @(Get-StartupEntries | Where-Object { $_.Estado -eq 'Activo' }).Count
    if ($st -gt 10) { Add-Check 'Rendimiento' 'Programas al inicio' 'ATENCION' ([string]$st + ' programas arrancan con Windows') 'Desactivar los innecesarios (Modulo 4 > Administrador de inicio).' }
    else { Add-Check 'Rendimiento' 'Programas al inicio' 'OK' ([string]$st + ' programas arrancan con Windows') }

    # ------------------------- INTERNET -------------------------
    $ping = Test-Connection -ComputerName 1.1.1.1 -Count 2 -Quiet -ErrorAction SilentlyContinue
    $dns = Test-DnsName 'www.microsoft.com'
    if ($dns)      { Add-Check 'Red' 'Internet' 'OK' 'Conexion y DNS funcionando' }
    elseif ($ping) { Add-Check 'Red' 'Internet' 'ATENCION' 'Hay conexion pero el DNS falla' 'Usar Modulo 3 > Restaurar la pila de red, o configurar DNS 1.1.1.1 / 8.8.8.8.' }
    else           { Add-Check 'Red' 'Internet' 'CRITICO' 'Sin conexion a internet' 'Revisar cable/WiFi/router; luego Modulo 3 > Restaurar la pila de red.' }

    # ------------------------- PROGRAMAS ESENCIALES -------------------------
    $apps = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                               'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                               'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
              Where-Object { $_.DisplayName } | ForEach-Object { [string]$_.DisplayName })
    $is64 = $global:Is64
    $vcRx = 'Visual C\+\+ (20(15|17|19|22)|v14)'
    $vc64 = ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64' -ErrorAction SilentlyContinue).Installed -eq 1) -or (@($apps | Where-Object { $_ -match ($vcRx + '.*x64') }).Count -gt 0)
    $vc86key = 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86'
    if ($is64) { $vc86key = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86' }
    $vc86 = ((Get-ItemProperty $vc86key -ErrorAction SilentlyContinue).Installed -eq 1) -or (@($apps | Where-Object { $_ -match ($vcRx + '.*x86') }).Count -gt 0)
    $vc13x86 = @($apps | Where-Object { $_ -match 'Visual C\+\+ 2013.*x86' }).Count -gt 0
    $vc13x64 = @($apps | Where-Object { $_ -match 'Visual C\+\+ 2013.*x64' }).Count -gt 0
    $netfx = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue).Release
    $desk = @(Get-ChildItem -LiteralPath "$env:ProgramFiles\dotnet\shared\Microsoft.WindowsDesktop.App" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $wv = $false
    foreach ($k in @('HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
                     'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
                     'HKCU:\Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}')) {
        $pv = (Get-ItemProperty -Path $k -ErrorAction SilentlyContinue).pv
        if ($pv -and $pv -ne '0.0.0.0') { $wv = $true }
    }
    $zip = @($apps | Where-Object { $_ -match '7-Zip|WinRAR|PeaZip|Bandizip|NanaZip' }).Count -gt 0
    $wg  = [bool](Get-Command winget -ErrorAction SilentlyContinue)

    $soft = @(
        @{ N = 'Visual C++ 2015-2022 (x64)'; Ok = ($vc64 -or -not $is64); S = 'ATENCION'; W = 'Muchos programas y juegos no abren sin el.'; Id = 'Microsoft.VCRedist.2015+.x64' },
        @{ N = 'Visual C++ 2015-2022 (x86)'; Ok = $vc86;    S = 'ATENCION'; W = 'Muchos programas y juegos no abren sin el.'; Id = 'Microsoft.VCRedist.2015+.x86' },
        @{ N = 'Visual C++ 2013 (x64)';      Ok = ($vc13x64 -or -not $is64); S = 'INFO'; W = 'Lo usan programas y juegos mas antiguos.'; Id = 'Microsoft.VCRedist.2013.x64' },
        @{ N = 'Visual C++ 2013 (x86)';      Ok = $vc13x86; S = 'INFO';     W = 'Lo usan programas y juegos mas antiguos.'; Id = 'Microsoft.VCRedist.2013.x86' },
        @{ N = '.NET Framework 4.8';         Ok = ($netfx -ge 528040); S = 'ATENCION'; W = 'Lo requieren muchos programas de gestion y facturacion. Se instala desde Windows Update.'; Id = '' },
        @{ N = '.NET Desktop Runtime';       Ok = ($desk.Count -gt 0); S = 'INFO'; W = 'Lo piden los programas modernos al abrirse.'; Id = 'Microsoft.DotNet.DesktopRuntime.10' },
        @{ N = 'DirectX (bibliotecas heredadas)'; Ok = (Test-Path "$env:SystemRoot\System32\d3dx9_43.dll"); S = 'INFO'; W = 'Necesario para juegos y programas graficos antiguos.'; Id = 'Microsoft.DirectX' },
        @{ N = 'Microsoft Edge WebView2';    Ok = $wv;  S = 'ATENCION'; W = 'Lo usan Teams, el nuevo Outlook, Widgets y muchas apps.'; Id = 'Microsoft.EdgeWebView2Runtime' },
        @{ N = 'Compresor de archivos (7-Zip)'; Ok = $zip; S = 'INFO'; W = 'Para abrir .rar, .7z y otros formatos comprimidos.'; Id = '7zip.7zip' },
        @{ N = 'winget (instalador de programas)'; Ok = $wg; S = 'ATENCION'; W = 'Instalar "Instalador de aplicacion" desde Microsoft Store: permite actualizar todos los programas.'; Id = '' }
    )
    if (-not $global:IsWin10) {
        # En Windows 7/8 estos ya no existen o no tienen soporte: no se piden
        $soft = @($soft | Where-Object { @('.NET Desktop Runtime', 'Microsoft Edge WebView2', 'winget (instalador de programas)') -notcontains $_.N })
    }
    foreach ($s in $soft) {
        if ($s.Ok) { Add-Check 'Programas esenciales' $s.N 'OK' 'Instalado' }
        else { Add-Check 'Programas esenciales' $s.N $s.S 'No instalado' $s.W; Add-Missing $s.N $s.Id $s.W }
    }
}

function Enc-Html([string]$s) { return [System.Security.SecurityElement]::Escape($s) }

function Write-HtmlReport([int]$score, [string]$label) {
    $os   = Get-CimInstance Win32_OperatingSystem
    $cs   = Get-CimInstance Win32_ComputerSystem
    $cpu  = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()
    $gpu  = (Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name }) -join ', '
    $bios = Get-CimInstance Win32_BIOS
    $col = '#1a7f37'; if ($score -lt 80) { $col = '#9a6700' }; if ($score -lt 50) { $col = '#cf222e' }
    $crit = @($global:Checks | Where-Object { $_.Estado -eq 'CRITICO' }).Count
    $warn = @($global:Checks | Where-Object { $_.Estado -eq 'ATENCION' }).Count
    $sorted = @($global:Checks | Sort-Object -Property @{ Expression = { Get-SevRank $_.Estado } }, Categoria)
    $todo = @($sorted | Where-Object { $_.Estado -ne 'OK' })
    $css = @'
body{font-family:'Segoe UI',Arial,sans-serif;background:#f4f5f7;color:#1f2328;margin:0;padding:24px 16px}
.wrap{max-width:1050px;margin:0 auto}
h1{margin:0 0 4px;font-size:26px}
h2{font-size:19px;margin:30px 0 10px;border-bottom:2px solid #d0d7de;padding-bottom:6px}
.sub{color:#59636e;margin:0 0 18px}
.top{display:flex;gap:28px;align-items:center;background:#fff;border:1px solid #d0d7de;border-radius:10px;padding:18px 22px;flex-wrap:wrap}
.score{font-size:52px;font-weight:700;color:COLOR;line-height:1}
.score small{font-size:18px;color:#59636e}
.bar{height:12px;background:#e6e8eb;border-radius:6px;overflow:hidden;margin-top:10px;width:260px;max-width:100%}
.bar div{height:100%;background:COLOR}
table{width:100%;border-collapse:collapse;background:#fff;border:1px solid #d0d7de;font-size:14px}
th,td{padding:8px 10px;border-bottom:1px solid #eaeef2;text-align:left;vertical-align:top}
th{background:#f6f8fa;font-weight:600}
.b{display:inline-block;padding:2px 8px;border-radius:10px;font-size:12px;font-weight:700;white-space:nowrap}
.CRITICO,.ERROR{background:#ffebe9;color:#cf222e}.ATENCION,.AVISO{background:#fff8c5;color:#9a6700}.INFO{background:#ddf4ff;color:#0969da}.OK{background:#dafbe1;color:#1a7f37}
.rec{color:#59636e;font-size:13px;margin-top:4px}
code{background:#f6f8fa;border:1px solid #d0d7de;padding:1px 6px;border-radius:4px;font-size:12px}
.ok100{background:#dafbe1;color:#1a7f37;padding:14px;border-radius:8px;font-weight:600}
.foot{color:#59636e;font-size:12px;margin-top:26px}
@media print{body{background:#fff}}
'@
    $css = $css.Replace('COLOR', $col)
    $h = New-Object System.Text.StringBuilder
    $add = { param($s) [void]$h.AppendLine($s) }

    & $add ('<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Informe ' + (Enc-Html $env:COMPUTERNAME) + '</title><style>' + $css + '</style></head><body><div class="wrap">')
    & $add ('<h1>Informe de mantenimiento: ' + (Enc-Html $env:COMPUTERNAME) + '</h1>')
    & $add ('<p class="sub">' + (Enc-Html ($cs.Manufacturer + ' ' + $cs.Model)) + ' &middot; ' + (Get-Date -Format 'dd/MM/yyyy HH:mm') + '</p>')
    & $add ('<div class="top"><div><div class="score">' + $score + '<small> / 100</small></div><div class="bar"><div style="width:' + $score + '%"></div></div></div>')
    & $add ('<div><b>Estado de Windows: ' + $label + '</b><br>' + $crit + ' problema(s) critico(s) &middot; ' + $warn + ' punto(s) de atencion &middot; ' + @($global:Missing).Count + ' herramienta(s) faltante(s)</div></div>')

    if ($global:Results.ContainsKey('Inicio')) {
        $okN  = @($global:StepLog | Where-Object { $_.Estado -eq 'OK' }).Count
        $avN  = @($global:StepLog | Where-Object { $_.Estado -eq 'AVISO' }).Count
        $erN  = @($global:StepLog | Where-Object { $_.Estado -eq 'ERROR' }).Count
        $wuOk = @($global:Results['WU_Instaladas'])
        $wuTxt = 'Ninguna (ya estaba al dia)'; if ($wuOk.Count -gt 0 -and $wuOk[0]) { $wuTxt = ($wuOk | ForEach-Object { Enc-Html $_ }) -join '<br>' }
        & $add '<h2>Lo que se hizo</h2><table>'
        & $add ('<tr><th style="width:260px">Espacio liberado</th><td>' + (Format-Size $global:Freed) + '</td></tr>')
        & $add ('<tr><th>Libre en ' + $env:SystemDrive + '</th><td>' + (Format-Size $global:Results['LibreAntes']) + ' &rarr; ' + (Format-Size $global:Results['LibreDespues']) + '</td></tr>')
        & $add ('<tr><th>RAM libre</th><td>' + $global:Results['RamAntes'] + ' GB &rarr; ' + $global:Results['RamDespues'] + ' GB</td></tr>')
        & $add ('<tr><th>Tareas ejecutadas</th><td>' + $okN + ' correctas &middot; ' + $avN + ' con aviso &middot; ' + $erN + ' con error</td></tr>')
        & $add ('<tr><th>Actualizaciones de Windows instaladas</th><td>' + $wuTxt + '</td></tr>')
        & $add ('<tr><th>Duracion</th><td>' + ((Get-Date) - $global:Results['Inicio']).ToString('hh\:mm\:ss') + '</td></tr>')
        & $add '</table>'
    }

    & $add '<h2>Lo que falta para tener Windows al 100%</h2>'
    if ($todo.Count -eq 0) { & $add '<div class="ok100">Nada. Windows esta al 100%.</div>' }
    else {
        & $add '<table><tr><th>Estado</th><th>Area</th><th>Problema y solucion</th></tr>'
        foreach ($c in $todo) {
            & $add ('<tr><td><span class="b ' + $c.Estado + '">' + $c.Estado + '</span></td><td>' + (Enc-Html $c.Categoria) + '</td><td><b>' + (Enc-Html $c.Elemento) + ':</b> ' + (Enc-Html $c.Detalle) + '<div class="rec">&#10148; ' + (Enc-Html $c.Recomendacion) + '</div></td></tr>')
        }
        & $add '</table>'
    }

    if (@($global:Missing).Count -gt 0) {
        & $add '<h2>Herramientas y programas que faltan</h2><table><tr><th>Programa</th><th>Para que sirve</th><th>Como instalarlo</th></tr>'
        foreach ($m in $global:Missing) {
            $how = 'Windows Update / Microsoft Store'
            if (-not $global:IsWin10) { $how = 'Descargar desde la pagina oficial' }
            if ($m.Id -and $global:IsWin10) { $how = '<code>winget install --id ' + (Enc-Html $m.Id) + ' -e</code>' }
            & $add ('<tr><td>' + (Enc-Html $m.Nombre) + '</td><td>' + (Enc-Html $m.Rec) + '</td><td>' + $how + '</td></tr>')
        }
        & $add '</table>'
    }

    & $add '<h2>Diagnostico completo</h2><table><tr><th>Estado</th><th>Area</th><th>Elemento</th><th>Detalle</th></tr>'
    foreach ($c in $sorted) {
        & $add ('<tr><td><span class="b ' + $c.Estado + '">' + $c.Estado + '</span></td><td>' + (Enc-Html $c.Categoria) + '</td><td>' + (Enc-Html $c.Elemento) + '</td><td>' + (Enc-Html $c.Detalle) + '</td></tr>')
    }
    & $add '</table>'

    $issues = @($global:StepLog | Where-Object { $_.Estado -ne 'OK' })
    if ($issues.Count -gt 0) {
        & $add '<h2>Avisos y errores durante el mantenimiento</h2><table><tr><th>Estado</th><th>Tarea</th><th>Detalle</th></tr>'
        foreach ($i in $issues) { & $add ('<tr><td><span class="b ' + $i.Estado + '">' + $i.Estado + '</span></td><td>' + (Enc-Html $i.Tarea) + '</td><td>' + (Enc-Html $i.Detalle) + '</td></tr>') }
        & $add '</table>'
    }

    & $add '<h2>Datos del equipo</h2><table>'
    $rows = @(
        @('Equipo', ($cs.Manufacturer + ' ' + $cs.Model)), @('No. de serie', $bios.SerialNumber), @('Windows', ($os.Caption + ' (build ' + $os.BuildNumber + ')')),
        @('Procesador', $cpu), @('RAM', ([string][math]::Round($cs.TotalPhysicalMemory / 1GB, 1) + ' GB')), @('Grafica', $gpu),
        @('BIOS', ($bios.SMBIOSBIOSVersion)), @('Usuario', $env:USERNAME))
    foreach ($r in $rows) { & $add ('<tr><th style="width:260px">' + $r[0] + '</th><td>' + (Enc-Html ([string]$r[1])) + '</td></tr>') }
    & $add '</table>'
    & $add ('<p class="foot">Generado por ' + (Enc-Html $global:AppName) + ' v' + $global:AppVer + ' &middot; Creado por ' + (Enc-Html $global:AppAuthor) + ' &middot; Log detallado: ' + (Enc-Html $global:LogFile) + '</p></div></body></html>')

    $path = Join-Path $global:LogDir ('Informe_' + $env:COMPUTERNAME + '_' + (Get-Date -Format 'yyyy-MM-dd_HH-mm') + '.html')
    [IO.File]::WriteAllText($path, $h.ToString(), [Text.Encoding]::UTF8)
    return $path
}

function New-Report {
    Write-Section 'Diagnostico final e informe'
    Get-Diagnostics
    $crit = @($global:Checks | Where-Object { $_.Estado -eq 'CRITICO' }).Count
    $warn = @($global:Checks | Where-Object { $_.Estado -eq 'ATENCION' }).Count
    $score = [math]::Max(0, 100 - 12 * $crit - 4 * $warn)
    $label = 'Malo'
    if ($score -ge 50) { $label = 'Regular' }
    if ($score -ge 75) { $label = 'Bueno' }
    if ($score -ge 90) { $label = 'Excelente' }
    if ($score -eq 100) { $label = 'Perfecto' }
    $color = 'Green'; if ($score -lt 80) { $color = 'Yellow' }; if ($score -lt 50) { $color = 'Red' }

    Write-Host ''
    Write-Host '=================================================================' -ForegroundColor $color
    Write-Host ('            ESTADO DE WINDOWS:  {0} / 100   ({1})' -f $score, $label) -ForegroundColor $color
    Write-Host '=================================================================' -ForegroundColor $color
    $todo = @($global:Checks | Where-Object { $_.Estado -ne 'OK' } | Sort-Object -Property @{ Expression = { Get-SevRank $_.Estado } })
    if ($todo.Count -eq 0) { Write-Host '  No falta nada: Windows esta al 100%.' -ForegroundColor Green }
    else {
        Write-Host '  LO QUE FALTA PARA TENER WINDOWS AL 100%:' -ForegroundColor White
        foreach ($c in $todo) {
            $cc = 'Cyan'; if ($c.Estado -eq 'CRITICO') { $cc = 'Red' } elseif ($c.Estado -eq 'ATENCION') { $cc = 'Yellow' }
            Write-Host ('  [{0}] {1}: {2}' -f $c.Estado, $c.Elemento, $c.Detalle) -ForegroundColor $cc
            if ($c.Recomendacion) { Write-Host ('        -> ' + $c.Recomendacion) -ForegroundColor Gray }
        }
    }
    Write-Log ('PUNTUACION FINAL: ' + $score + '/100 (' + $label + ')')
    foreach ($c in $global:Checks) { Write-Log ('[' + $c.Estado + '] ' + $c.Categoria + ' / ' + $c.Elemento + ': ' + $c.Detalle) }

    $path = Write-HtmlReport $score $label
    Write-Host ''
    Write-Host ('  Informe completo guardado en: ' + $path) -ForegroundColor Green
    Write-Log ('Informe HTML: ' + $path)
    try { Start-Process $path } catch {}
}

function Install-Missing {
    $inst = @($global:Missing | Where-Object { $_.Id })
    if ($inst.Count -eq 0) { return }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host '  Para instalar lo que falta automaticamente, primero instala "Instalador de aplicacion" desde la Microsoft Store.' -ForegroundColor Yellow
        return
    }
    Write-Host ''
    Write-Host '  Herramientas que faltan y se pueden instalar ahora:' -ForegroundColor Cyan
    foreach ($m in $inst) { Write-Host ('   - ' + $m.Nombre) }
    if (Confirm-Action 'Instalar ahora todas las herramientas que faltan?') {
        foreach ($m in $inst) {
            Invoke-Live ('Instalar ' + $m.Nombre) 'winget' ('install --id ' + $m.Id + ' -e --silent --accept-package-agreements --accept-source-agreements')
        }
    }
}

# =====================================================================
#   MODO AUTOMATICO TOTAL
# =====================================================================
function Preset-Auto {
    $global:Results = @{}
    $global:StepLog.Clear()
    $global:Results['Inicio']     = Get-Date
    $global:Results['LibreAntes'] = (Get-FreeBytes)
    $global:Results['RamAntes']   = (Get-RamStatus).Libre
    $global:Auto = $true
    try {
        Write-Host ''; Write-Host '>>> FASE 1/7: Analisis inicial' -ForegroundColor Magenta
        Get-EventSummary
        Write-Host ''; Write-Host '>>> FASE 2/7: Punto de restauracion y analisis de virus' -ForegroundColor Magenta
        X-Restore
        T-DefenderQuick
        Write-Host ''; Write-Host '>>> FASE 3/7: Limpieza' -ForegroundColor Magenta
        M1-UserTemp; M1-WinTemp; M1-WUCache; M1-Dumps; M1-Store; M1-Browsers; M1-Thumbs; M1-Recycle; M1-DNS
        Write-Host ''; Write-Host '>>> FASE 4/7: Memoria RAM' -ForegroundColor Magenta
        M2-KillBloat; M2-Clipboard; M2-WorkingSets; M2-Standby
        Write-Host ''; Write-Host '>>> FASE 5/7: Rendimiento' -ForegroundColor Magenta
        M4-Power; M4-Visual; M4-Game; M4-Telemetry; M2-Pagefile; M2-Timer
        Write-Host ''; Write-Host '>>> FASE 6/7: Reparacion' -ForegroundColor Magenta
        M3-DISM; M3-Components; M3-SFC; M3-Chkdsk; M3-Services; M3-Defrag
        Write-Host ''; Write-Host '>>> FASE 7/7: Actualizaciones' -ForegroundColor Magenta
        X-WindowsUpdate; X-Winget
    } finally {
        $global:Auto = $false
    }
    Complete-Run
}

function Report-Only {
    $global:Results = @{}
    $global:StepLog.Clear()
    New-Report
    Install-Missing
}

# =====================================================================
#   HERRAMIENTAS DE SOPORTE
# =====================================================================

# Convierte "1,3,5" en indices (0-based). $allKey = letra que significa "todos"
function Get-Selection([string]$sel, [int]$count, [string]$allKey = 'T') {
    if (-not $sel) { return @() }
    if ($sel.Trim().ToUpper() -eq $allKey) { return @(0..($count - 1)) }
    $idx = @()
    foreach ($s in ($sel -split '[,\s]+')) {
        $n = 0
        if ([int]::TryParse($s, [ref]$n) -and $n -ge 1 -and $n -le $count -and ($idx -notcontains ($n - 1))) { $idx += ($n - 1) }
    }
    return $idx
}

# Pregunta donde guardar (USB, otro disco, escritorio o ruta escrita) y revisa el espacio libre
function Select-Destination([string]$what, [double]$needBytes = 0) {
    Write-Host ''
    Write-Host ('  Donde guardar ' + $what + '?') -ForegroundColor Cyan
    $opts = @()
    foreach ($d in @(Get-CimInstance Win32_LogicalDisk | Where-Object { (@(2, 3)) -contains ($_.DriveType) -and $_.DeviceID -ne $env:SystemDrive -and $_.Size -gt 0 })) {
        $tipo = 'Disco'; if ($d.DriveType -eq 2) { $tipo = 'USB / extraible' }
        $label = [string]$d.VolumeName; if (-not $label) { $label = 'sin nombre' }
        $opts += (New-Object PSObject -Property @{ Path = ($d.DeviceID + '\'); Text = ('{0}\  {1} "{2}"  -  {3} libres' -f $d.DeviceID, $tipo, $label, (Format-Size $d.FreeSpace)); Free = [double]$d.FreeSpace })
    }
    $sysFree = [double](Get-FreeBytes)
    $opts += (New-Object PSObject -Property @{ Path = [Environment]::GetFolderPath('Desktop'); Text = ('Escritorio de este equipo  -  NO sirve si vas a formatear'); Free = $sysFree })
    for ($i = 0; $i -lt $opts.Count; $i++) { Write-Host ('   {0}. {1}' -f ($i + 1), $opts[$i].Text) }
    Write-Host '   R. Escribir otra ruta'
    Write-Host '   0. Cancelar'
    if ($needBytes -gt 0) { Write-Host ('  Espacio necesario: ' + (Format-Size $needBytes)) -ForegroundColor DarkGray }
    $sel = Read-Host '  Opcion'
    $path = $null; $free = 0
    if ($sel -match '^\s*[rR]\s*$') {
        $path = Read-Host '  Escribe la ruta completa (ej: E:\Respaldos)'
        if (-not $path) { return $null }
        try {
            $qual = Split-Path -Path $path -Qualifier -ErrorAction Stop
            $free = [double](Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='" + $qual + "'")).FreeSpace
        } catch { $free = 0 }
    } else {
        $n = 0
        if (-not ([int]::TryParse($sel, [ref]$n)) -or $n -lt 1 -or $n -gt $opts.Count) { return $null }
        $path = $opts[$n - 1].Path; $free = $opts[$n - 1].Free
    }
    if ($needBytes -gt 0 -and $free -gt 0 -and $free -lt ($needBytes * 1.05)) {
        Write-Host ('  No hay espacio suficiente en el destino (libre: ' + (Format-Size $free) + ').') -ForegroundColor Red
        return $null
    }
    return $path
}

# ---------------------------------------------------------------------
#   1. ANTIVIRUS (MICROSOFT DEFENDER)
# ---------------------------------------------------------------------
function Get-DefenderStatus { try { return Get-MpComputerStatus -ErrorAction Stop } catch { return $null } }

function Show-Threats([int]$Days = 30) {
    $since = (Get-Date).AddDays(-$Days)
    $names = @{}
    foreach ($t in @(Get-MpThreat -ErrorAction SilentlyContinue)) { $names[[string]$t.ThreatID] = $t.ThreatName }
    $det = @(Get-MpThreatDetection -ErrorAction SilentlyContinue | Where-Object { $_.InitialDetectionTime -ge $since } | Sort-Object InitialDetectionTime -Descending)
    if ($det.Count -eq 0) {
        Write-Host ('  No se encontraron virus ni amenazas en los ultimos ' + $Days + ' dias.') -ForegroundColor Green
        Write-Log ('Defender: sin amenazas en ' + $Days + ' dias')
        return
    }
    Write-Host ('  AMENAZAS DETECTADAS: ' + $det.Count) -ForegroundColor Red
    foreach ($d in ($det | Select-Object -First 15)) {
        $nm = $names[[string]$d.ThreatID]; if (-not $nm) { $nm = 'ID ' + $d.ThreatID }
        $st = 'eliminada / en cuarentena'; if (-not $d.ActionSuccess) { $st = 'NO SE PUDO ELIMINAR' }
        $where = (@($d.Resources) | Select-Object -First 2) -join '; '
        Write-Host ('   - {0}   [{1}]   {2}' -f $nm, $st, $d.InitialDetectionTime) -ForegroundColor Yellow
        if ($where) { Write-Host ('       ' + $where) -ForegroundColor DarkGray }
        Write-Log ('[VIRUS] ' + $nm + ' - ' + $st + ' - ' + $where)
    }
    if (@($det | Where-Object { -not $_.ActionSuccess }).Count -gt 0) {
        Write-Host '  Hay amenazas que no se pudieron eliminar: usa el ANALISIS SIN CONEXION (opcion 3).' -ForegroundColor Red
    }
}

function T-DefenderQuick {
    Write-Section 'Analisis rapido de virus (Microsoft Defender)'
    $mp = Get-DefenderStatus
    $mpc = Get-MpCmdRun
    if (-not $mp -and $mpc) {
        # Windows 7 (Security Essentials) u 8: se usa el antivirus por linea de comandos
        Invoke-Live 'Actualizar la base de virus' $mpc '-SignatureUpdate'
        Write-Host '     Analizando... tarda de 5 a 15 minutos. No cierres esta ventana.' -ForegroundColor DarkGray
        Invoke-Live 'Analisis rapido de virus' $mpc '-Scan -ScanType 1'
        if ($global:LastLive -eq 2) { Write-Host '  SE ENCONTRARON AMENAZAS: abre el antivirus para ver cuales y si se eliminaron.' -ForegroundColor Red }
        return
    }
    if (-not $mp -or -not $mp.AntivirusEnabled) {
        Write-Host '  Microsoft Defender no esta activo (el equipo usa otro antivirus). Se omite.' -ForegroundColor Yellow
        Write-Log 'Defender no activo: analisis omitido'
        return
    }
    Step 'Actualizar la base de virus de Defender' { Update-MpSignature -ErrorAction Stop }
    Write-Host '     Analizando... tarda de 5 a 15 minutos. No cierres esta ventana.' -ForegroundColor DarkGray
    Step 'Analisis rapido de virus' { Start-MpScan -ScanType QuickScan -ErrorAction Stop }
    if (-not $global:DryRun) { Show-Threats 1 }
}

function T-Defender {
    Write-Section 'Buscar virus con Microsoft Defender'
    $mp = Get-DefenderStatus
    $mpc = Get-MpCmdRun
    if (-not $mp -and $mpc) {
        Write-Host ('  Antivirus de Microsoft encontrado (' + $global:WinName + ').')
        Write-Host '   1. Analisis RAPIDO   (5-15 min)'
        Write-Host '   2. Analisis COMPLETO (1-3 horas)'
        Write-Host '   0. Volver'
        $op = (Read-Host '  Opcion').Trim()
        if ($op -ne '1' -and $op -ne '2') { return }
        Invoke-Live 'Actualizar la base de virus' $mpc '-SignatureUpdate'
        Write-Host '     Analizando... no cierres esta ventana.' -ForegroundColor DarkGray
        Invoke-Live 'Analisis de virus' $mpc ('-Scan -ScanType ' + $op)
        if ($global:LastLive -eq 2) { Write-Host '  SE ENCONTRARON AMENAZAS: abre el antivirus para ver cuales y si se eliminaron.' -ForegroundColor Red }
        return
    }
    if (-not $mp -or -not $mp.AntivirusEnabled) {
        Write-Host '  Microsoft Defender no esta activo: este equipo usa otro antivirus.' -ForegroundColor Yellow
        Write-Host '  Haz el analisis desde ese antivirus.' -ForegroundColor Yellow
        return
    }
    if ($mp.QuickScanAge -lt 10000) { Write-Host ('  Ultimo analisis rapido: hace ' + $mp.QuickScanAge + ' dia(s).   Base de virus: de hace ' + $mp.AntivirusSignatureAge + ' dia(s).') -ForegroundColor Gray }
    Write-Host ''
    Write-Host '   1. Analisis RAPIDO      (5-15 min)  revisa donde suelen esconderse los virus'
    Write-Host '   2. Analisis COMPLETO    (1-3 horas) revisa todo el disco'
    Write-Host '   3. Analisis SIN CONEXION (~15 min)  REINICIA el equipo; para virus que no se dejan borrar'
    Write-Host '   4. Ver virus encontrados en los ultimos 90 dias'
    Write-Host '   0. Volver'
    switch ((Read-Host '  Opcion').Trim()) {
        '1' {
            Step 'Actualizar la base de virus' { Update-MpSignature -ErrorAction Stop }
            Write-Host '     Analizando... tarda de 5 a 15 minutos. No cierres esta ventana.' -ForegroundColor DarkGray
            Step 'Analisis rapido' { Start-MpScan -ScanType QuickScan -ErrorAction Stop }
            if (-not $global:DryRun) { Show-Threats 1 }
        }
        '2' {
            Step 'Actualizar la base de virus' { Update-MpSignature -ErrorAction Stop }
            Write-Host '     Analizando TODO el disco... puede tardar horas. No cierres esta ventana.' -ForegroundColor DarkGray
            Step 'Analisis completo' { Start-MpScan -ScanType FullScan -ErrorAction Stop }
            if (-not $global:DryRun) { Show-Threats 1 }
        }
        '3' {
            Write-Host '  El equipo se REINICIARA en unos segundos y analizara antes de que arranque Windows (~15 min).' -ForegroundColor Yellow
            if (Confirm-Action 'Guardaste todo el trabajo abierto y quieres continuar?' $false $true) {
                Step 'Analisis sin conexion (el equipo se reinicia)' { Start-MpWDOScan -ErrorAction Stop }
            }
        }
        '4' { Show-Threats 90 }
    }
}

# ---------------------------------------------------------------------
#   2. APLICACIONES BASURA DE FABRICA
#   Solo apps que se pueden volver a instalar gratis desde la Microsoft Store.
#   NUNCA se tocan: Tienda, Calculadora, Fotos, Paint clasico, Bloc de notas,
#   Configuracion, Seguridad de Windows, Xbox (juegos) ni drivers.
# ---------------------------------------------------------------------
$global:BloatApps = @(
    @{ P = 'king.com.*';                                N = 'Juegos de King (Candy Crush y similares)' },
    @{ P = 'Microsoft.MicrosoftSolitaireCollection';    N = 'Microsoft Solitaire Collection' },
    @{ P = 'Microsoft.BingNews';                        N = 'Noticias' },
    @{ P = 'Microsoft.BingWeather';                     N = 'El Tiempo' },
    @{ P = 'Microsoft.Getstarted';                      N = 'Sugerencias (Tips)' },
    @{ P = 'Microsoft.GetHelp';                         N = 'Obtener ayuda' },
    @{ P = 'Microsoft.MicrosoftOfficeHub';              N = 'Office (publicidad para comprar Office)' },
    @{ P = 'Microsoft.People';                          N = 'Contactos' },
    @{ P = 'Microsoft.SkypeApp';                        N = 'Skype' },
    @{ P = 'Microsoft.WindowsFeedbackHub';              N = 'Centro de opiniones' },
    @{ P = 'Microsoft.WindowsMaps';                     N = 'Mapas' },
    @{ P = 'Microsoft.MixedReality.Portal';             N = 'Portal de realidad mixta' },
    @{ P = 'Microsoft.Microsoft3DViewer';               N = 'Visor 3D' },
    @{ P = 'Microsoft.Print3D';                         N = 'Print 3D' },
    @{ P = 'Microsoft.3DBuilder';                       N = '3D Builder' },
    @{ P = 'Microsoft.MSPaint';                         N = 'Paint 3D (el Paint clasico NO se toca)' },
    @{ P = 'Microsoft.ZuneVideo';                       N = 'Peliculas y TV' },
    @{ P = 'Microsoft.549981C3F5F10';                   N = 'Cortana' },
    @{ P = 'Microsoft.Todos';                           N = 'Microsoft To Do' },
    @{ P = 'Clipchamp.Clipchamp';                       N = 'Clipchamp (editor de video)' },
    @{ P = 'MicrosoftCorporationII.MicrosoftFamily';    N = 'Microsoft Family' },
    @{ P = 'Microsoft.YourPhone';                       N = 'Vincular telefono' },
    @{ P = 'SpotifyAB.SpotifyMusic';                    N = 'Spotify (version de la Tienda)' },
    @{ P = '*Disney*';                                  N = 'Disney+' },
    @{ P = '*Facebook*';                                N = 'Facebook' },
    @{ P = '*Instagram*';                               N = 'Instagram' },
    @{ P = '*TikTok*';                                  N = 'TikTok' },
    @{ P = '*Twitter*';                                 N = 'Twitter / X' },
    @{ P = 'AmazonVideo.PrimeVideo';                    N = 'Prime Video' },
    @{ P = '*Netflix*';                                 N = 'Netflix' },
    @{ P = '*McAfee*';                                  N = 'McAfee (version de la Tienda)' },
    @{ P = '*HiddenCity*';                              N = 'Hidden City (juego)' },
    @{ P = '*MarchofEmpires*';                          N = 'March of Empires (juego)' }
)

function Get-InstalledBloat {
    $found = @()
    foreach ($b in $global:BloatApps) {
        $pk = @(Get-AppxPackage -AllUsers -Name $b.P -ErrorAction SilentlyContinue)
        if ($pk.Count -gt 0) { $found += (New-Object PSObject -Property @{ N = $b.N; P = $b.P }) }
    }
    return $found
}

function T-Bloat {
    Write-Section 'Quitar aplicaciones basura de fabrica'
    if (-not $global:IsWin8) {
        Show-NotSupported 'Quitar apps de la Tienda'
        Write-Host '  Windows 7 no tiene apps de la Tienda. Para quitar programas usa Panel de control > Programas.' -ForegroundColor DarkGray
        return
    }
    Write-Host '  Buscando aplicaciones innecesarias...'
    $found = @(Get-InstalledBloat)
    if ($found.Count -eq 0) { Write-Host '  No hay aplicaciones basura instaladas. Todo limpio.' -ForegroundColor Green; return }
    for ($i = 0; $i -lt $found.Count; $i++) { Write-Host ('   {0,2}. {1}' -f ($i + 1), $found[$i].N) }
    Write-Host ''
    Write-Host '  Todas se pueden volver a instalar gratis desde la Microsoft Store si el usuario las extrana.' -ForegroundColor DarkGray
    $idx = Get-Selection (Read-Host '  Numeros a quitar separados por coma (ej: 1,3), T = todas, ENTER = ninguna') $found.Count
    if ($idx.Count -eq 0) { Write-Host '  No se quito nada.'; return }
    foreach ($i in $idx) {
        $b = $found[$i]
        Step ('Quitar ' + $b.N) {
            if ((Get-Command Remove-AppxPackage).Parameters.ContainsKey('AllUsers')) { Get-AppxPackage -AllUsers -Name $b.P -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction Stop }
            else { Get-AppxPackage -Name $b.P -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction Stop }
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $b.P } |
                Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

# ---------------------------------------------------------------------
#   3. PROGRAMAS BASICOS (winget)
# ---------------------------------------------------------------------
# Rx = como aparece en "Programas instalados" de Windows (se usa para saber si ya esta instalado;
# winget no reconoce los programas que se instalaron sin el, por eso no se usa "winget list")
$global:BasicApps = @(
    @{ N = 'Google Chrome';                       Rx = @('^Google Chrome');                Ids = @('Google.Chrome'); Url = 'https://www.google.com/chrome' },
    @{ N = 'Mozilla Firefox';                     Rx = @('^Mozilla Firefox');              Ids = @('Mozilla.Firefox'); Url = 'https://www.mozilla.org/firefox' },
    @{ N = '7-Zip (abrir .zip / .rar / .7z)';     Rx = @('^7-Zip');                        Ids = @('7zip.7zip'); Url = 'https://www.7-zip.org' },
    @{ N = 'VLC (videos y musica)';               Rx = @('^VLC media player');             Ids = @('VideoLAN.VLC'); Url = 'https://www.videolan.org' },
    @{ N = 'Adobe Acrobat Reader (PDF)';          Rx = @('^Adobe Acrobat');                Ids = @('Adobe.Acrobat.Reader.64-bit'); Url = 'https://get.adobe.com/reader' },
    @{ N = 'LibreOffice (Office gratuito)';       Rx = @('^LibreOffice');                  Ids = @('TheDocumentFoundation.LibreOffice'); Url = 'https://www.libreoffice.org' },
    @{ N = 'AnyDesk (soporte remoto)';            Rx = @('^AnyDesk');                      Ids = @('AnyDesk.AnyDesk'); Url = 'https://anydesk.com' },
    @{ N = 'TeamViewer (soporte remoto)';         Rx = @('^TeamViewer');                   Ids = @('TeamViewer.TeamViewer'); Url = 'https://www.teamviewer.com' },
    @{ N = 'Zoom (videollamadas)';                Rx = @('^Zoom');                         Ids = @('Zoom.Zoom'); Url = 'https://zoom.us/download' },
    @{ N = 'Notepad++ (editor de texto)';         Rx = @('^Notepad\+\+');                  Ids = @('Notepad++.Notepad++'); Url = 'https://notepad-plus-plus.org' },
    @{ N = 'Visual C++ 2015-2022 (x64 y x86)';    Rx = @('Visual C\+\+ (20(15|17|19|22)|v14).*x64', 'Visual C\+\+ (20(15|17|19|22)|v14).*x86'); Ids = @('Microsoft.VCRedist.2015+.x64', 'Microsoft.VCRedist.2015+.x86'); Url = 'https://aka.ms/vs/17/release/vc_redist.x64.exe' },
    @{ N = 'Microsoft Edge WebView2';             Rx = @('^Microsoft Edge WebView2');      Ids = @('Microsoft.EdgeWebView2Runtime'); Url = 'https://developer.microsoft.com/microsoft-edge/webview2' }
)

function Get-InstalledProgramNames {
    @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                       'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                       'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
      Where-Object { $_.DisplayName } | ForEach-Object { [string]$_.DisplayName })
}

function Test-AppInstalled([string[]]$rx, [string[]]$names) {
    foreach ($r in $rx) { if (@($names | Where-Object { $_ -match $r }).Count -eq 0) { return $false } }
    return $true
}

function T-BasicApps {
    Write-Section 'Instalar programas basicos'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        if ($global:IsWin10) { Write-Host '  Falta winget. Instala "Instalador de aplicacion" (App Installer) desde la Microsoft Store y vuelve a intentar.' -ForegroundColor Yellow; return }
        Write-Host ('  En ' + $global:WinName + ' no existe el instalador automatico (winget). Descargalos desde su pagina oficial:') -ForegroundColor Yellow
        foreach ($a in $global:BasicApps) { if ($a.Url) { Write-Host ('   - {0,-38} {1}' -f $a.N, $a.Url) } }
        Write-Host '  OJO: muchos programas nuevos ya no funcionan en Windows 7/8; busca la ultima version compatible.' -ForegroundColor DarkGray
        return
    }
    $names = Get-InstalledProgramNames
    $wv2 = $false
    foreach ($k in @('HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
                     'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
                     'HKCU:\Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}')) {
        $pv = (Get-ItemProperty -Path $k -ErrorAction SilentlyContinue).pv
        if ($pv -and $pv -ne '0.0.0.0') { $wv2 = $true }
    }
    $rows = @()
    foreach ($a in $global:BasicApps) {
        $inst = Test-AppInstalled $a.Rx $names
        if ($a.Ids -contains 'Microsoft.EdgeWebView2Runtime') { $inst = ($inst -or $wv2) }
        $rows += (New-Object PSObject -Property @{ N = $a.N; Ids = $a.Ids; Inst = $inst })
    }
    for ($i = 0; $i -lt $rows.Count; $i++) {
        if ($rows[$i].Inst) { Write-Host ('   {0,2}. {1,-40} ya instalado' -f ($i + 1), $rows[$i].N) -ForegroundColor DarkGray }
        else { Write-Host ('   {0,2}. {1,-40} NO instalado' -f ($i + 1), $rows[$i].N) }
    }
    Write-Host ''
    $sel = Read-Host '  Numeros a instalar (ej: 1,3,4), F = todos los que faltan, ENTER = ninguno'
    if ($sel -match '^\s*[fF]\s*$') { $idx = @(for ($i = 0; $i -lt $rows.Count; $i++) { if (-not $rows[$i].Inst) { $i } }) }
    else { $idx = Get-Selection $sel $rows.Count }
    if ($idx.Count -eq 0) { Write-Host '  No se instalo nada.'; return }
    foreach ($i in $idx) {
        foreach ($id in $rows[$i].Ids) {
            Invoke-Live ('Instalar ' + $rows[$i].N) 'winget' ('install --id ' + $id + ' -e --silent --accept-package-agreements --accept-source-agreements')
        }
    }
}

# ---------------------------------------------------------------------
#   4. RESPALDO Y RESTAURACION DE DRIVERS
# ---------------------------------------------------------------------
function T-Drivers {
    Write-Section 'Respaldar o restaurar drivers'
    Write-Host '   1. Respaldar los drivers de este equipo (hazlo ANTES de formatear)'
    Write-Host '   2. Restaurar drivers desde un respaldo (DESPUES de formatear, en el MISMO equipo)'
    Write-Host '   0. Volver'
    switch ((Read-Host '  Opcion').Trim()) {
        '1' {
            if (-not $global:IsWin81) {
                Show-NotSupported 'Respaldar drivers'
                Write-Host '  Descarga los drivers del modelo desde la web del fabricante y guardalos en la USB antes de formatear.' -ForegroundColor DarkGray
                return
            }
            $base = Select-Destination 'el respaldo de drivers'
            if (-not $base) { Write-Host '  Cancelado.'; return }
            $dest = Join-Path $base ('Drivers_' + $env:COMPUTERNAME + '_' + (Get-Date -Format 'yyyy-MM-dd'))
            Step ('Crear carpeta ' + $dest) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
            if ($global:IsWin10) { Invoke-Live 'Copiar todos los drivers instalados (1-5 minutos)' 'pnputil.exe' ('/export-driver * "' + $dest + '"') }
            else { Invoke-Live 'Copiar todos los drivers instalados (1-5 minutos)' 'dism.exe' ('/Online /Export-Driver /Destination:"' + $dest + '"') }
            if ($global:DryRun) { return }
            if ($global:LastLive -ne 0 -and (Test-Cmd 'Export-WindowsDriver')) { Step 'Copiar drivers (metodo alternativo)' { Export-WindowsDriver -Online -Destination $dest -ErrorAction Stop | Out-Null } }
            $infs = @(Get-ChildItem -LiteralPath $dest -Recurse -Filter *.inf -ErrorAction SilentlyContinue).Count
            $size = [double](Get-ChildItem -LiteralPath $dest -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
            $cs = Get-CimInstance Win32_ComputerSystem
            $txt = @(
                'RESPALDO DE DRIVERS - MG Toolkit (Matthew Garay)',
                ('Fecha : ' + (Get-Date -Format 'dd/MM/yyyy HH:mm')),
                ('Equipo: ' + $env:COMPUTERNAME + ' - ' + $cs.Manufacturer + ' ' + $cs.Model),
                ('Drivers: ' + $infs),
                '',
                'COMO RESTAURAR:',
                '  1. Abre MG Toolkit en el equipo ya formateado.',
                '  2. Elige "Respaldar / restaurar drivers" > opcion 2.',
                '  3. Escribe la ruta de esta carpeta.',
                '  Usar SOLO en este mismo modelo de equipo.')
            Set-Content -LiteralPath (Join-Path $dest 'LEEME.txt') -Value $txt -Encoding ASCII
            if ($infs -gt 0) {
                Write-Host ('  Listo: ' + $infs + ' drivers (' + (Format-Size $size) + ') guardados en ' + $dest) -ForegroundColor Green
                Write-Log ('Drivers respaldados: ' + $infs + ' en ' + $dest)
            } else { Write-Host '  No se copio ningun driver. Revisa el mensaje de arriba.' -ForegroundColor Red }
        }
        '2' {
            $src = Read-Host '  Ruta de la carpeta del respaldo (ej: E:\Drivers_PC_2026-11-17)'
            if (-not $src -or -not (Test-Path -LiteralPath $src)) { Write-Host '  Esa carpeta no existe.' -ForegroundColor Red; return }
            $infs = @(Get-ChildItem -LiteralPath $src -Recurse -Filter *.inf -ErrorAction SilentlyContinue).Count
            if ($infs -eq 0) { Write-Host '  En esa carpeta no hay drivers (archivos .inf).' -ForegroundColor Red; return }
            Write-Host ('  Se encontraron ' + $infs + ' drivers. Windows solo instala los que corresponden al hardware de este equipo.')
            if (Confirm-Action 'Instalar los drivers del respaldo?') {
                if ($global:IsWin10) { Invoke-Live 'Instalar drivers (puede tardar varios minutos)' 'pnputil.exe' ('/add-driver "' + (Join-Path $src '*.inf') + '" /subdirs /install') }
                else {
                    foreach ($inf in @(Get-ChildItem -LiteralPath $src -Recurse -Filter *.inf -ErrorAction SilentlyContinue)) {
                        Invoke-Live ('Instalar ' + $inf.Name) 'pnputil.exe' ('-i -a "' + $inf.FullName + '"')
                    }
                }
                Write-Host '  Reinicia el equipo al terminar.' -ForegroundColor Yellow
            }
        }
    }
}

# ---------------------------------------------------------------------
#   5. RESPALDO DE ARCHIVOS DEL USUARIO (solo COPIA, nunca borra ni mueve)
# ---------------------------------------------------------------------
function T-BackupFiles {
    Write-Section 'Respaldar archivos del usuario'
    $skip = @('Public', 'Default', 'Default User', 'All Users', 'defaultuser0', 'Todos los usuarios', 'Acceso publico')
    $users = @(Get-ChildItem -LiteralPath "$env:SystemDrive\Users" -Directory -Force -ErrorAction SilentlyContinue | Where-Object {
        ($skip) -notcontains ($_.Name) -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -and (Test-Path -LiteralPath (Join-Path $_.FullName 'NTUSER.DAT'))
    })
    if ($users.Count -eq 0) { Write-Host '  No se encontraron usuarios.' -ForegroundColor Red; return }
    for ($i = 0; $i -lt $users.Count; $i++) { Write-Host ('   {0}. {1}' -f ($i + 1), $users[$i].Name) }
    $n = 0
    if (-not [int]::TryParse((Read-Host '  Numero del usuario a respaldar'), [ref]$n) -or $n -lt 1 -or $n -gt $users.Count) { Write-Host '  Cancelado.'; return }
    $u = $users[$n - 1]; $prof = $u.FullName

    $src = @()
    foreach ($f in @(@('Escritorio', 'Desktop'), @('Documentos', 'Documents'), @('Imagenes', 'Pictures'), @('Musica', 'Music'), @('Videos', 'Videos'), @('Descargas', 'Downloads'))) {
        $p = Join-Path $prof $f[1]
        if (Test-Path -LiteralPath $p) { $src += (New-Object PSObject -Property @{ N = $f[0]; P = $p; Size = [double]0; Count = 0 }) }
    }
    foreach ($od in @(Get-ChildItem -LiteralPath $prof -Directory -Filter 'OneDrive*' -ErrorAction SilentlyContinue)) {
        foreach ($sub in @(Get-ChildItem -LiteralPath $od.FullName -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(Desktop|Escritorio|Documents|Documentos|Pictures|Im.genes)$' })) {
            $src += (New-Object PSObject -Property @{ N = ($od.Name + ' - ' + $sub.Name); P = $sub.FullName; Size = [double]0; Count = 0 })
        }
    }

    Write-Host ''
    Write-Host '  Calculando cuanto ocupa...'
    $skipMask = 0x1000 -bor 0x40000 -bor 0x400000   # archivos que solo estan en la nube (OneDrive)
    $total = [double]0
    foreach ($s in $src) {
        foreach ($file in @(Get-ChildItem -LiteralPath $s.P -Recurse -File -Force -ErrorAction SilentlyContinue)) {
            if (([int64]$file.Attributes -band $skipMask) -eq 0) { $s.Size += $file.Length; $s.Count++ }
        }
        Write-Host ('   - {0,-32} {1,10}  ({2} archivos)' -f $s.N, (Format-Size $s.Size), $s.Count)
        $total += $s.Size
    }
    Write-Host ('   TOTAL: ' + (Format-Size $total)) -ForegroundColor White
    Write-Host '  Los archivos que solo estan en la nube de OneDrive no se copian (ya estan guardados alla).' -ForegroundColor DarkGray
    Write-Host '  Cierra Outlook y los programas abiertos para que no quede ningun archivo sin copiar.' -ForegroundColor DarkGray

    $base = Select-Destination 'el respaldo' $total
    if (-not $base) { Write-Host '  Cancelado.'; return }
    if ($base.TrimEnd('\').StartsWith($prof, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Host '  No se puede guardar el respaldo dentro de la carpeta del mismo usuario. Elige una USB u otro disco.' -ForegroundColor Red
        return
    }
    $dest = Join-Path $base ('Respaldo_' + $u.Name + '_' + $env:COMPUTERNAME + '_' + (Get-Date -Format 'yyyy-MM-dd_HHmm'))
    $rcLog = Join-Path $global:LogDir ('robocopy_' + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + '.txt')

    foreach ($s in $src) {
        $d = Join-Path $dest $s.N
        $rcArgs = '"' + $s.P + '" "' + $d + '" /E /COPY:DAT /DCOPY:T /R:1 /W:1 /XJ /XA:O /MT:8 /NP /NDL /NFL /XF desktop.ini thumbs.db /LOG+:"' + $rcLog + '" /TEE'
        if ($global:DryRun) { $rcArgs += ' /L'; Write-Host ('  [SIM] Copiar ' + $s.N + ' (solo lista, no copia)') -ForegroundColor DarkYellow }
        else { Write-Host ('  -> Copiando ' + $s.N + '...') }
        $p = Start-Process -FilePath robocopy.exe -ArgumentList $rcArgs -NoNewWindow -Wait -PassThru
        if ($p.ExitCode -ge 8) {
            $global:Warnings++
            Add-Result 'AVISO' ('Respaldo ' + $s.N) ('robocopy codigo ' + $p.ExitCode + ', ver ' + $rcLog)
            Write-Host '     Algunos archivos no se pudieron copiar (en uso o sin permiso). Ver log de robocopy.' -ForegroundColor Yellow
        } else { Add-Result 'OK' ('Respaldo ' + $s.N) '' }
    }

    $bm = @()
    foreach ($pat in @("$prof\AppData\Local\Google\Chrome\User Data\*\Bookmarks",
                       "$prof\AppData\Local\Microsoft\Edge\User Data\*\Bookmarks",
                       "$prof\AppData\Local\BraveSoftware\Brave-Browser\User Data\*\Bookmarks",
                       "$prof\AppData\Roaming\Mozilla\Firefox\Profiles\*\places.sqlite")) {
        foreach ($r in @(Resolve-Path -Path $pat -ErrorAction SilentlyContinue)) { $bm += $r.ProviderPath }
    }
    if ($bm.Count -gt 0) {
        Step ('Copiar favoritos de los navegadores (' + $bm.Count + ' perfil(es))') {
            $bd = Join-Path $dest 'Favoritos de navegadores'
            New-Item -ItemType Directory -Path $bd -Force | Out-Null
            foreach ($f in $bm) {
                $parts = $f.Split('\')
                Copy-Item -LiteralPath $f -Destination (Join-Path $bd ($parts[-4] + '_' + $parts[-2] + '_' + $parts[-1])) -Force -ErrorAction Stop
            }
        }
    }

    if ($global:DryRun) { return }
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    $lines = @('RESPALDO DE ARCHIVOS - MG Toolkit (Matthew Garay)', ('Fecha  : ' + (Get-Date -Format 'dd/MM/yyyy HH:mm')), ('Equipo : ' + $env:COMPUTERNAME), ('Usuario: ' + $u.Name), '', 'Carpetas copiadas:')
    foreach ($s in $src) { $lines += ('  - ' + $s.N + '  (' + (Format-Size $s.Size) + ', ' + $s.Count + ' archivos)') }
    $lines += @('', 'COMO RESTAURAR:',
        '  Copia el contenido de cada carpeta a la carpeta del mismo nombre del usuario en el equipo nuevo.',
        '  Favoritos de Chrome/Edge/Brave: con el navegador CERRADO, copia el archivo a',
        '  C:\Users\<usuario>\AppData\Local\<navegador>\User Data\Default\ y renombralo a "Bookmarks".')
    Set-Content -LiteralPath (Join-Path $dest 'LEEME.txt') -Value $lines -Encoding ASCII
    $copied = [double](Get-ChildItem -LiteralPath $dest -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Write-Host ''
    Write-Host ('  Respaldo terminado: ' + (Format-Size $copied) + ' copiados en ' + $dest) -ForegroundColor Green
    Write-Log ('Respaldo de ' + $u.Name + ': ' + (Format-Size $copied) + ' en ' + $dest)
    if ($copied -lt ($total * 0.97)) {
        Write-Host ('  ATENCION: se copio menos de lo esperado (' + (Format-Size $total) + '). Revisa el log: ' + $rcLog) -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------
#   6. BUSCAR ARCHIVOS GRANDES (solo muestra, nunca borra)
# ---------------------------------------------------------------------
function Find-BigFiles([string]$root, [double]$minBytes = 250MB) {
    $big = New-Object System.Collections.ArrayList
    $lvl1 = @{}; $lvl2 = @{}
    $stack = New-Object System.Collections.Stack
    $stack.Push((New-Object System.IO.DirectoryInfo($root)))
    $rootLen = $root.TrimEnd('\').Length + 1
    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        try {
            foreach ($f in $dir.GetFiles()) {
                $len = $f.Length
                $seg = $f.FullName.Substring($rootLen).Split('\')
                if ($seg.Count -gt 1) {
                    $lvl1[$seg[0]] = [double]$lvl1[$seg[0]] + $len
                    if ($seg.Count -gt 2) { $k2 = $seg[0] + '\' + $seg[1]; $lvl2[$k2] = [double]$lvl2[$k2] + $len }
                }
                if ($len -ge $minBytes) { [void]$big.Add((New-Object PSObject -Property @{ Ruta = $f.FullName; Bytes = $len; Fecha = $f.LastWriteTime })) }
            }
        } catch {}
        try {
            foreach ($sd in $dir.GetDirectories()) {
                if (-not ($sd.Attributes -band [IO.FileAttributes]::ReparsePoint)) { $stack.Push($sd) }
            }
        } catch {}
    }
    return (New-Object PSObject -Property @{ Big = $big; L1 = $lvl1; L2 = $lvl2 })
}

function T-BigFiles {
    Write-Section 'Buscar archivos grandes (no borra nada)'
    $drv = Read-Host '  Letra de la unidad a revisar (ENTER = C)'
    if (-not $drv) { $drv = $env:SystemDrive }
    $root = $drv.Trim().TrimEnd('\').TrimEnd(':') + ':\'
    if (-not (Test-Path -LiteralPath $root)) { Write-Host '  Esa unidad no existe.' -ForegroundColor Red; return }
    Write-Host '  Revisando todo el disco... puede tardar de 1 a 10 minutos segun la cantidad de archivos.'
    $r = Find-BigFiles $root 250MB
    Write-Host ''
    Write-Host '  CARPETAS QUE MAS OCUPAN:' -ForegroundColor Cyan
    foreach ($e in @($r.L2.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 15)) {
        Write-Host ('   {0,10}   {1}' -f (Format-Size $e.Value), ($root + $e.Key))
    }
    Write-Host ''
    Write-Host '  ARCHIVOS DE MAS DE 250 MB:' -ForegroundColor Cyan
    $list = @($r.Big | Sort-Object Bytes -Descending | Select-Object -First 30)
    if ($list.Count -eq 0) { Write-Host '   Ninguno.' }
    for ($i = 0; $i -lt $list.Count; $i++) {
        $note = ''
        if ($list[$i].Ruta -match '\\(pagefile|hiberfil|swapfile)\.sys$' -or $list[$i].Ruta.StartsWith($env:SystemRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { $note = '   (de Windows, NO borrar)' }
        Write-Host ('  {0,2}. {1,10}  {2:dd/MM/yyyy}  {3}{4}' -f ($i + 1), (Format-Size $list[$i].Bytes), $list[$i].Fecha, $list[$i].Ruta, $note)
    }
    Write-Log ('Archivos grandes en ' + $root + ': ' + $list.Count)
    Write-Host ''
    Write-Host '  Esta herramienta NO borra nada. Revisa con el usuario que se puede borrar o mover a otro disco.' -ForegroundColor DarkGray
    while ($list.Count -gt 0) {
        $s = Read-Host '  Numero de un archivo para abrir su carpeta (ENTER = salir)'
        $n = 0
        if (-not [int]::TryParse($s, [ref]$n) -or $n -lt 1 -or $n -gt $list.Count) { break }
        Start-Process explorer.exe ('/select,"' + $list[$n - 1].Ruta + '"')
    }
}

# ---------------------------------------------------------------------
#   7. MEDIR VELOCIDAD DEL DISCO (winsat de Windows)
# ---------------------------------------------------------------------
function T-DiskSpeed {
    Write-Section 'Medir velocidad del disco'
    if (-not (Get-Command winsat.exe -ErrorAction SilentlyContinue)) { Write-Host '  La herramienta de medicion de Windows no esta disponible.' -ForegroundColor Red; return }
    $drv = Read-Host '  Letra de la unidad a medir (ENTER = C)'
    if (-not $drv) { $drv = $env:SystemDrive }
    $letter = $drv.Trim().TrimEnd('\').TrimEnd(':')
    if ($global:DryRun) { Write-Host ('  [SIM] Medir velocidad de la unidad ' + $letter + ':') -ForegroundColor DarkYellow; return }
    Write-Host '  Midiendo... tarda 1-2 minutos. No uses el equipo mientras tanto.'
    $out = (& winsat.exe disk -drive $letter 2>&1 | Out-String)
    $res = @{}
    foreach ($m in [regex]::Matches($out, 'Disk\s+(Random|Sequential)\s+[\d\.,]+\s+(Read|Write)\s+([\d\.,]+)\s+MB/s')) {
        $res[$m.Groups[1].Value + ' ' + $m.Groups[2].Value] = [double]::Parse($m.Groups[3].Value.Replace(',', '.'), [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($res.Count -eq 0) {
        Write-Host '  No se pudo medir. Mensaje de Windows:' -ForegroundColor Red
        Write-Host $out
        Write-Log ('winsat sin resultados: ' + $out)
        return
    }
    $label = @{
        'Sequential Read'  = 'Lectura de archivos grandes'
        'Sequential Write' = 'Escritura de archivos grandes'
        'Random Read'      = 'Lectura de archivos pequenos (Windows y programas)'
        'Random Write'     = 'Escritura de archivos pequenos'
    }
    Write-Host ''
    foreach ($k in @('Sequential Read', 'Sequential Write', 'Random Read', 'Random Write')) {
        if (-not $res.ContainsKey($k)) { continue }
        $t = $label[$k]; if (-not $t) { $t = $k }
        Write-Host ('   {0,-52} {1,8:N0} MB/s' -f $t, $res[$k])
        Write-Log ('Velocidad ' + $letter + ': ' + $k + ' = ' + $res[$k] + ' MB/s')
    }
    $seq = [double]$res['Sequential Read']
    Write-Host ''
    if ($seq -lt 200)     { Write-Host '  RESULTADO: LENTO. Es la velocidad de un disco mecanico (HDD). Cambiarlo por un SSD hara el equipo mucho mas rapido.' -ForegroundColor Red }
    elseif ($seq -lt 1000) { Write-Host '  RESULTADO: BUENO. Velocidad normal de un SSD SATA.' -ForegroundColor Green }
    else                   { Write-Host '  RESULTADO: EXCELENTE. Velocidad de un SSD NVMe.' -ForegroundColor Green }
}

# ---------------------------------------------------------------------
#   8. REDES WIFI GUARDADAS Y REPORTE WIFI
# ---------------------------------------------------------------------
function Get-WifiProfiles {
    $tmp = Join-Path "$env:SystemRoot\Temp" ('maxpc_' + [guid]::NewGuid().ToString('N'))
    $nets = @()
    try {
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $null = netsh wlan export profile key=clear folder=$tmp
        foreach ($x in @(Get-ChildItem -LiteralPath $tmp -Filter *.xml -ErrorAction SilentlyContinue)) {
            [xml]$doc = [IO.File]::ReadAllText($x.FullName)
            $p = $doc.WLANProfile
            $auth = [string]$p.MSM.security.authEncryption.authentication
            $key  = [string]$p.MSM.security.sharedKey.keyMaterial
            if ($auth -eq 'open') { $key = '(red abierta, sin contrasena)' }
            elseif (-not $key) { $key = '(red de empresa / no disponible)' }
            $nets += (New-Object PSObject -Property @{ Red = [string]$p.name; Seguridad = $auth; Contrasena = $key })
        }
    } finally {
        # Los archivos exportados tienen contrasenas: se borran siempre, aunque algo falle
        try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction Stop }
        catch {
            foreach ($x in @(Get-ChildItem -LiteralPath $tmp -File -ErrorAction SilentlyContinue)) { try { Remove-Item -LiteralPath $x.FullName -Force -ErrorAction Stop } catch {} }
            try { Remove-Item -LiteralPath $tmp -Force -ErrorAction Stop } catch {}
        }
    }
    return $nets
}

function T-Wifi {
    Write-Section 'Redes WiFi guardadas y contrasenas'
    $svc = Get-Service -Name WlanSvc -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Host '  Este equipo no tiene WiFi.'; return }
    if ([string]$svc.Status -ne 'Running') { try { Start-Service -Name WlanSvc -ErrorAction Stop } catch {} }
    $nets = @(Get-WifiProfiles)
    if ($nets.Count -eq 0) { Write-Host '  No hay redes WiFi guardadas.' }
    else {
        Write-Host '  NO compartas esta pantalla: muestra contrasenas.' -ForegroundColor Yellow
        $nets | Sort-Object Red | Select-Object Red, Seguridad, Contrasena | Show-Table
        Write-Log ('Redes WiFi guardadas: ' + $nets.Count + ' (las contrasenas NO se guardan en el log)')
    }
    if ($global:IsWin8 -and (Confirm-Action 'Generar el reporte de problemas de WiFi de los ultimos 3 dias?')) {
        Step 'Generar reporte WiFi' { netsh wlan show wlanreport }
        $rep = "$env:ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html"
        if (-not $global:DryRun -and (Test-Path -LiteralPath $rep)) { Start-Process $rep }
    }
}

# ---------------------------------------------------------------------
#   9. DESTRABAR LA IMPRESORA
# ---------------------------------------------------------------------
function T-Printer {
    Write-Section 'Destrabar la impresora'
    $spool = "$env:SystemRoot\System32\spool\PRINTERS"
    $jobs = @(Get-ChildItem -LiteralPath $spool -File -ErrorAction SilentlyContinue).Count
    Write-Host ('  Documentos atascados en la cola: ' + [math]::Ceiling($jobs / 2))
    Step 'Detener la cola de impresion' { Stop-Service -Name Spooler -Force -ErrorAction Stop }
    Clear-Folder 'Documentos atascados' @($spool)
    Step 'Iniciar la cola de impresion' { Start-Service -Name Spooler -ErrorAction Stop }
    $pr = @(Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'PDF|XPS|OneNote|Fax' })
    if ($pr.Count -gt 0) {
        Write-Host ''
        Write-Host '  Impresoras instaladas:' -ForegroundColor Cyan
        foreach ($p in $pr) { $st = 'lista'; if ($p.WorkOffline) { $st = 'SIN CONEXION' }; Write-Host ('   - {0}   ({1})' -f $p.Name, $st) }
    }
    Write-Host ''
    Write-Host '  Si sigue sin imprimir: apaga y enciende la impresora, revisa el cable o el WiFi,' -ForegroundColor DarkGray
    Write-Host '  y si no funciona, reinstala el driver desde la web del fabricante de la impresora.' -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------
#   10. REPARAR WINDOWS UPDATE (procedimiento oficial de Microsoft)
# ---------------------------------------------------------------------
function Rename-WithRetry([string]$path, [string]$newName, [string[]]$services) {
    if (-not (Test-Path -LiteralPath $path)) { return }
    for ($i = 0; $i -lt 6; $i++) {
        foreach ($s in $services) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }
        try { Rename-Item -LiteralPath $path -NewName $newName -ErrorAction Stop; return } catch { Start-Sleep -Seconds 2 }
    }
    throw ('No se pudo renombrar ' + $path + ' porque esta en uso. Reinicia el equipo y vuelve a intentar.')
}

function T-WUReset {
    Write-Section 'Reparar Windows Update'
    Write-Host '  Detiene Windows Update, RENOMBRA (no borra) sus carpetas de cache y lo vuelve a iniciar.' -ForegroundColor DarkGray
    Write-Host '  Es el procedimiento oficial de Microsoft cuando Update da errores o se queda trabado.' -ForegroundColor DarkGray
    $stamp = Get-Date -Format 'yyyyMMdd_HHmm'
    Step 'Detener los servicios de Windows Update' { foreach ($s in @('wuauserv', 'bits', 'usosvc', 'cryptsvc', 'msiserver')) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue } }
    Step 'Renombrar la cache de Windows Update (SoftwareDistribution)' { Rename-WithRetry "$env:SystemRoot\SoftwareDistribution" ('SoftwareDistribution.old_' + $stamp) @('wuauserv', 'bits', 'usosvc') }
    Step 'Renombrar la cache de firmas (catroot2)' { Rename-WithRetry "$env:SystemRoot\System32\catroot2" ('catroot2.old_' + $stamp) @('cryptsvc') }
    Step 'Iniciar los servicios de Windows Update' { foreach ($s in @('cryptsvc', 'bits', 'wuauserv')) { Start-Service -Name $s -ErrorAction SilentlyContinue } }
    Step 'Borrar copias viejas (.old) de mas de 30 dias' {
        $lim = (Get-Date).AddDays(-30)
        foreach ($o in @(Get-ChildItem -LiteralPath $env:SystemRoot -Directory -Filter 'SoftwareDistribution.old_*' -ErrorAction SilentlyContinue) + @(Get-ChildItem -LiteralPath "$env:SystemRoot\System32" -Directory -Filter 'catroot2.old_*' -ErrorAction SilentlyContinue)) {
            if ($o.CreationTime -lt $lim) { Remove-Item -LiteralPath $o.FullName -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
    if ($global:IsWin10) { Step 'Pedir a Windows que busque actualizaciones' { Start-Process -FilePath "$env:SystemRoot\System32\UsoClient.exe" -ArgumentList 'StartScan' -WindowStyle Hidden -ErrorAction Stop } }
    else { Step 'Pedir a Windows que busque actualizaciones' { Start-Process -FilePath "$env:SystemRoot\System32\wuauclt.exe" -ArgumentList '/detectnow' -WindowStyle Hidden -ErrorAction Stop } }
    Write-Host '  Listo. Abre Configuracion > Windows Update y pulsa "Buscar actualizaciones".' -ForegroundColor Green
    Write-Host '  (El historial de actualizaciones puede aparecer vacio: es normal, las actualizaciones siguen instaladas.)' -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------
#   11. MANTENIMIENTO AUTOMATICO SEMANAL (tarea programada)
#   Solo hace cosas seguras: temporales de mas de 1 dia, volcados de memoria,
#   cache DNS y analisis rapido de virus. No cierra programas ni reinicia.
# ---------------------------------------------------------------------
$global:TaskName   = 'MG Toolkit - Mantenimiento semanal'
$global:InstallDir = Join-Path $env:ProgramData 'MGToolkit'

function Invoke-Maintenance {
    $global:Auto = $true
    Write-Log '##### MANTENIMIENTO SEMANAL AUTOMATICO #####'
    M1-UserTemp; M1-WinTemp; M1-Dumps; M1-DNS
    $mp = Get-DefenderStatus
    if ($mp -and $mp.AntivirusEnabled) {
        try { Update-MpSignature -ErrorAction Stop } catch {}
        try { Start-MpScan -ScanType QuickScan -ErrorAction Stop; Write-Log '[OK] Analisis rapido de virus' } catch { Write-Log ('[AVISO] Analisis de virus: ' + $_.Exception.Message) }
    } elseif (Get-MpCmdRun) {
        $null = & (Get-MpCmdRun) -SignatureUpdate 2>&1
        $null = & (Get-MpCmdRun) -Scan -ScanType 1 2>&1
        Write-Log ('[OK] Analisis rapido de virus (codigo ' + $LASTEXITCODE + ', 2 = amenazas encontradas)')
    }
    foreach ($old in @(Get-ChildItem -LiteralPath $global:LogDir -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-90) })) {
        Remove-Item -LiteralPath $old.FullName -Force -ErrorAction SilentlyContinue
    }
    Write-Log ('##### FIN MANTENIMIENTO: liberado ' + (Format-Size $global:Freed) + ' #####')
}

function Test-MaintTask { $null = schtasks.exe /Query /TN $global:TaskName 2>&1; return ($LASTEXITCODE -eq 0) }

function New-MaintTaskXml([string]$day, [int]$hour, [string]$bat, [string]$userId = 'S-1-5-18', [string]$runLevel = 'HighestAvailable') {
    $start = [datetime]::Today.AddHours($hour).ToString("yyyy-MM-dd'T'HH:mm:ss")
    return @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>Limpieza segura y analisis de virus semanal. Creado por MG Toolkit (Matthew Garay).</Description></RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>$start</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByWeek><DaysOfWeek><$day /></DaysOfWeek><WeeksInterval>1</WeeksInterval></ScheduleByWeek>
    </CalendarTrigger>
  </Triggers>
  <Principals><Principal id="Author"><UserId>$userId</UserId><RunLevel>$runLevel</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <ExecutionTimeLimit>PT2H</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author"><Exec><Command>cmd.exe</Command><Arguments>/c $bat --mantenimiento</Arguments></Exec></Actions>
</Task>
"@
}

function T-Schedule {
    Write-Section 'Mantenimiento automatico semanal'
    Write-Host '  Que hace cada semana, sin molestar al usuario:' -ForegroundColor Gray
    Write-Host '   - Borra temporales con mas de 1 dia, volcados de memoria y cache DNS' -ForegroundColor Gray
    Write-Host '   - Analisis rapido de virus con el antivirus de Microsoft (si esta activo)' -ForegroundColor Gray
    Write-Host '  NO cierra programas, NO reinicia y NO cambia ninguna configuracion.' -ForegroundColor Gray
    $exists = Test-MaintTask
    Write-Host ''
    if ($exists) {
        Write-Host '  Estado: ACTIVADO.' -ForegroundColor Green
        schtasks.exe /Query /TN $global:TaskName /FO LIST | Out-String | Write-Host
    } else { Write-Host '  Estado: DESACTIVADO.' -ForegroundColor Yellow }
    Write-Host ''
    Write-Host '   1. Activar / cambiar dia y hora'
    Write-Host '   2. Desactivar (borrar la tarea)'
    Write-Host '   3. Ejecutarlo ahora para probar'
    Write-Host '   4. Ver los registros del mantenimiento'
    Write-Host '   0. Volver'
    switch ((Read-Host '  Opcion').Trim()) {
        '1' {
            $days = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')
            $dias = @('lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo')
            $dn = 0; $d = Read-Host '  Dia (1=lunes 2=martes 3=miercoles 4=jueves 5=viernes 6=sabado 7=domingo, ENTER = 3)'
            if (-not [int]::TryParse($d, [ref]$dn) -or $dn -lt 1 -or $dn -gt 7) { $dn = 3 }
            $hn = 0; $h = Read-Host '  Hora (0 a 23, ENTER = 12)'
            if (-not [int]::TryParse($h, [ref]$hn) -or $hn -lt 0 -or $hn -gt 23) { $hn = 12 }
            $bat = Join-Path $global:InstallDir 'MGToolkit.bat'
            Step ('Copiar MG Toolkit a ' + $global:InstallDir) {
                New-Item -ItemType Directory -Path $global:InstallDir -Force | Out-Null
                Copy-Item -LiteralPath $env:OPT_SELF -Destination $bat -Force -ErrorAction Stop
            }
            $xmlFile = Join-Path $env:TEMP 'MGToolkit_tarea.xml'
            Step ('Programar el mantenimiento: ' + $dias[$dn - 1] + ' a las ' + $hn + ':00') {
                [IO.File]::WriteAllText($xmlFile, (New-MaintTaskXml $days[$dn - 1] $hn $bat), [Text.Encoding]::Unicode)
                schtasks.exe /Create /TN $global:TaskName /XML $xmlFile /F
            }
            Remove-Item -LiteralPath $xmlFile -Force -ErrorAction SilentlyContinue
            Write-Host '  Si el equipo esta apagado a esa hora, se hace la proxima vez que se encienda.' -ForegroundColor DarkGray
        }
        '2' {
            if (-not $exists) { Write-Host '  No estaba activado.'; return }
            Step 'Borrar la tarea de mantenimiento' { schtasks.exe /Delete /TN $global:TaskName /F }
        }
        '3' {
            if (-not $exists) { Write-Host '  Primero activalo con la opcion 1.' -ForegroundColor Yellow; return }
            Step 'Iniciar el mantenimiento ahora (corre en segundo plano)' { schtasks.exe /Run /TN $global:TaskName }
            Write-Host ('  Revisa el resultado en unos minutos en: ' + (Join-Path $global:InstallDir 'Logs')) -ForegroundColor Gray
        }
        '4' {
            $ld = Join-Path $global:InstallDir 'Logs'
            if (Test-Path -LiteralPath $ld) { Start-Process explorer.exe $ld } else { Write-Host '  Todavia no hay registros: el mantenimiento no se ha ejecutado.' }
        }
    }
}
# =====================================================================
#   RED, SEGURIDAD Y SISTEMA (opciones 43 a 53) - compatibles con Windows 7 a 11
# =====================================================================

# Conexiones de red activas (con puerta de enlace). Get-WmiObject para poder usar sus metodos.
function Get-ActiveAdapters {
    @(Get-WmiObject Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = TRUE' -ErrorAction SilentlyContinue | Where-Object { $_.DefaultIPGateway })
}

function Test-Ping([string]$target, [int]$count = 10) {
    $times = @(); $ok = 0; $netOk = $true
    try { $ping = New-Object System.Net.NetworkInformation.Ping } catch { $netOk = $false }
    if ($netOk) {
        for ($i = 0; $i -lt $count; $i++) {
            try { $r = $ping.Send($target, 1500); if ([string]$r.Status -eq 'Success') { $ok++; $times += [int]$r.RoundtripTime } }
            catch { if ($_.Exception.InnerException -isnot [System.Net.NetworkInformation.PingException] -or $i -eq 0) { $netOk = $false; break } }
        }
    }
    if (-not $netOk) {
        # Plan B: el comando ping de Windows (las lineas con "TTL=" son respuestas, en cualquier idioma)
        $times = @(); $ok = 0
        foreach ($l in @(ping.exe -n $count -w 1500 $target 2>&1)) {
            if ([string]$l -match 'TTL=') { $ok++; if ([string]$l -match '[=<](\d+)\s*ms') { $times += [int]$matches[1] } }
        }
    }
    $avg = -1; $max = -1
    if ($times.Count -gt 0) { $m = $times | Measure-Object -Average -Maximum; $avg = [math]::Round($m.Average); $max = [int]$m.Maximum }
    return (New-Object PSObject -Property @{ Ok = $ok; Total = $count; Loss = [math]::Round(100 * ($count - $ok) / $count); Avg = $avg; Max = $max })
}

# Comprueba que el DNS resuelva un nombre. Plan B con ping.exe si .NET no puede usar la red.
function Test-DnsName([string]$name) {
    try { $null = [System.Net.Dns]::GetHostAddresses($name); return $true } catch {}
    $o = ping.exe -n 1 -w 1000 $name 2>&1 | Out-String
    return ($o -match '\[[0-9a-fA-F\.:]+\]')
}

function Format-PingResult($r) {
    if ($r.Ok -eq 0) { return 'NO RESPONDE' }
    return ('{0} ms promedio, {1}% de perdida' -f $r.Avg, $r.Loss)
}

# Descarga 10 MB y calcula la velocidad (Mbps). Si HTTPS no funciona (Windows 7 viejo) usa un servidor HTTP.
function Measure-Download {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch {}
    foreach ($url in @('https://speed.cloudflare.com/__down?bytes=10000000', 'http://speed.cloudflare.com/__down?bytes=10000000', 'http://cachefly.cachefly.net/10mb.test')) {
        try {
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add('User-Agent', 'MG-Toolkit')
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $data = $wc.DownloadData($url)
            $sw.Stop()
            if ($data.Length -gt 1000000 -and $sw.Elapsed.TotalSeconds -gt 0) { return [math]::Round($data.Length * 8 / $sw.Elapsed.TotalSeconds / 1000000, 1) }
        } catch {}
    }
    return -1
}

function T-SpeedTest {
    Write-Section 'Probar la conexion a internet'
    $ad = @(Get-ActiveAdapters)
    if ($ad.Count -eq 0) { Write-Host '  No hay ninguna conexion de red activa (revisa el cable o la WiFi).' -ForegroundColor Red; return }
    $gw = [string]@($ad[0].DefaultIPGateway)[0]
    Write-Host ('  Conexion: ' + $ad[0].Description) -ForegroundColor Gray
    Write-Host '  1/4 Probando la conexion con el router...'
    $r1 = Test-Ping $gw 10
    Write-Host '  2/4 Probando la conexion a internet...'
    $r2 = Test-Ping '1.1.1.1' 10
    Write-Host '  3/4 Probando el DNS...'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $dnsOk = Test-DnsName 'www.wikipedia.org'
    $sw.Stop(); $dnsMs = [int]$sw.Elapsed.TotalMilliseconds
    $mbps = -1
    if ($r2.Ok -gt 0) { Write-Host '  4/4 Midiendo la velocidad de descarga (descarga 10 MB)...'; $mbps = Measure-Download }
    $dnsTxt = 'NO RESPONDE'; if ($dnsOk) { $dnsTxt = [string]$dnsMs + ' ms' }
    $spTxt = 'no se pudo medir'; if ($mbps -ge 0) { $spTxt = [string]$mbps + ' Mbps' }
    Write-Host ''
    Write-Host (('   Router ({0})' -f $gw).PadRight(32)) -NoNewline; Write-Host (Format-PingResult $r1)
    Write-Host ('   Internet (1.1.1.1)'.PadRight(32)) -NoNewline; Write-Host (Format-PingResult $r2)
    Write-Host ('   DNS'.PadRight(32)) -NoNewline; Write-Host $dnsTxt
    Write-Host ('   Velocidad de descarga'.PadRight(32)) -NoNewline; Write-Host $spTxt
    Write-Log ('Internet: router ' + (Format-PingResult $r1) + ' | internet ' + (Format-PingResult $r2) + ' | DNS ' + $dnsTxt + ' | descarga ' + $spTxt)
    Write-Host ''
    $good = $true
    if ($r1.Ok -eq 0) { $good = $false; Write-Host '  - El router no responde. Revisa el cable o la WiFi (algunos routers no responden a esta prueba: si internet funciona, ignoralo).' -ForegroundColor Yellow }
    elseif ($r1.Loss -gt 0 -or $r1.Avg -gt 20) { $good = $false; Write-Host '  - La conexion con el router es inestable: senal WiFi debil o cable danado. Acercate al router o usa cable.' -ForegroundColor Yellow }
    if ($r2.Ok -eq 0) { $good = $false; Write-Host '  - No hay internet. Reinicia el router; si sigue igual, usa la opcion 28 o llama al proveedor.' -ForegroundColor Red }
    elseif ($r2.Loss -gt 5 -or $r2.Avg -gt 100) { $good = $false; Write-Host '  - Internet inestable o con mucha demora: puede ser el proveedor o la red saturada.' -ForegroundColor Yellow }
    if (-not $dnsOk) { $good = $false; Write-Host '  - El DNS no responde: usa la opcion 44 (Cambiar DNS).' -ForegroundColor Yellow }
    elseif ($dnsMs -gt 300) { $good = $false; Write-Host '  - El DNS es lento: la opcion 44 puede hacer que las paginas empiecen a cargar antes.' -ForegroundColor Yellow }
    if ($mbps -ge 0 -and $mbps -lt 5) { $good = $false; Write-Host '  - Velocidad muy baja: compara con el plan contratado; prueba con cable para descartar la WiFi.' -ForegroundColor Yellow }
    if ($good) { Write-Host '  La conexion esta bien.' -ForegroundColor Green }
}

function T-DNS {
    Write-Section 'Cambiar los servidores DNS'
    Write-Host '  El DNS traduce el nombre de las paginas. Uno rapido hace que empiecen a cargar antes.' -ForegroundColor DarkGray
    $ad = @(Get-ActiveAdapters)
    if ($ad.Count -eq 0) { Write-Host '  No hay ninguna conexion de red activa.' -ForegroundColor Red; return }
    foreach ($a in $ad) {
        $dns = (@($a.DNSServerSearchOrder) | Where-Object { $_ }) -join ', '; if (-not $dns) { $dns = '(automatico)' }
        $mode = 'IP automatica'; if (-not $a.DHCPEnabled) { $mode = 'IP FIJA' }
        Write-Host ('   - {0}  [{1}]  DNS actual: {2}' -f $a.Description, $mode, $dns)
        Write-Log ('DNS antes en ' + $a.Description + ': ' + $dns)
    }
    Write-Host ''
    Write-Host '   1. Cloudflare  (1.1.1.1)  - el mas rapido'
    Write-Host '   2. Google      (8.8.8.8)'
    Write-Host '   3. Automatico  (volver al DNS del router / proveedor)'
    Write-Host '   0. Volver'
    $servers = $null; $label = ''
    switch ((Read-Host '  Opcion').Trim()) {
        '1' { $servers = @('1.1.1.1', '1.0.0.1'); $label = 'Cloudflare' }
        '2' { $servers = @('8.8.8.8', '8.8.4.4'); $label = 'Google' }
        '3' { $servers = @(); $label = 'automatico' }
    }
    if ($null -eq $servers) { return }
    foreach ($a in $ad) {
        if ($servers.Count -eq 0 -and -not $a.DHCPEnabled) {
            Write-Host ('  ' + $a.Description + ': tiene IP fija, no se puede poner DNS automatico. Se deja como esta.') -ForegroundColor Yellow
            continue
        }
        Step ('DNS ' + $label + ' en ' + $a.Description) {
            if ($servers.Count -eq 0) { $rv = $a.SetDNSServerSearchOrder($null) } else { $rv = $a.SetDNSServerSearchOrder([string[]]$servers) }
            if ($rv.ReturnValue -gt 1) { throw ('Windows respondio con el codigo ' + $rv.ReturnValue) }
        }
    }
    Step 'Limpiar cache DNS' { ipconfig /flushdns }
    Write-Host '  Para deshacerlo, vuelve a esta opcion y elige 3 (Automatico).' -ForegroundColor DarkGray
}

# Conexiones TCP abiertas (netstat funciona igual de Windows 7 a 11)
function Get-NetConnections {
    $rows = @()
    foreach ($l in @(netstat -ano)) {
        if ($l -match '^\s*TCP\s+(\S+)\s+(\S+)\s+\S+\s+(\d+)\s*$') {
            $remote = $matches[2]; $procId = [int]$matches[3]
            if ($procId -eq 0 -or $remote -match '^(0\.0\.0\.0|\[::\]|127\.|\[::1\]|\*)') { continue }
            $rows += (New-Object PSObject -Property @{ ProcId = $procId; Remote = $remote })
        }
    }
    return $rows
}

function T-Connections {
    Write-Section 'Programas conectados a internet'
    $rows = @(Get-NetConnections)
    if ($rows.Count -eq 0) { Write-Host '  Ningun programa esta conectado ahora mismo.'; return }
    $warn = 0
    foreach ($g in @($rows | Group-Object ProcId | Sort-Object Count -Descending)) {
        $p = Get-Process -Id ([int]$g.Name) -ErrorAction SilentlyContinue
        $name = '(cerrado)'; $path = ''
        if ($p) { $name = $p.ProcessName; try { $path = [string]$p.Path } catch {} }
        $dest = (@($g.Group | ForEach-Object { $_.Remote -replace ':\d+$', '' } | Select-Object -Unique) | Select-Object -First 3) -join ', '
        $odd = ($path -match '\\AppData\\|\\Temp\\|\\Users\\Public\\' -and $path -notmatch '\\Microsoft\\|\\Google\\|\\Mozilla\\|\\Zoom|\\Discord|\\Spotify|\\Teams')
        $color = 'White'; if ($odd) { $color = 'Yellow'; $warn++ }
        Write-Host ('   {0,-24} {1,3} conexion(es)   {2}' -f $name, $g.Count, $dest) -ForegroundColor $color
        if ($odd) { Write-Host ('      ubicacion inusual: ' + $path) -ForegroundColor Yellow }
    }
    Write-Log ('Programas conectados: ' + @($rows | Group-Object ProcId).Count + ', con ubicacion inusual: ' + $warn)
    Write-Host ''
    if ($warn -gt 0) { Write-Host '  Los programas en amarillo se ejecutan desde una carpeta poco comun. Si no los conoces, usa la opcion 21 (Buscar virus).' -ForegroundColor Yellow }
    else { Write-Host '  No se ven programas en ubicaciones sospechosas.' -ForegroundColor Green }
}

$global:HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$global:DefaultHosts = "# Copyright (c) 1993-2009 Microsoft Corp.`r`n#`r`n# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.`r`n#`r`n# localhost name resolution is handled within DNS itself.`r`n#`t127.0.0.1       localhost`r`n#`t::1             localhost`r`n"

function Get-HostsEntries {
    if (-not (Test-Path -LiteralPath $global:HostsPath)) { return @() }
    return @([IO.File]::ReadAllLines($global:HostsPath) | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') })
}

function T-Hosts {
    Write-Section 'Revisar el archivo hosts'
    Write-Host '  Algunos virus lo modifican para llevarte a paginas falsas o bloquear el antivirus.' -ForegroundColor DarkGray
    $e = @(Get-HostsEntries)
    if ($e.Count -eq 0) { Write-Host '  El archivo hosts esta limpio (sin redirecciones).' -ForegroundColor Green; Write-Log 'hosts limpio'; return }
    Write-Host ('  Tiene ' + $e.Count + ' redireccion(es):') -ForegroundColor Yellow
    foreach ($l in ($e | Select-Object -First 25)) { Write-Host ('   ' + $l.Trim()) }
    if ($e.Count -gt 25) { Write-Host ('   ... y ' + ($e.Count - 25) + ' mas') }
    Write-Log ('hosts con ' + $e.Count + ' redirecciones')
    Write-Host '  Si las agrego un programa conocido (bloqueador de publicidad, programa de la empresa), puede ser normal.' -ForegroundColor DarkGray
    if (Confirm-Action 'Restaurar el archivo hosts original de Windows? (se guarda una copia)' $false $true) {
        $bk = Join-Path $global:LogDir ('hosts_respaldo_' + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + '.txt')
        Step ('Guardar copia en ' + $bk) { Copy-Item -LiteralPath $global:HostsPath -Destination $bk -Force -ErrorAction Stop }
        Step 'Restaurar el archivo hosts original' {
            $item = Get-Item -LiteralPath $global:HostsPath -Force
            if ($item.IsReadOnly) { $item.IsReadOnly = $false }
            [IO.File]::WriteAllText($global:HostsPath, $global:DefaultHosts, [Text.Encoding]::ASCII)
        }
        Step 'Limpiar cache DNS' { ipconfig /flushdns }
    }
}

function Get-ProxyState {
    $p = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    return (New-Object PSObject -Property @{ Enabled = ($p.ProxyEnable -eq 1); Server = [string]$p.ProxyServer; Pac = [string]$p.AutoConfigURL })
}

function T-Proxy {
    Write-Section 'Revisar el proxy'
    Write-Host '  Algunos programas de publicidad (adware) ponen un proxy para espiar o cambiar las paginas.' -ForegroundColor DarkGray
    $s = Get-ProxyState
    if (-not $s.Enabled -and -not $s.Pac) { Write-Host '  No hay proxy configurado. Todo bien.' -ForegroundColor Green; Write-Log 'Sin proxy'; return }
    if ($s.Enabled) { Write-Host ('  Proxy ACTIVO: ' + $s.Server) -ForegroundColor Yellow }
    if ($s.Pac) { Write-Host ('  Configuracion automatica: ' + $s.Pac) -ForegroundColor Yellow }
    Write-Host '  OJO: en empresas el proxy puede ser necesario. Si este equipo es de una empresa, consulta antes.' -ForegroundColor Yellow
    if (Confirm-Action 'Quitar el proxy?' $false $true) {
        Write-Log ('Proxy antes: activo=' + $s.Enabled + ' servidor=' + $s.Server + ' pac=' + $s.Pac)
        Step 'Desactivar el proxy' { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'ProxyEnable' 0 }
        Step 'Quitar la configuracion automatica' { Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name 'AutoConfigURL' -ErrorAction SilentlyContinue }
        Step 'Restablecer el proxy del sistema (WinHTTP)' { netsh winhttp reset proxy }
        Write-Host '  Cierra y vuelve a abrir el navegador.' -ForegroundColor DarkGray
    }
}

function T-Time {
    Write-Section 'Sincronizar la hora'
    Write-Host ('  Hora del equipo: ' + (Get-Date -Format 'dd/MM/yyyy HH:mm:ss') + '   Zona horaria: ' + [TimeZone]::CurrentTimeZone.StandardName)
    Write-Host '  Una hora incorrecta causa errores de "conexion no segura" y fallos de Windows Update y de activacion.' -ForegroundColor DarkGray
    $cs = Get-CimInstance Win32_ComputerSystem
    Step 'Iniciar el servicio de hora de Windows' { Set-Service -Name W32Time -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service -Name W32Time -ErrorAction Stop }
    if ($cs.PartOfDomain) { Write-Host '  El equipo es de una empresa (dominio): se sincroniza con el servidor de la empresa.' -ForegroundColor DarkGray }
    else { Step 'Usar el servidor de hora de Microsoft' { w32tm /config /syncfromflags:manual /manualpeerlist:time.windows.com /update } }
    Step 'Sincronizar ahora' { w32tm /resync; if ($LASTEXITCODE -ne 0) { Start-Sleep -Seconds 3; w32tm /resync /rediscover } }
    if (-not $global:DryRun) { Write-Host ('  Hora ahora: ' + (Get-Date -Format 'dd/MM/yyyy HH:mm:ss')) -ForegroundColor Green }
}

function T-DriverUpdates {
    Write-Section 'Actualizar drivers desde Windows Update'
    Write-Host '  Busca drivers oficiales publicados por los fabricantes en Windows Update.' -ForegroundColor DarkGray
    Write-Host '  Buscando (puede tardar unos minutos)...'
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $r = $session.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0 and Type='Driver'")
    } catch { $global:Errors++; Write-Host ('  No se pudo buscar: ' + $_.Exception.Message) -ForegroundColor Red; Write-Log ('[ERROR] Buscar drivers: ' + $_.Exception.Message); return }
    $ups = @(); foreach ($u in $r.Updates) { $ups += $u }
    if ($ups.Count -eq 0) { Write-Host '  No hay drivers nuevos en Windows Update. Para versiones mas recientes revisa la web del fabricante.' -ForegroundColor Green; return }
    for ($i = 0; $i -lt $ups.Count; $i++) { Write-Host ('   {0,2}. {1}' -f ($i + 1), $ups[$i].Title) }
    $idx = Get-Selection (Read-Host '  Numeros a instalar (ej: 1,3), T = todos, ENTER = ninguno') $ups.Count
    if ($idx.Count -eq 0) { Write-Host '  No se instalo nada.'; return }
    if (Confirm-Action 'Crear un punto de restauracion antes (recomendado)?') { X-Restore }
    if ($global:DryRun) { foreach ($i in $idx) { Write-Host ('  [SIM] Instalar ' + $ups[$i].Title) -ForegroundColor DarkYellow }; return }
    $coll = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($i in $idx) { try { if (-not $ups[$i].EulaAccepted) { $ups[$i].AcceptEula() } } catch {}; [void]$coll.Add($ups[$i]) }
    try {
        Write-Host '  Descargando...'
        $d = $session.CreateUpdateDownloader(); $d.Updates = $coll; [void]$d.Download()
        Write-Host '  Instalando...'
        $in = $session.CreateUpdateInstaller(); $in.Updates = $coll; $res = $in.Install()
        for ($k = 0; $k -lt $coll.Count; $k++) {
            $rc = $res.GetUpdateResult($k).ResultCode
            if ($rc -eq 2 -or $rc -eq 3) { Write-Host ('  OK: ' + $coll.Item($k).Title) -ForegroundColor Green; Add-Result 'OK' ('Driver: ' + $coll.Item($k).Title) '' }
            else { $global:Warnings++; Write-Host ('  NO se pudo: ' + $coll.Item($k).Title) -ForegroundColor Yellow; Add-Result 'AVISO' 'Driver' $coll.Item($k).Title }
            Write-Log ('Driver ' + $coll.Item($k).Title + ' -> codigo ' + $rc)
        }
        if ($res.RebootRequired) { Write-Host '  Reinicia el equipo para terminar.' -ForegroundColor Yellow }
    } catch { $global:Errors++; Write-Host ('  ERROR: ' + $_.Exception.Message) -ForegroundColor Red; Write-Log ('[ERROR] Instalar drivers: ' + $_.Exception.Message) }
}

# Decodifica la clave instalada (algoritmo conocido de DigitalProductId, Windows 7 a 11)
function Get-InstalledProductKey {
    $id = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).DigitalProductId
    if (-not $id -or $id.Length -lt 67) { return $null }
    $k = New-Object 'int[]' 15
    for ($i = 0; $i -lt 15; $i++) { $k[$i] = [int]$id[52 + $i] }
    $isWin8 = [int]([math]::Floor($k[14] / 6)) -band 1
    $k[14] = ($k[14] -band 0xF7) -bor (($isWin8 -band 2) * 4)
    $chars = 'BCDFGHJKMPQRTVWXY2346789'
    $out = ''; $last = 0
    for ($i = 24; $i -ge 0; $i--) {
        $cur = 0
        for ($j = 14; $j -ge 0; $j--) {
            $cur = $cur * 256 + $k[$j]
            $k[$j] = [int][math]::Floor($cur / 24)
            $cur = $cur % 24
        }
        $out = [string]$chars[$cur] + $out
        $last = $cur
    }
    if ($isWin8 -eq 1) {
        $rest = $out.Substring(1)
        $out = $rest.Substring(0, $last) + 'N' + $rest.Substring($last)
    }
    return ($out.Substring(0, 5) + '-' + $out.Substring(5, 5) + '-' + $out.Substring(10, 5) + '-' + $out.Substring(15, 5) + '-' + $out.Substring(20, 5))
}

function T-ProductKey {
    Write-Section 'Clave de producto de Windows'
    Write-Host '  NO compartas esta pantalla: muestra la clave completa.' -ForegroundColor Yellow
    Write-Host ''
    $svc = @(Get-CimInstance SoftwareLicensingService -ErrorAction SilentlyContinue)
    $oem = ''; if ($svc.Count -gt 0) { $oem = [string]$svc[0].OA3xOriginalProductKey }
    if ($oem) {
        Write-Host ('  Clave de fabrica guardada en la BIOS:  ' + $oem) -ForegroundColor Green
        Write-Host '    Windows la usa sola si reinstalas la misma edicion en este equipo.' -ForegroundColor DarkGray
    } else {
        Write-Host '  No hay clave guardada en la BIOS (normal en Windows 7 y en equipos armados).' -ForegroundColor Gray
        Write-Host '    Busca la etiqueta de licencia (COA) pegada al equipo o al cargador.' -ForegroundColor DarkGray
    }
    $lic = @(Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" -ErrorAction SilentlyContinue)
    $inst = Get-InstalledProductKey
    if ($inst) {
        $match = $false
        foreach ($l in $lic) { if ($l.PartialProductKey -and $inst.EndsWith([string]$l.PartialProductKey)) { $match = $true } }
        Write-Host ''
        Write-Host ('  Clave instalada en Windows:            ' + $inst) -ForegroundColor Green
        if ($match) { Write-Host '    Verificada: coincide con la licencia activa.' -ForegroundColor DarkGray }
        Write-Host '    Si Windows se activo con licencia digital, puede ser una clave generica que no sirve en otro equipo.' -ForegroundColor DarkGray
    }
    $map = @{ 0 = 'Sin licencia'; 1 = 'ACTIVADO'; 2 = 'Periodo de gracia'; 3 = 'Gracia adicional'; 4 = 'Gracia (no original)'; 5 = 'NO ACTIVADO'; 6 = 'Gracia extendida' }
    foreach ($l in $lic) {
        Write-Host ''
        Write-Host ('  ' + $l.Name)
        Write-Host ('    Tipo: ' + $l.Description + '   Estado: ' + $map[[int]$l.LicenseStatus]) -ForegroundColor DarkGray
    }
    Write-Log 'Clave de producto consultada (la clave no se guarda en el log)'
}

function Get-InstalledPrograms {
    $seen = @{}; $list = @()
    foreach ($p in @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                                      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                                      'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue)) {
        $n = [string]$p.DisplayName
        if (-not $n -or $p.SystemComponent -eq 1 -or $p.ParentKeyName -or $n -match '^(Security Update|Update for|Hotfix)') { continue }
        if ($seen.ContainsKey($n)) { continue }
        $seen[$n] = $true
        $size = ''; if ($p.EstimatedSize) { $size = Format-Size ([double]$p.EstimatedSize * 1KB) }
        $date = ''; if ([string]$p.InstallDate -match '^\d{8}$') { $d = [string]$p.InstallDate; $date = $d.Substring(6, 2) + '/' + $d.Substring(4, 2) + '/' + $d.Substring(0, 4) }
        $list += (New-Object PSObject -Property @{ Programa = $n; Version = [string]$p.DisplayVersion; Fabricante = [string]$p.Publisher; Instalado = $date; Tamano = $size })
    }
    return @($list | Sort-Object Programa)
}

function T-ProgramsList {
    Write-Section 'Lista de programas instalados'
    $list = @(Get-InstalledPrograms)
    $file = Join-Path $global:LogDir ('Programas_' + $env:COMPUTERNAME + '_' + (Get-Date -Format 'yyyy-MM-dd_HH-mm') + '.txt')
    $head = @('PROGRAMAS INSTALADOS - ' + $env:COMPUTERNAME + ' - ' + (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - MG Toolkit', ('Total: ' + $list.Count), '')
    $table = $list | Select-Object Programa, Version, Fabricante, Instalado, Tamano | Format-Table -AutoSize | Out-String -Width 250
    $head + $table | Out-File -FilePath $file -Encoding UTF8 -Width 250
    Write-Host ('  ' + $list.Count + ' programas instalados.') -ForegroundColor Green
    Write-Host ('  Lista guardada en: ' + $file)
    Write-Log ('Lista de programas: ' + $list.Count + ' en ' + $file)
    Start-Process notepad.exe -ArgumentList ('"' + $file + '"')
    if (Confirm-Action 'Abrir "Programas y caracteristicas" para desinstalar alguno?') { Start-Process appwiz.cpl }
}

function Get-SafeBootState {
    $o = bcdedit /enum '{current}' 2>$null | Out-String
    if ($o -match 'safeboot\s+(\w+)') { return $matches[1] }
    return ''
}

function Restart-Soon([string]$extra = '') {
    if ($global:DryRun) { Write-Host '  [SIM] Reiniciar el equipo' -ForegroundColor DarkYellow; return }
    if ($extra) { shutdown /r /t 10 $extra /c "MG Toolkit: el equipo se reinicia en 10 segundos" }
    else { shutdown /r /t 10 /c "MG Toolkit: el equipo se reinicia en 10 segundos" }
    Write-Host '  El equipo se reinicia en 10 segundos. Para cancelar escribe: shutdown /a' -ForegroundColor Yellow
}

function T-Reboot {
    Write-Section 'Reiniciar en modo especial'
    $sb = Get-SafeBootState
    if ($sb) { Write-Host ('  ATENCION: el equipo esta configurado para iniciar SIEMPRE en modo seguro (' + $sb + ').') -ForegroundColor Yellow }
    Write-Host '   1. Modo seguro             (solo lo basico; para quitar virus o drivers que fallan)'
    Write-Host '   2. Modo seguro con red     (igual, pero con internet)'
    Write-Host '   3. Volver al inicio NORMAL (quita el modo seguro)'
    Write-Host '   4. Entrar a la BIOS / UEFI'
    Write-Host '   5. Opciones avanzadas de inicio (reparar, restaurar, USB)'
    Write-Host '   0. Volver'
    switch ((Read-Host '  Opcion').Trim()) {
        '1' { Set-SafeBoot 'minimal' }
        '2' { Set-SafeBoot 'network' }
        '3' {
            if (-not $sb) { Write-Host '  Ya inicia en modo normal.' -ForegroundColor Green; return }
            Step 'Volver al inicio normal' { bcdedit /deletevalue '{current}' safeboot }
            if (Confirm-Action 'Reiniciar ahora?' $false $true) { Restart-Soon }
        }
        '4' {
            if (-not $global:IsWin8) { Write-Host '  En Windows 7: reinicia y presiona F2, Supr, F10, F12 o Esc al encender (depende de la marca).' -ForegroundColor Yellow; return }
            if (Confirm-Action 'Reiniciar ahora y entrar a la BIOS? (guarda todo antes)' $false $true) {
                Step 'Reiniciar a la BIOS / UEFI' { shutdown /r /fw /t 10 }
                if ($LASTEXITCODE -ne 0) { Write-Host '  Este equipo no lo permite (BIOS antigua): presiona F2, Supr, F10 o Esc al encender.' -ForegroundColor Yellow }
            }
        }
        '5' {
            if (-not $global:IsWin8) { Write-Host '  En Windows 7: reinicia y presiona F8 repetidamente antes de que aparezca el logo de Windows.' -ForegroundColor Yellow; return }
            if (Confirm-Action 'Reiniciar ahora en opciones avanzadas? (guarda todo antes)' $false $true) { Restart-Soon '/o' }
        }
    }
}

function Set-SafeBoot([string]$mode) {
    Write-Host '  El equipo iniciara en modo seguro CADA VEZ hasta que vuelvas a normal:' -ForegroundColor Yellow
    Write-Host '  abre MG Toolkit en modo seguro, opcion 52 y luego 3 (o ejecuta msconfig > Arranque).' -ForegroundColor Yellow
    if (Confirm-Action 'Configurar el modo seguro y reiniciar ahora? (guarda todo antes)' $false $true) {
        Step ('Activar modo seguro (' + $mode + ')') { bcdedit /set '{current}' safeboot $mode }
        Restart-Soon
    }
}

$global:WinTools = @(
    @('Administrador de dispositivos (drivers)', 'devmgmt.msc', ''),
    @('Administrador de tareas', 'taskmgr.exe', ''),
    @('Monitor de recursos (que usa CPU, disco y red)', 'resmon.exe', ''),
    @('Visor de eventos (errores del sistema)', 'eventvwr.msc', ''),
    @('Historial de confiabilidad (fallos por fecha)', 'perfmon.exe', '/rel'),
    @('Servicios', 'services.msc', ''),
    @('Administracion de discos (particiones)', 'diskmgmt.msc', ''),
    @('Programas y caracteristicas (desinstalar)', 'appwiz.cpl', ''),
    @('Conexiones de red', 'ncpa.cpl', ''),
    @('Opciones de energia', 'powercfg.cpl', ''),
    @('Propiedades del sistema (nombre, rendimiento)', 'sysdm.cpl', ''),
    @('Configuracion del sistema (msconfig)', 'msconfig.exe', ''),
    @('Informacion del sistema (msinfo32)', 'msinfo32.exe', ''),
    @('Restaurar sistema', 'rstrui.exe', ''),
    @('Liberador de espacio en disco', 'cleanmgr.exe', ''),
    @('Editor del registro', 'regedit.exe', ''),
    @('Programador de tareas', 'taskschd.msc', ''),
    @('Firewall con seguridad avanzada', 'wf.msc', ''),
    @('Usuarios y grupos locales (no en ediciones Home)', 'lusrmgr.msc', ''),
    @('Directivas de grupo (no en ediciones Home)', 'gpedit.msc', ''),
    @('Panel de control', 'control.exe', ''),
    @('Simbolo del sistema (administrador)', 'cmd.exe', '')
)

function T-WinTools {
    while ($true) {
        Show-Header
        Write-Group 'HERRAMIENTAS DE WINDOWS (se abren en otra ventana)'
        Write-Host ''
        for ($i = 0; $i -lt $global:WinTools.Count; $i++) { Write-Opt ([string]($i + 1)) $global:WinTools[$i][0] }
        Write-Host ''
        Write-Opt '0' 'Volver al menu principal'
        Write-Host ''
        $s = Read-Host '   Escribe el numero y presiona ENTER'
        $n = 0
        if (-not [int]::TryParse($s, [ref]$n) -or $n -lt 1 -or $n -gt $global:WinTools.Count) { return }
        $t = $global:WinTools[$n - 1]
        try {
            if ($t[2]) { Start-Process -FilePath $t[1] -ArgumentList $t[2] -ErrorAction Stop } else { Start-Process -FilePath $t[1] -ErrorAction Stop }
            Write-Log ('Abierto: ' + $t[0])
        } catch { Write-Host '   No esta disponible en esta edicion de Windows.' -ForegroundColor Yellow; Start-Sleep -Seconds 2 }
    }
}

function Invoke-Task([string]$name, [scriptblock]$body, [switch]$Simple) {
    $global:Freed = [int64]0; $global:Errors = 0; $global:Warnings = 0; $global:YesAll = $false
    Clear-Host
    Write-Host ''
    Write-Host ('  ===== ' + $name.ToUpper() + ' =====') -ForegroundColor Green
    if ($global:DryRun) { Write-Host '  (MODO SIMULACION: no se cambia nada)' -ForegroundColor Black -BackgroundColor Yellow }
    Write-Log ('##### INICIO: ' + $name + ' #####')
    if ($Simple) {
        & $body
        Write-Log ('##### FIN: ' + $name + ' #####')
        Wait-Enter
        return
    }
    $drive = $env:SystemDrive.TrimEnd(':')
    $free0 = Get-FreeBytes
    $t0 = Get-Date
    & $body
    $free1 = Get-FreeBytes
    $dur = (Get-Date) - $t0
    Write-Host ''
    Write-Host '  ------------------------- RESUMEN -------------------------' -ForegroundColor Cyan
    if ($global:DryRun) {
        Write-Host '  MODO SIMULACION: no se aplico ningun cambio.' -ForegroundColor Yellow
        if ($global:Freed -gt 0) { Write-Host ('  Espacio que se liberaria: ' + (Format-Size $global:Freed)) }
    } else {
        if ($global:Freed -gt 0) { Write-Host ('  Espacio liberado: ' + (Format-Size $global:Freed) + '   (libre en ' + $env:SystemDrive + ': ' + (Format-Size $free0) + ' -> ' + (Format-Size $free1) + ')') }
    }
    $estado = 'Todo salio bien.'
    if ($global:Errors -gt 0 -or $global:Warnings -gt 0) { $estado = ('Errores: ' + $global:Errors + '   Avisos: ' + $global:Warnings + '   (detalles en el log)') }
    $col = 'Green'; if ($global:Errors -gt 0) { $col = 'Red' } elseif ($global:Warnings -gt 0) { $col = 'Yellow' }
    Write-Host ('  ' + $estado + '   Duracion: ' + $dur.ToString('mm\:ss')) -ForegroundColor $col
    Write-Log ('##### FIN: {0} | liberado {1} | errores {2} | avisos {3} | duracion {4} #####' -f $name, (Format-Size $global:Freed), $global:Errors, $global:Warnings, $dur.ToString('mm\:ss'))
    Wait-Enter
}

function Show-Header {
    Clear-Host
    $ram = Get-RamStatus
    $c = New-Object PSObject -Property @{ Free = (Get-FreeBytes) }
    Write-Host '  ==================================================================' -NoNewline -ForegroundColor Cyan
    Write-Host '  Matthew Garay' -ForegroundColor White
    Write-Host '        MG Toolkit  -  Herramientas de Limpieza y Optimizacion de Windows' -ForegroundColor Cyan
    Write-Host ('                       v' + $global:AppVer + '   |   Creado por Matthew Garay') -ForegroundColor DarkCyan
    Write-Host '  ==================================================================' -ForegroundColor Cyan
    Write-Host ('   Equipo: ' + $env:COMPUTERNAME + '   |   RAM libre: ' + $ram.Libre + ' de ' + $ram.Total + ' GB   |   Libre en ' + $env:SystemDrive + ' ' + (Format-Size $c.Free)) -ForegroundColor Gray
    if ($global:DryRun) { Write-Host '   MODO SIMULACION ACTIVADO: solo muestra lo que haria, no cambia nada ' -ForegroundColor Black -BackgroundColor Yellow }
    if (Get-SafeBootState) { Write-Host '   ATENCION: el equipo arranca siempre en MODO SEGURO. Para volver a normal: opcion 52 y luego 3 ' -ForegroundColor Black -BackgroundColor Yellow }
}

function Write-Group([string]$t) { Write-Host ''; Write-Host ('   ' + $t) -ForegroundColor Cyan }

function Write-Opt([string]$num, [string]$text, [string]$hint = '') {
    Write-Host ('   {0,3}  ' -f $num) -NoNewline -ForegroundColor Yellow
    Write-Host $text -NoNewline
    if ($hint) { Write-Host ('   ' + $hint) -ForegroundColor DarkGray } else { Write-Host '' }
}

function Show-ModuleMenu([string]$title, [array]$items) {
    while ($true) {
        Show-Header
        Write-Group $title
        Write-Host ''
        for ($i = 0; $i -lt $items.Count; $i++) { Write-Opt ([string]($i + 1)) $items[$i].N }
        Write-Host ''
        Write-Opt 'T' 'Hacer todas las de esta lista'
        Write-Opt '0' 'Volver'
        Write-Host ''
        $sel = Read-Host '   Escribe el numero (o varios separados por coma, ej: 1,3,5) y ENTER'
        if ($sel -eq '0' -or -not $sel) { return }
        $idx = @()
        if ($sel -match '^\s*[tT]\s*$') { $idx = 0..($items.Count - 1) }
        else {
            foreach ($s in ($sel -split '[,\s]+')) {
                $n = 0
                if ([int]::TryParse($s, [ref]$n) -and $n -ge 1 -and $n -le $items.Count) { $idx += ($n - 1) }
            }
        }
        if ($idx.Count -eq 0) { continue }
        Invoke-Task $title { foreach ($k in $idx) { & $items[$k].A } }
    }
}

$menuM1 = @(
    @{ N = 'Temporales de Windows (C:\Windows\Temp)';                     A = { M1-WinTemp } },
    @{ N = 'Temporales de usuarios (AppData\Local\Temp)';                 A = { M1-UserTemp } },
    @{ N = 'Vaciar papelera de reciclaje (todas las unidades)';           A = { M1-Recycle } },
    @{ N = 'Cache de Prefetch';                                           A = { M1-Prefetch } },
    @{ N = 'Cache de apps de la Tienda';                                  A = { M1-Store } },
    @{ N = 'Cache de Windows Update';                                     A = { M1-WUCache } },
    @{ N = 'Volcados de memoria y reportes de error';                     A = { M1-Dumps } },
    @{ N = 'Vaciar registros de eventos';                                 A = { M1-EventLogs } },
    @{ N = 'Restos de instaladores (MSOCache, Adobe)';                    A = { M1-Installers } },
    @{ N = 'Cache de navegadores';                                        A = { M1-Browsers } },
    @{ N = 'Cache de miniaturas e iconos';                                A = { M1-Thumbs } },
    @{ N = 'Limpiar cache DNS';                                           A = { M1-DNS } }
)
$menuM2 = @(
    @{ N = 'Liberar memoria en espera (Standby)';                         A = { M2-Standby } },
    @{ N = 'Archivo de paginacion (revisar / poner automatico)';          A = { M2-Pagefile } },
    @{ N = 'Cerrar procesos innecesarios en segundo plano';               A = { M2-KillBloat } },
    @{ N = 'Dar prioridad alta a un programa';                            A = { M2-Priority } },
    @{ N = 'Hibernacion: desactivar / reducir / activar';                 A = { M2-Hibernate } },
    @{ N = 'Temporizador del sistema (HPET)';                             A = { M2-Timer } },
    @{ N = 'Limpiar portapapeles e historial';                            A = { M2-Clipboard } },
    @{ N = 'Vaciar memoria de trabajo de los procesos';                   A = { M2-WorkingSets } },
    @{ N = 'Reiniciar el Explorador de Windows';                          A = { M2-Explorer } },
    @{ N = 'Ver que programas consumen mas RAM';                          A = { M2-Leak } }
)
$menuM3 = @(
    @{ N = 'DISM: reparar imagen de Windows';                             A = { M3-DISM } },
    @{ N = 'SFC: reparar archivos del sistema';                           A = { M3-SFC } },
    @{ N = 'Limpiar componentes antiguos de Windows';                     A = { M3-Components } },
    @{ N = 'CHKDSK: errores del disco';                                   A = { M3-Chkdsk } },
    @{ N = 'Optimizar discos (TRIM / desfragmentar)';                     A = { M3-Defrag } },
    @{ N = 'Reparar internet / red';                                      A = { M3-Network } },
    @{ N = 'Restablecer firewall';                                        A = { M3-Firewall } },
    @{ N = 'Ver activacion de Windows';                                   A = { M3-Activation } },
    @{ N = 'Actualizar directivas de grupo (gpupdate)';                   A = { M3-GPUpdate } },
    @{ N = 'Reiniciar servicios trabados';                                A = { M3-Services } }
)
$menuM4 = @(
    @{ N = 'Plan de energia Maximo rendimiento';                          A = { M4-Power } },
    @{ N = 'Quitar efectos visuales pesados';                             A = { M4-Visual } },
    @{ N = 'Programas que arrancan con Windows';                          A = { M4-Startup } },
    @{ N = 'Modo Juego y prioridad de GPU';                               A = { M4-Game } },
    @{ N = 'Desactivar telemetria y anuncios';                            A = { M4-Telemetry } },
    @{ N = 'Desactivar servicios que no se usan';                         A = { M4-Services } }
)

function Show-Advanced {
    while ($true) {
        Show-Header
        Write-Group 'OPCIONES AVANZADAS: cada tarea por separado'
        Write-Host ''
        Write-Opt '1' 'Limpieza'               '(12 tareas)'
        Write-Opt '2' 'Memoria RAM'            '(10 tareas)'
        Write-Opt '3' 'Reparacion'             '(10 tareas)'
        Write-Opt '4' 'Rendimiento y arranque' '(6 tareas)'
        Write-Host ''
        Write-Opt '0' 'Volver al menu principal'
        Write-Host ''
        switch ((Read-Host '   Escribe el numero y presiona ENTER').Trim()) {
            '1' { Show-ModuleMenu 'LIMPIEZA' $menuM1 }
            '2' { Show-ModuleMenu 'MEMORIA RAM' $menuM2 }
            '3' { Show-ModuleMenu 'REPARACION' $menuM3 }
            '4' { Show-ModuleMenu 'RENDIMIENTO Y ARRANQUE' $menuM4 }
            '0' { return }
        }
    }
}

# =====================================================================
#   MODO MANTENIMIENTO (lo usa la tarea programada semanal; no muestra menu)
# =====================================================================
if ($global:Maint) {
    Invoke-Maintenance
    exit 0
}

# Ventana mas grande para que entre todo el menu (sin perder el historial para desplazarse)
try {
    $raw = $Host.UI.RawUI
    $max = $raw.MaxPhysicalWindowSize
    $buf = $raw.BufferSize
    if ($buf.Width -lt 100) { $buf.Width = 100 }
    if ($buf.Height -lt 3000) { $buf.Height = 3000 }
    $raw.BufferSize = $buf
    $win = $raw.WindowSize
    $win.Width  = [math]::Min(100, $max.Width)
    $win.Height = [math]::Min(54, $max.Height)
    $raw.WindowSize = $win
} catch {}

function New-MI([string]$n, [string]$t) { (New-Object PSObject -Property @{ K = 'I'; N = $n; T = $t }) }
function New-MH([string]$t) { (New-Object PSObject -Property @{ K = 'H'; T = $t }) }

function Write-Cell($c, [int]$w) {
    if ($null -eq $c) { Write-Host (''.PadRight($w)) -NoNewline; return }
    if ($c.K -eq 'H') { Write-Host (('   ' + $c.T).PadRight($w)) -NoNewline -ForegroundColor Cyan; return }
    $num = ($c.N.PadLeft(5) + '  ')
    Write-Host $num -NoNewline -ForegroundColor Yellow
    $max = $w - $num.Length
    $txt = $c.T; if ($txt.Length -gt ($max - 1)) { $txt = $txt.Substring(0, $max - 1) }
    Write-Host ($txt.PadRight($max)) -NoNewline
}

function Open-Manual {
    $dir = Split-Path -Path $env:OPT_SELF -Parent
    $man = Join-Path $dir 'MANUAL.md'
    if (Test-Path -LiteralPath $man) {
        # Si no hay programa asociado a .md, se abre con el Bloc de notas
        try { Start-Process -FilePath $man -ErrorAction Stop }
        catch {
            $txt = Join-Path $env:TEMP 'Manual MG Toolkit.txt'
            [IO.File]::WriteAllText($txt, ([IO.File]::ReadAllText($man) -replace "`r?`n", "`r`n"), (New-Object Text.UTF8Encoding($true)))
            Start-Process notepad.exe -ArgumentList ('"' + $txt + '"')
        }
    }
    else { Write-Host ('   No se encontro "MANUAL.md" junto a este programa (' + $dir + ').') -ForegroundColor Yellow; Start-Sleep -Seconds 3 }
}

# =====================================================================
#   MENU PRINCIPAL
# =====================================================================
while ($true) {
    Show-Header
    $sim = 'APAGADO'; if ($global:DryRun) { $sim = 'ENCENDIDO' }
    $L = @(
        (New-MH 'HACER TODO (con informe al final)'),
        (New-MI '1' 'Todo PREGUNTANDO (S/N, T = si a todo)'),
        (New-MI '2' 'Todo AUTOMATICO, sin preguntar'),
        (New-MI '3' 'Solo revisar y ver el informe'),
        $null,
        (New-MH 'LIMPIEZA'),
        (New-MI '4' 'Borrar temporales y basura'),
        (New-MI '5' 'Borrar cache de navegadores'),
        (New-MI '6' 'Vaciar la papelera'),
        (New-MI '7' 'Liberar espacio (hibernacion)'),
        (New-MI '8' 'Buscar archivos grandes'),
        (New-MI '9' 'Quitar apps basura de fabrica'),
        $null,
        (New-MH 'VELOCIDAD'),
        (New-MI '10' 'Poner en maximo rendimiento'),
        (New-MI '11' 'Liberar memoria RAM'),
        (New-MI '12' 'Programas que arrancan con Windows'),
        (New-MI '13' 'Ver que programas consumen mas'),
        (New-MI '14' 'Desactivar servicios sin uso'),
        (New-MI '15' 'Desactivar telemetria y anuncios'),
        (New-MI '16' 'Medir velocidad del disco'),
        (New-MI '17' 'Deshacer cambios de velocidad'),
        $null,
        (New-MH 'ACTUALIZAR E INSTALAR'),
        (New-MI '18' 'Instalar actualizaciones de Windows'),
        (New-MI '19' 'Actualizar todos los programas'),
        (New-MI '20' 'Instalar programas basicos'),
        (New-MI '49' 'Actualizar drivers (Windows Update)'),
        $null,
        (New-MH 'RED E INTERNET'),
        (New-MI '43' 'Probar internet (velocidad y fallas)'),
        (New-MI '44' 'Cambiar DNS (paginas mas rapidas)'),
        (New-MI '45' 'Programas conectados a internet'),
        (New-MI '46' 'Revisar archivo hosts (virus)'),
        (New-MI '47' 'Quitar proxy (publicidad)'),
        (New-MI '48' 'Sincronizar la hora')
    )
    $R = @(
        (New-MH 'SEGURIDAD Y RESPALDO'),
        (New-MI '21' 'Buscar virus (Defender)'),
        (New-MI '22' 'Crear punto de restauracion'),
        (New-MI '23' 'Respaldar archivos del usuario'),
        (New-MI '24' 'Respaldar / restaurar drivers'),
        $null,
        (New-MH 'REPARACION'),
        (New-MI '25' 'Reparar archivos de Windows'),
        (New-MI '26' 'Revisar errores del disco'),
        (New-MI '27' 'Optimizar el disco'),
        (New-MI '28' 'Reparar internet / red'),
        (New-MI '29' 'Reparar Windows Update'),
        (New-MI '30' 'Destrabar la impresora'),
        (New-MI '31' 'Reiniciar servicios trabados'),
        (New-MI '32' 'Restablecer el firewall'),
        (New-MI '33' 'Probar la memoria RAM'),
        $null,
        (New-MH 'INFORMACION'),
        (New-MI '34' 'Informacion del equipo'),
        (New-MI '35' 'Reporte de bateria'),
        (New-MI '36' 'Ver si Windows esta activado'),
        (New-MI '37' 'Contrasenas y reporte de WiFi'),
        (New-MI '50' 'Clave de producto de Windows'),
        (New-MI '51' 'Lista de programas instalados'),
        $null,
        (New-MH 'OTROS'),
        (New-MI '38' 'Mantenimiento automatico semanal'),
        (New-MI '39' ('Modo simulacion: ' + $sim)),
        (New-MI '40' 'Abrir carpeta de informes'),
        (New-MI '41' 'Opciones avanzadas'),
        (New-MI '42' 'Ver el manual'),
        (New-MI '52' 'Reiniciar en modo seguro / BIOS'),
        (New-MI '53' 'Herramientas de Windows (atajos)'),
        (New-MI '0' 'Salir')
    )
    Write-Host ''
    $wide = $true
    try { if ($Host.UI.RawUI.WindowSize.Width -lt 100) { $wide = $false } } catch {}
    if ($wide) {
        $rows = [math]::Max($L.Count, $R.Count)
        for ($i = 0; $i -lt $rows; $i++) {
            $lc = $null; if ($i -lt $L.Count) { $lc = $L[$i] }
            $rc = $null; if ($i -lt $R.Count) { $rc = $R[$i] }
            Write-Cell $lc 50; Write-Cell $rc 49; Write-Host ''
        }
    } else {
        foreach ($c in ($L + @($null) + $R)) { Write-Cell $c 60; Write-Host '' }
    }
    Write-Host ''
    $op = (Read-Host '   Escribe el numero y presiona ENTER').Trim()
    switch ($op) {
        '1'  { Invoke-Task 'Hacer todo preguntando' { Preset-Guided } }
        '2'  { Invoke-Task 'Hacer todo automatico' { Preset-Auto } }
        '3'  { Invoke-Task 'Revisar el equipo e informe' { Report-Only } -Simple }
        '4'  { Invoke-Task 'Borrar archivos temporales y basura' { M1-UserTemp; M1-WinTemp; M1-WUCache; M1-Dumps; M1-Store; M1-Thumbs; M1-DNS; M3-Components } }
        '5'  { Invoke-Task 'Borrar cache de navegadores' { M1-Browsers } }
        '6'  { Invoke-Task 'Vaciar papelera' { M1-Recycle } }
        '7'  { Invoke-Task 'Liberar espacio (hibernacion)' { M2-Hibernate } }
        '8'  { Invoke-Task 'Buscar archivos grandes' { T-BigFiles } -Simple }
        '9'  { Invoke-Task 'Quitar apps basura de fabrica' { T-Bloat } }
        '10' { Invoke-Task 'Maximo rendimiento' { M4-Power; M4-Visual; M4-Game } }
        '11' { Invoke-Task 'Liberar memoria RAM' { M2-KillBloat; M2-Clipboard; M2-WorkingSets; M2-Standby } }
        '12' { Invoke-Task 'Programas que arrancan con Windows' { M4-Startup } -Simple }
        '13' { Invoke-Task 'Programas que consumen mas' { M2-Leak; M2-Priority } -Simple }
        '14' { Invoke-Task 'Servicios que no se usan' { M4-Services } -Simple }
        '15' { Invoke-Task 'Desactivar telemetria y anuncios' { M4-Telemetry } }
        '16' { Invoke-Task 'Medir velocidad del disco' { T-DiskSpeed } -Simple }
        '17' { Invoke-Task 'Deshacer cambios de velocidad' { X-Revert } }
        '18' { Invoke-Task 'Actualizaciones de Windows' { X-WindowsUpdate } }
        '19' { Invoke-Task 'Actualizar programas' { X-Winget } }
        '20' { Invoke-Task 'Instalar programas basicos' { T-BasicApps } }
        '21' { Invoke-Task 'Buscar virus' { T-Defender } }
        '22' { Invoke-Task 'Punto de restauracion' { X-Restore } }
        '23' { Invoke-Task 'Respaldar archivos del usuario' { T-BackupFiles } }
        '24' { Invoke-Task 'Respaldar / restaurar drivers' { T-Drivers } }
        '25' { Invoke-Task 'Reparar archivos de Windows' { M3-DISM; M3-SFC } }
        '26' { Invoke-Task 'Revisar errores del disco' { M3-Chkdsk } }
        '27' { Invoke-Task 'Optimizar el disco' { M3-Defrag } }
        '28' { Invoke-Task 'Reparar internet / red' { M3-Network } }
        '29' { Invoke-Task 'Reparar Windows Update' { T-WUReset } }
        '30' { Invoke-Task 'Destrabar la impresora' { T-Printer } }
        '31' { Invoke-Task 'Reiniciar servicios trabados' { M3-Services } }
        '32' { Invoke-Task 'Restablecer firewall' { M3-Firewall } }
        '33' { Invoke-Task 'Probar la memoria RAM' { X-RamDiag } -Simple }
        '34' { Invoke-Task 'Informacion del equipo' { X-Info } -Simple }
        '35' { Invoke-Task 'Reporte de bateria' { X-Battery } -Simple }
        '36' { Invoke-Task 'Activacion de Windows' { M3-Activation } -Simple }
        '37' { Invoke-Task 'Redes WiFi' { T-Wifi } -Simple }
        '38' { Invoke-Task 'Mantenimiento automatico semanal' { T-Schedule } -Simple }
        '39' { $global:DryRun = -not $global:DryRun; Write-Log ('Modo simulacion: ' + $global:DryRun) }
        '40' { Start-Process explorer.exe $global:LogDir }
        '41' { Show-Advanced }
        '42' { Open-Manual }
        '43' { Invoke-Task 'Probar internet' { T-SpeedTest } -Simple }
        '44' { Invoke-Task 'Cambiar DNS' { T-DNS } }
        '45' { Invoke-Task 'Programas conectados a internet' { T-Connections } -Simple }
        '46' { Invoke-Task 'Revisar archivo hosts' { T-Hosts } }
        '47' { Invoke-Task 'Revisar proxy' { T-Proxy } }
        '48' { Invoke-Task 'Sincronizar la hora' { T-Time } }
        '49' { Invoke-Task 'Actualizar drivers' { T-DriverUpdates } }
        '50' { Invoke-Task 'Clave de producto' { T-ProductKey } -Simple }
        '51' { Invoke-Task 'Programas instalados' { T-ProgramsList } -Simple }
        '52' { Invoke-Task 'Reiniciar en modo especial' { T-Reboot } -Simple }
        '53' { T-WinTools }
        '0'  { Write-Log 'Programa cerrado por el usuario'; exit 0 }
        default {
            if ($op) { Write-Host ('   "' + $op + '" no es una opcion valida. Escribe solo el numero, por ejemplo: 4') -ForegroundColor Red; Start-Sleep -Seconds 2 }
        }
    }
}

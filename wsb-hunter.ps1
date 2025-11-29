param(
    [string[]]$TrustedPaths = @("C:\TrustedWSB"),
    [string]$QuarantineDir = "C:\WSB_Quarantine",
    [string]$LogFile = "C:\WSB_Quarantine\wsb-hunter.log"
)

# --- Setup -----------------------------------------------------
if (-not (Test-Path $QuarantineDir)) {
    New-Item -ItemType Directory -Path $QuarantineDir | Out-Null
}

$logDir = Split-Path $LogFile
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

function Write-Log {
    param([string]$msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] $msg"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

function Is-TrustedPath {
    param([string]$path)
    foreach ($p in $TrustedPaths) {
        if ($path -like "$p*") { return $true }
    }
    return $false
}

# --- Risk Analysis -----------------------------------------------------
function Analyze-WSB {
    param([string]$path)

    if (-not (Test-Path $path)) { return }

    try {
        [xml]$xml = Get-Content $path -ErrorAction Stop
    }
    catch {
        Write-Log "Unable to parse XML in $path"
        return
    }

    $score = 0
    $details = @()

    # Networking
    if ($xml.Configuration.Networking -eq "Enable") {
        $score += 20
        $details += "Networking enabled (+20)"
    }

    # Mapped folders
    $mapped = $xml.Configuration.MappedFolders.MappedFolder
    if ($mapped) {
        $score += 20
        $details += "Folder mapping present (+20)"

        foreach ($m in $mapped) {
            if ($m.ReadOnly -eq "false") {
                $score += 10
                $details += "Writable mapped folder (+10)"
            }

            if ($m.HostFolder -match "Public|Temp|AppData") {
                $score += 10
                $details += "Mapped to malware staging folder (+10)"
            }
        }
    }

    # LogonCommand
    $cmd = $xml.Configuration.LogonCommand.Command
    if ($cmd) {
        $score += 30
        $details += "Auto-Execution command present (+30)"

        if ($cmd -match "\.bat$|\.exe$|7z\.exe") {
            $score += 40
            $details += "Suspicious executable in LogonCommand (+40)"
        }
    }

    # Memory
    $mem = $xml.Configuration.MemoryInMB
    if ($mem -as [int] -gt 1024) {
        $score += 5
        $details += "Unusually high memory allocation (+5)"
    }

    # --- Output Risk Summary -----------------------------------------
    Write-Host "`n======== WSB RISK ANALYSIS ========" -ForegroundColor Cyan
    Write-Host "File: $path"
    Write-Host "Risk Score: $score"
    Write-Host "Details:"
    foreach ($d in $details) { Write-Host " - $d" }

    # --- Ask User for Decision ---------------------------------------
    Write-Host ""
    $choice = Read-Host "Delete this quarantined file? [y/N]"

    if ($choice -match "^[Yy]") {
        Remove-Item $path -Force
        Write-Log "User deleted quarantined file: $path"
        Write-Host "File deleted."
    }
    else {
        Write-Host "File retained in quarantine."
    }
}

# --- Quarantine + Trigger Risk Analysis -------------------------------
function Quarantine-File {
    param([string]$path)

    if (-not (Test-Path $path)) { return }

    $name = Split-Path $path -Leaf
    $dest = Join-Path $QuarantineDir $name

    # If duplicate, append timestamp
    if (Test-Path $dest) {
        $stamp = Get-Date -Format "yyyyMMddHHmmss"
        $dest = Join-Path $QuarantineDir ("$stamp-$name")
    }

    try {
        Move-Item -Path $path -Destination $dest -Force
        Write-Log "QUARANTINED: $path --> $dest"
        Analyze-WSB $dest   # Run analysis after quarantine
    }
    catch {
        Write-Log "FAILED to quarantine $path : $_"
    }
}

# --- Watch Roots (realistic sandbox staging zones) ---------------------
$WatchRoots = @(
    "$env:USERPROFILE",
    "$env:PUBLIC",
    "$env:TEMP"
)

Write-Log "===== INITIAL SCAN STARTED ====="

foreach ($root in $WatchRoots) {
    if (-not (Test-Path $root)) { continue }

    $files = Get-ChildItem -Path $root -Filter *.wsb -Recurse -Depth 5 -Force -ErrorAction Ignore

    foreach ($f in $files) {
        if (-not (Is-TrustedPath $f.FullName)) {
            Quarantine-File $f.FullName
        } else {
            Write-Log "IGNORED (trusted): $($f.FullName)"
        }
    }
}

Write-Log "===== INITIAL SCAN DONE ====="
Write-Log "Real-time monitoring active (WSB only)."

# --- Real-time detection loop -----------------------------------------
$Seen = @{}

while ($true) {
    foreach ($root in $WatchRoots) {
        if (-not (Test-Path $root)) { continue }

        $items = Get-ChildItem -Path $root -Filter *.wsb -Force -Recurse -Depth 3 -ErrorAction Ignore

        foreach ($i in $items) {
            $p = $i.FullName

            if (-not $Seen[$p]) {
                $Seen[$p] = $true

                if (Is-TrustedPath $p) {
                    Write-Log "IGNORED (trusted folder): $p"
                    continue
                }

                Write-Log "DETECTED NEW WSB FILE: $p"
                Quarantine-File $p
            }
        }
    }

    Start-Sleep -Seconds 1
}

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

# --- Risk Analysis (Silent Return) ------------------------------------
function Analyze-WSB {
    param([string]$path)

    if (-not (Test-Path $path)) {
        return $null
    }

    try {
        [xml]$xml = Get-Content $path -ErrorAction Stop
    }
    catch {
        return @{
            Score = 0
            Details = @("Unable to parse XML")
        }
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
                $details += "Mapped to common malware staging folder (+10)"
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

    return @{
        Score = $score
        Details = $details
    }
}

# --- Quarantine Function -----------------------------------------
function Quarantine-File {
    param([string]$path)

    if (-not (Test-Path $path)) { return }

    $name = Split-Path $path -Leaf
    $dest = Join-Path $QuarantineDir $name

    # Prevent overwrite
    if (Test-Path $dest) {
        $stamp = Get-Date -Format "yyyyMMddHHmmss"
        $dest = Join-Path $QuarantineDir ("$stamp-$name")
    }

    try {
        Move-Item -Path $path -Destination $dest -Force
        Write-Log "QUARANTINED: $path --> $dest"
    }
    catch {
        Write-Log "FAILED to quarantine $path : $_"
    }
}

# --- User Decision Menu -------------------------------------------
function Handle-Detection {
    param([string]$path)

    Write-Host "`n======== WSB FILE DETECTED ========" -ForegroundColor Yellow
    Write-Host "Path: $path`n"

    # Get risk analysis
    $risk = Analyze-WSB $path

    Write-Host "Risk Score: $($risk.Score)"
    Write-Host "Details:"
    foreach ($d in $risk.Details) { Write-Host " - $d" }

    Write-Host ""
    Write-Host "[A] Allow (leave it)"
    Write-Host "[Q] Quarantine it"
    Write-Host "[D] Delete immediately"
    $choice = Read-Host "Selection"

    switch -regex ($choice) {
        "^[Aa]$" {
            Write-Host "File left untouched."
            Write-Log "User allowed file: $path"
        }
        "^[Qq]$" {
            Quarantine-File $path
        }
        "^[Dd]$" {
            try {
                Remove-Item $path -Force
                Write-Log "User deleted file: $path"
                Write-Host "File deleted."
            }
            catch {
                Write-Log "FAILED to delete $path : $_"
            }
        }
        default {
            Write-Host "Invalid choice. No action taken."
            Write-Log "User made invalid choice for: $path"
        }
    }
}

$Seen = @{}

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
        $fullPath = $f.FullName
        $Seen[$fullPath] = $true  # ← Mark as seen to avoid duplicate detection

        if (-not (Is-TrustedPath $fullPath)) {
            Handle-Detection $fullPath
        }
        else {
            Write-Log "IGNORED (trusted): $fullPath"
        }
    }
}

Write-Log "===== INITIAL SCAN DONE ====="
Write-Log "Real-time monitoring active (WSB only)."

# ------------------------------------------------------------------
# Real-time Monitoring Loop
# ------------------------------------------------------------------
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
                Handle-Detection $p
            }
        }
    }

    Start-Sleep -Seconds 1
}
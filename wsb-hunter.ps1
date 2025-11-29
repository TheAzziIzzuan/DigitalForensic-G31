param(
    [string[]]$TrustedPaths = @("C:\TrustedWSB"),
    [string]$QuarantineDir = "C:\WSB_Quarantine",
    [string]$LogFile = "C:\WSB_Quarantine\wsb-hunter.log"
)

# --- Setup
if (-not (Test-Path $QuarantineDir)) { New-Item -ItemType Directory -Path $QuarantineDir | Out-Null }
$logDir = Split-Path $LogFile
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

function Write-Log {
    param([string]$msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$ts] $msg"
    Write-Host "[$ts] $msg"
}

function Is-TrustedPath {
    param([string]$path)
    foreach ($p in $TrustedPaths) {
        if ($path -like "$p*") { return $true }
    }
    return $false
}

function Quarantine-File {
    param([string]$path)

    if (-not (Test-Path $path)) { return }

    $name = Split-Path $path -Leaf
    $dest = Join-Path $QuarantineDir $name

    try {
        Move-Item -Path $path -Destination $dest -Force
        Write-Log "QUARANTINED: $path --> $dest"
    }
    catch {
        Write-Log "FAILED to quarantine $path : $_"
    }
}

# --- Scan paths where .wsb files are likely to appear
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

# --- REAL-TIME LOOP (fast, stable)
$Seen = @{}  # hashset of seen .wsb files

while ($true) {
    foreach ($root in $WatchRoots) {
        if (-not (Test-Path $root)) { continue }

        $items = Get-ChildItem -Path $root -Filter *.wsb -Force -Recurse -Depth 3 -ErrorAction Ignore

        foreach ($i in $items) {
            $p = $i.FullName

            if (-not $Seen[$p]) {
                $Seen[$p] = $true

                # Trusted exemption only
                if (Is-TrustedPath $p) {
                    Write-Log "IGNORED (trusted folder): $p"
                    continue
                }

                Write-Log "DETECTED NEW WSB FILE: $p"
                Quarantine-File $p
            }
        }
    }

    Start-Sleep -Seconds 1   # ← detection speed
}

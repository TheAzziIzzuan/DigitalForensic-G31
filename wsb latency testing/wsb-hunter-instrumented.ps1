param(
    [string[]]$TrustedPaths = @("C:\TrustedWSB"),
    [string]$QuarantineDir = "C:\WSB_Quarantine\quarantine files",
    [string]$LogFile = "C:\WSB_Quarantine\wsb-hunter.log",
    [string]$PerformanceLogFile = "C:\WSB_Quarantine\performance.csv",
    [bool]$EnablePerformanceLogging = $true,
    [ValidateSet("Shallow","Medium","Deep")]
    [string]$ScanScope = "Shallow",
    [int]$ScanDepth = 5,
    [double]$PollingInterval = 1.0
)

# --- Setup -------
if (-not (Test-Path $QuarantineDir)) {
    New-Item -ItemType Directory -Path $QuarantineDir | Out-Null
}

$logDir = Split-Path $LogFile
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Initialize performance CSV header if enabled
if ($EnablePerformanceLogging) {
    $perfLogDir = Split-Path $PerformanceLogFile
    if (-not (Test-Path $perfLogDir)) {
        New-Item -ItemType Directory -Path $perfLogDir | Out-Null
    }
    
    # Always ensure header is present (recreate if file exists but has no header)
    $header = "Timestamp,EventType,FilePath,DetectionLatencyMs,QuarantineLatencyMs,AnalysisLatencyMs,TotalResponseTimeMs,RiskScore,Details"
    
    if (-not (Test-Path $PerformanceLogFile)) {
        Add-Content -Path $PerformanceLogFile -Value $header
    } else {
        # Check if file is empty or missing header
        $firstLine = Get-Content $PerformanceLogFile -First 1
        if ($firstLine -notlike "*Timestamp*") {
            # File exists but no header - add it at the top
            $content = Get-Content $PerformanceLogFile
            $header | Out-File $PerformanceLogFile
            $content | Out-File $PerformanceLogFile -Append
        }
    }
}

function Write-Log {
    param([string]$msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] $msg"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

function Write-PerfLog {
    param(
        [string]$EventType,
        [string]$FilePath,
        [int]$DetectionLatencyMs,
        [int]$QuarantineLatencyMs,
        [int]$AnalysisLatencyMs,
        [int]$TotalResponseTimeMs,
        [int]$RiskScore,
        [string]$Details
    )
    
    if (-not $EnablePerformanceLogging) { return }
    
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $line = "$ts,$EventType,$FilePath,$DetectionLatencyMs,$QuarantineLatencyMs,$AnalysisLatencyMs,$TotalResponseTimeMs,$RiskScore,$Details"
    Add-Content -Path $PerformanceLogFile -Value $line
}

function Is-TrustedPath {
    param([string]$path)
    foreach ($p in $TrustedPaths) {
        if ($path -like "$p*") { return $true }
    }
    return $false
}

# --- Quarantine + Trigger Risk Analysis -------
function Quarantine-File {
    param([string]$path, [System.Diagnostics.Stopwatch]$detectionWatch)

    if (-not (Test-Path $path)) { return }

    $detectionWatch.Stop()
    $detectionLatency = $detectionWatch.ElapsedMilliseconds

    # FIRST: Analyze the file
    $analysisStartTime = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        [xml]$xml = Get-Content $path -ErrorAction Stop
    }
    catch {
        Write-Log "Unable to parse XML in $path"
        $analysisStartTime.Stop()
        Write-Host "[SKIPPED] Invalid XML: $([System.IO.Path]::GetFileName($path))" -ForegroundColor Yellow
        Write-PerfLog -EventType "FileSkipped" -FilePath $path -DetectionLatencyMs $detectionLatency -QuarantineLatencyMs 0 -AnalysisLatencyMs $analysisStartTime.ElapsedMilliseconds -TotalResponseTimeMs ($detectionLatency + $analysisStartTime.ElapsedMilliseconds) -RiskScore 0 -Details "Parse Error"
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

    $analysisStartTime.Stop()
    $analysisLatency = $analysisStartTime.ElapsedMilliseconds

    # SECOND: If score > threshold (e.g., > 0), then quarantine
    if ($score -gt 0) {
        $name = Split-Path $path -Leaf
        $dest = Join-Path $QuarantineDir $name

        # If duplicate, append timestamp
        if (Test-Path $dest) {
            $stamp = Get-Date -Format "yyyyMMddHHmmss"
            $dest = Join-Path $QuarantineDir ("$stamp-$name")
        }

        $quarantineStartTime = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            Move-Item -Path $path -Destination $dest -Force
            $quarantineStartTime.Stop()
            $quarantineLatency = $quarantineStartTime.ElapsedMilliseconds

            Write-Host "[THREAT] Suspicious $([System.IO.Path]::GetFileName($path)) moved to quarantine (Risk: $score)" -ForegroundColor Red
            Write-Log "THREAT DETECTED: $path - Risk Score: $score - Details: $($details -join '; ')"

            $totalResponseTime = $detectionLatency + $quarantineLatency + $analysisLatency
            Write-PerfLog -EventType "FileQuarantined" -FilePath $path -DetectionLatencyMs $detectionLatency -QuarantineLatencyMs $quarantineLatency -AnalysisLatencyMs $analysisLatency -TotalResponseTimeMs $totalResponseTime -RiskScore $score -Details ($details -join "; ")
        }
        catch {
            $quarantineStartTime.Stop()
            Write-Log "FAILED to quarantine $path : $_"
            Write-PerfLog -EventType "FileQuarantineFailed" -FilePath $path -DetectionLatencyMs $detectionLatency -QuarantineLatencyMs $quarantineStartTime.ElapsedMilliseconds -AnalysisLatencyMs $analysisLatency -TotalResponseTimeMs ($detectionLatency + $quarantineStartTime.ElapsedMilliseconds + $analysisLatency) -RiskScore $score -Details "Quarantine failed"
        }
    } else {
        # Risk score is 0 - file is safe, don't quarantine
        Write-Host "[SAFE] $([System.IO.Path]::GetFileName($path)) is safe (Risk: 0)" -ForegroundColor Green
        Write-Log "SAFE FILE: $path - Risk Score: 0"
        Write-PerfLog -EventType "FileSafe" -FilePath $path -DetectionLatencyMs $detectionLatency -QuarantineLatencyMs 0 -AnalysisLatencyMs $analysisLatency -TotalResponseTimeMs ($detectionLatency + $analysisLatency) -RiskScore 0 -Details "No threats detected"
    }
}

# --- Configure Watch Roots -------
$WatchRoots = @()

switch ($ScanScope) {
    "Shallow" {
        $WatchRoots = @(
            "$env:USERPROFILE\Downloads",
            "$env:USERPROFILE\Desktop",
            "$env:TEMP"
        )
        Write-Log "Scan Scope: SHALLOW (obvious attack locations, depth: $ScanDepth)"
    }
    "Medium" {
        $WatchRoots = @(
            "$env:USERPROFILE\AppData\Local\Temp",
            "$env:USERPROFILE\Documents\Work",
            "$env:USERPROFILE\Downloads\Archive"
        )
        Write-Log "Scan Scope: MEDIUM (user-hidden locations, depth: $ScanDepth)"
    }
    "Deep" {
        $WatchRoots = @(
            "C:\ProgramData\Microsoft\Windows\Caches\Temp\Work",
            "C:\Windows\Temp\System\Cache\Data",
            "$env:USERPROFILE\AppData\Local\Microsoft\Edge\Cache\Storage"
        )
        Write-Log "Scan Scope: DEEP (system-level hiding, depth: $ScanDepth)"
    }
}

Write-Log "===== INITIAL SCAN STARTED ====="
Write-Log "Configuration: Scope=$ScanScope, Depth=$ScanDepth, PollingInterval=${PollingInterval}s"

# Expand paths to show actual values
Write-Log "Watch roots:"
foreach ($root in $WatchRoots) {
    Write-Log "  - $root"
}

foreach ($root in $WatchRoots) {
    if (-not (Test-Path $root)) { 
        Write-Log "WARNING: Root path not found: $root - Creating it..."
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        continue 
    }

    $scanStartTime = [System.Diagnostics.Stopwatch]::StartNew()
    $files = Get-ChildItem -Path $root -Filter *.wsb -Recurse -Depth $ScanDepth -Force -ErrorAction Ignore

    Write-Log "Found $($files.Count) .wsb files in $root"

    foreach ($f in $files) {
        if (-not (Is-TrustedPath $f.FullName)) {
            $fileDetectWatch = [System.Diagnostics.Stopwatch]::StartNew()
            Quarantine-File $f.FullName $fileDetectWatch
        } else {
            Write-Log "IGNORED (trusted): $($f.FullName)"
        }
    }
    
    $scanStartTime.Stop()
    Write-Log "Scan completed for $root in $($scanStartTime.ElapsedMilliseconds)ms"
}

Write-Log "===== INITIAL SCAN DONE ====="
Write-Log "Real-time monitoring active (WSB only) - Polling interval: ${PollingInterval}s"

# --- Real-time detection loop -------
$Seen = @{}

while ($true) {
    foreach ($root in $WatchRoots) {
        if (-not (Test-Path $root)) { continue }

        $items = Get-ChildItem -Path $root -Filter *.wsb -Force -Recurse -Depth $ScanDepth -ErrorAction Ignore

        foreach ($i in $items) {
            $p = $i.FullName

            if (-not $Seen[$p]) {
                $Seen[$p] = $true

                if (Is-TrustedPath $p) {
                    Write-Log "IGNORED (trusted folder): $p"
                    continue
                }

                Write-Log "DETECTED NEW WSB FILE: $p"
                $detectionWatch = [System.Diagnostics.Stopwatch]::StartNew()
                Quarantine-File $p $detectionWatch
            }
        }
    }

    Start-Sleep -Seconds $PollingInterval
}

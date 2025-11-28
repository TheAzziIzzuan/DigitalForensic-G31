<#
WSB Hunter - Detects and neutralizes rogue Windows Sandbox configurations
This script scans for suspicious .wsb files, analyzes their content,
and optionally quarantines them for further analysis.

Usage:
  # Scan only (detect but don't touch)
  powershell -ExecutionPolicy Bypass -File .\wsb-hunter.ps1 -ScanPath "C:\" -QuarantineMode $false

  # Scan and quarantine
  powershell -ExecutionPolicy Bypass -File .\wsb-hunter.ps1 -ScanPath "C:\" -QuarantineMode $true

  # Scheduled task to run every 6 hours
  Register-ScheduledTask -TaskName "WSB-Hunter" -Trigger (New-ScheduledTaskTrigger -At 00:00 -RepetitionInterval (New-TimeSpan -Hours 6) -RepetitionDuration (New-TimeSpan -Days 1)) -Action (New-ScheduledTaskAction -Execute powershell -Argument "-ExecutionPolicy Bypass -File C:\Scripts\wsb-hunter.ps1")
#>

param(
    [string]$ScanPath = "C:\",
    [bool]$QuarantineMode = $false,
    [string]$QuarantineDir = "C:\WSB_Quarantine",
    [string]$LogFile = "C:\Logs\wsb-hunter.log",
    [string[]]$WhitelistedPaths = @("C:\Temp\SandboxRun", "C:\Sandy-Temp"),
    [switch]$Verbose
)

# Ensure log directory exists
if (-not (Test-Path (Split-Path $LogFile))) {
    New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUSPICIOUS", "QUARANTINED")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to file
    Add-Content -Path $LogFile -Value $logEntry
    
    # Write to console with color
    switch ($Level) {
        "INFO" { Write-Host $logEntry -ForegroundColor Gray }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "SUSPICIOUS" { Write-Host $logEntry -ForegroundColor Magenta }
        "QUARANTINED" { Write-Host $logEntry -ForegroundColor Red }
    }
}

function Get-WSBFiles {
    param([string]$Path)
    
    try {
        Get-ChildItem -Path $Path -Filter "*.wsb" -Recurse -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log "Error scanning $Path : $_" -Level "ERROR"
        return $null
    }
}

function Test-IsWhitelisted {
    param([string]$FilePath)
    
    foreach ($whitelistedPath in $WhitelistedPaths) {
        if ($FilePath -like "$whitelistedPath*") {
            return $true
        }
    }
    return $false
}

function Analyze-WSBFile {
    param([System.IO.FileInfo]$File)
    
    $analysis = @{
        Path                = $File.FullName
        FileName            = $File.Name
        CreatedTime         = $File.CreationTime
        ModifiedTime        = $File.LastWriteTime
        Owner               = (Get-Acl -Path $File.FullName -ErrorAction SilentlyContinue).Owner
        Size                = $File.Length
        IsSuspicious        = $false
        IsWhitelisted       = $false
        Reasons             = @()
        LogonCommand        = ""
        MappedFolders       = @()
        Content             = ""
        RiskScore           = 0
    }

    # Check whitelist first
    if (Test-IsWhitelisted -FilePath $File.FullName) {
        $analysis.IsWhitelisted = $true
        return $analysis
    }

    # Read file content
    try {
        $analysis.Content = Get-Content -Path $File.FullName -Raw -ErrorAction SilentlyContinue
    }
    catch {
        $analysis.IsSuspicious = $true
        $analysis.Reasons += "Cannot read file content: $_"
        return $analysis
    }

    if (-not $analysis.Content) {
        $analysis.IsSuspicious = $true
        $analysis.Reasons += "File is empty or unreadable"
        return $analysis
    }

    # ===== ANALYSIS CHECKS =====

    # Check 1: Suspicious LogonCommand patterns
    if ($analysis.Content -match '<LogonCommand>') {
        $cmdMatch = [regex]::Match($analysis.Content, '<Command>(.*?)</Command>', 'Singleline')
        if ($cmdMatch.Success) {
            $command = $cmdMatch.Groups[1].Value
            $analysis.LogonCommand = $command
            
            # Define suspicious command patterns
            $suspiciousPatterns = @{
                'powershell.*-enc'           = 'Encoded PowerShell (obfuscation)'
                'cmd.*\/c.*powershell'       = 'Hidden PowerShell execution'
                'certutil.*-decode'          = 'File decode (malware staging)'
                'bitsadmin.*download'        = 'Background file download (data exfiltration)'
                '(curl|wget|Invoke-WebRequest).*http' = 'Remote file download'
                'reg.*add.*run'              = 'Registry persistence (Run key)'
                'reg.*add.*startup'          = 'Registry persistence (Startup)'
                'schtasks.*create'           = 'Scheduled task creation (persistence)'
                'copy.*system32'             = 'System file copy (privilege escalation)'
                'del.*windows'               = 'Windows file deletion (destructive)'
                'taskkill.*system'           = 'Process termination (destructive)'
                '\.exe["\s]'                 = 'Direct executable execution'
                'psexec'                     = 'PsExec (lateral movement)'
                'wmiexec'                    = 'WMI execution (lateral movement)'
                'mimikatz'                   = 'Known credential dumper'
                'reverse.*shell'             = 'Reverse shell pattern'
                'nc\.exe.*-l'                = 'Netcat listener (C2)'
            }
            
            foreach ($pattern in $suspiciousPatterns.Keys) {
                if ($command -match $pattern) {
                    $analysis.IsSuspicious = $true
                    $analysis.RiskScore += 25
                    $analysis.Reasons += "Suspicious command pattern: $($suspiciousPatterns[$pattern])"
                    Write-Log "  Pattern match: '$pattern' in command" -Level "WARNING"
                }
            }
        }
    }

    # Check 2: Mapped folders analysis
    if ($analysis.Content -match '<HostFolder>') {
        $mappedFolders = [regex]::Matches($analysis.Content, '<HostFolder>(.*?)</HostFolder>')
        
        $approvedPaths = @("C:\Temp", "C:\Users", "C:\SandboxConfigs", "C:\Sandy-Temp", "C:\Artifacts")
        
        foreach ($folder in $mappedFolders) {
            $path = $folder.Groups[1].Value.Trim()
            $analysis.MappedFolders += $path
            
            # Check if path is approved
            $isApproved = $false
            foreach ($approvedPath in $approvedPaths) {
                if ($path -like "$approvedPath*" -or $path -eq $approvedPath) {
                    $isApproved = $true
                    break
                }
            }
            
            if (-not $isApproved) {
                $analysis.IsSuspicious = $true
                $analysis.RiskScore += 20
                $analysis.Reasons += "Suspicious mapped folder: $path (not in approved list)"
                Write-Log "  Unapproved path: $path" -Level "WARNING"
            }
        }
    }

    # Check 3: Writable mapped folders (can exfiltrate data)
    if ($analysis.Content -match '<ReadOnly>false</ReadOnly>') {
        $analysis.IsSuspicious = $true
        $analysis.RiskScore += 15
        $analysis.Reasons += "Mapped folder is writable (potential data exfiltration risk)"
    }

    # Check 4: Networking enabled
    if ($analysis.Content -match '<Networking>Enable</Networking>') {
        $analysis.RiskScore += 10
        if ($analysis.IsSuspicious) {
            $analysis.Reasons += "Network enabled (combined with other suspicious features)"
        }
    }

    # Check 5: Unusual file owner
    if ($analysis.Owner -and $analysis.Owner -notmatch "SYSTEM|Administrators|$env:USERNAME") {
        $analysis.IsSuspicious = $true
        $analysis.RiskScore += 15
        $analysis.Reasons += "Unusual owner: $($analysis.Owner) (not current user/admin)"
    }

    # Check 6: File location outside standard paths
    $standardLocations = @("C:\Users", "C:\Temp", "C:\Sandy", "C:\SandboxConfigs", "C:\Windows\Temp", "$env:APPDATA")
    $isStandardLocation = $false
    foreach ($location in $standardLocations) {
        if ($File.FullName -like "$location*") {
            $isStandardLocation = $true
            break
        }
    }
    
    if (-not $isStandardLocation) {
        $analysis.RiskScore += 10
        if ($analysis.IsSuspicious) {
            $analysis.Reasons += "Suspicious file location (outside standard paths)"
        }
    }

    # Check 7: Recent modification time (potential active threat)
    $lastModified = (Get-Date) - $File.LastWriteTime
    if ($lastModified.TotalHours -lt 1) {
        $analysis.RiskScore += 5
        if ($analysis.IsSuspicious) {
            $analysis.Reasons += "Recently modified (potential active threat)"
        }
    }

    # Check 8: File size anomalies (very large config files are suspicious)
    if ($analysis.Size -gt 100KB) {
        $analysis.IsSuspicious = $true
        $analysis.RiskScore += 10
        $analysis.Reasons += "Unusually large .wsb file ($($analysis.Size) bytes)"
    }

    return $analysis
}

function Quarantine-WSBFile {
    param([System.IO.FileInfo]$File, [string]$QuarantineDir)
    
    if (-not (Test-Path $QuarantineDir)) {
        try {
            New-Item -ItemType Directory -Path $QuarantineDir -Force | Out-Null
        }
        catch {
            Write-Log "ERROR: Cannot create quarantine directory $QuarantineDir : $_" -Level "ERROR"
            return $false
        }
    }
    
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $quarantineName = "$($File.BaseName)_$timestamp.wsb"
    $quarantinePath = Join-Path $QuarantineDir $quarantineName
    
    try {
        Move-Item -Path $File.FullName -Destination $quarantinePath -Force
        Write-Log "QUARANTINED: $($File.FullName) -> $quarantinePath" -Level "QUARANTINED"
        
        # Create analysis report
        $reportPath = "$quarantinePath.analysis.txt"
        $analysis | Out-File -FilePath $reportPath
        Write-Log "Analysis report saved to: $reportPath" -Level "INFO"
        
        return $true
    }
    catch {
        Write-Log "ERROR quarantining $($File.FullName): $_" -Level "ERROR"
        return $false
    }
}

function Generate-Report {
    param($ScanResults)
    
    $report = @"
================================
    WSB HUNTER SCAN REPORT
================================
Scan Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Scan Path: $ScanPath
Quarantine Mode: $QuarantineMode

SUMMARY:
--------
Total .wsb files found: $($ScanResults.Count)
Whitelisted files: $($ScanResults | Where-Object { $_.IsWhitelisted } | Measure-Object | Select-Object -ExpandProperty Count)
Suspicious files: $($ScanResults | Where-Object { $_.IsSuspicious } | Measure-Object | Select-Object -ExpandProperty Count)
Quarantined files: $($ScanResults | Where-Object { $_.Quarantined } | Measure-Object | Select-Object -ExpandProperty Count)

SUSPICIOUS FILES DETECTED:
--------------------------
"@

    foreach ($file in $ScanResults | Where-Object { $_.IsSuspicious }) {
        $report += "`nFile: $($file.Path)`n"
        $report += "Risk Score: $($file.RiskScore)/100`n"
        $report += "Reasons:`n"
        foreach ($reason in $file.Reasons) {
            $report += "  - $reason`n"
        }
        $report += "Logon Command: $($file.LogonCommand)`n"
        $report += "Mapped Folders: $($file.MappedFolders -join ', ')`n"
        $report += "---`n"
    }

    $reportPath = Join-Path (Split-Path $LogFile) "wsb-hunter-report_$(Get-Date -Format 'yyyyMMddHHmmss').txt"
    $report | Out-File -FilePath $reportPath
    Write-Log "Report generated: $reportPath" -Level "INFO"
    
    return $reportPath
}

# ===== MAIN EXECUTION =====

Write-Log "========================================" -Level "INFO"
Write-Log "WSB HUNTER STARTED" -Level "INFO"
Write-Log "========================================" -Level "INFO"
Write-Log "Scan Path: $ScanPath" -Level "INFO"
Write-Log "Quarantine Mode: $QuarantineMode" -Level "INFO"
Write-Log "Log File: $LogFile" -Level "INFO"

if (-not (Test-Path $ScanPath)) {
    Write-Log "ERROR: Scan path does not exist: $ScanPath" -Level "ERROR"
    exit 1
}

# Find all .wsb files
Write-Log "Scanning for .wsb files..." -Level "INFO"
$wsbFiles = Get-WSBFiles -Path $ScanPath

if ($null -eq $wsbFiles) {
    Write-Log "No .wsb files found or scan error occurred" -Level "WARNING"
    exit 0
}

if ($wsbFiles -is [single]) {
    $wsbFiles = @($wsbFiles)
}

Write-Log "Found $($wsbFiles.Count) .wsb file(s)" -Level "INFO"

# Analyze each file
$scanResults = @()
$suspiciousCount = 0
$quarantinedCount = 0

foreach ($file in $wsbFiles) {
    Write-Log "Analyzing: $($file.FullName)" -Level "INFO"
    $analysis = Analyze-WSBFile -File $file
    
    if ($analysis.IsWhitelisted) {
        Write-Log "  WHITELISTED: $($file.FullName)" -Level "INFO"
        $analysis | Add-Member -NotePropertyName "Quarantined" -NotePropertyValue $false
    }
    elseif ($analysis.IsSuspicious) {
        $suspiciousCount++
        $analysis | Add-Member -NotePropertyName "Quarantined" -NotePropertyValue $false
        
        $reasonsStr = $analysis.Reasons -join " | "
        Write-Log "  SUSPICIOUS (Risk: $($analysis.RiskScore)/100): $reasonsStr" -Level "SUSPICIOUS"
        
        if ($QuarantineMode) {
            if (Quarantine-WSBFile -File $file -QuarantineDir $QuarantineDir) {
                $quarantinedCount++
                $analysis.Quarantined = $true
            }
        }
    }
    else {
        Write-Log "  SAFE: $($file.FullName)" -Level "INFO"
        $analysis | Add-Member -NotePropertyName "Quarantined" -NotePropertyValue $false
    }
    
    $scanResults += $analysis
}

# Generate report
Write-Log "Generating scan report..." -Level "INFO"
$reportPath = Generate-Report -ScanResults $scanResults

# Summary
Write-Log "========================================" -Level "INFO"
Write-Log "SCAN COMPLETE" -Level "INFO"
Write-Log "Total files: $($scanResults.Count)" -Level "INFO"
Write-Log "Suspicious: $suspiciousCount" -Level "INFO"
Write-Log "Quarantined: $quarantinedCount" -Level "INFO"
Write-Log "Report: $reportPath" -Level "INFO"
Write-Log "========================================" -Level "INFO"

# Return exit code based on findings
if ($suspiciousCount -gt 0) {
    exit 1
}
else {
    exit 0
}

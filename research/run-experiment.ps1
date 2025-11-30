param(
    [int]$TrialsPerConfig = 100,
    [string]$ResultsDirectory = "C:\Research\WSB-Hunter-Latency\results",
    [ValidateSet("1", "3", "5")]
    [string]$TestDepth = "1"
)

# Create results directory
if (-not (Test-Path $ResultsDirectory)) {
    New-Item -ItemType Directory -Path $ResultsDirectory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$sessionId = "Experiment_Depth${TestDepth}_$timestamp"
$sessionDir = Join-Path $ResultsDirectory $sessionId

New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "WSB-Hunter Detection Latency Research" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test Depth: $TestDepth (ISOLATED - only files at exactly this depth)" -ForegroundColor Yellow
Write-Host "Session ID: $sessionId"
Write-Host "Results Directory: $sessionDir"
Write-Host "Trials: $TrialsPerConfig"
Write-Host ""
Write-Host "Make sure detector is running with: -ScanDepth $TestDepth" -ForegroundColor Cyan
Write-Host ""

$allResults = @()

# Single configuration for this run
# Use REALISTIC attack directories, not just nested Downloads folders

$attackDirectories = @{
    "1" = @{
        Name = "Depth_1"
        Description = "Files at shallow locations (easy to find)"
        Locations = @(
            "$env:USERPROFILE\Downloads",
            "$env:USERPROFILE\Desktop",
            "$env:TEMP"
        )
    }
    "3" = @{
        Name = "Depth_3"
        Description = "Files hidden 3 levels in user directories"
        Locations = @(
            "$env:USERPROFILE\AppData\Local\Temp",
            "$env:USERPROFILE\Documents\Work",
            "$env:USERPROFILE\Downloads\Archive"
        )
    }
    "5" = @{
        Name = "Depth_5"
        Description = "Files DEEP in system directories (realistic attacker hiding)"
        Locations = @(
            "C:\ProgramData\Microsoft\Windows\Caches\Temp\Work",
            "C:\Windows\Temp\System\Cache\Data",
            "$env:USERPROFILE\AppData\Local\Microsoft\Edge\Cache\Storage"
        )
    }
}

$depthConfig = $attackDirectories[$TestDepth]

$config = @{
    Name = $depthConfig.Name
    Description = $depthConfig.Description
    ScanScope = "Default"
    ScanDepth = $TestDepth
    TargetDirectories = $depthConfig.Locations
    RiskLevel = "low"
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Yellow
Write-Host "Configuration: $($config.Name)" -ForegroundColor Yellow
Write-Host "Description: $($config.Description)" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow
Write-Host ""

$configResultsFile = Join-Path $sessionDir "$($config.Name)_results.csv"

# Create header for this configuration's results
$header = "Trial,FilePath,CreationTime,TargetDirectory,RiskLevel"
Add-Content -Path $configResultsFile -Value $header

# Distribute trials evenly across target directories
$filesPerDirectory = [math]::Ceiling($TrialsPerConfig / $config.TargetDirectories.Count)
$fileCounter = 0

foreach ($targetDir in $config.TargetDirectories) {
    # Create target directory if it doesn't exist
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Write-Host "  Created directory: $targetDir" -ForegroundColor Green
    }

    for ($trial = 1; $trial -le $filesPerDirectory -and $fileCounter -lt $TrialsPerConfig; $trial++) {
        $fileCounter++
        $outputFile = "$targetDir\test-$fileCounter.wsb"
        Write-Host "  Trial $fileCounter/$TrialsPerConfig (Dir: $targetDir)..." -NoNewline

        try {
            # Generate test file
            $testFile = & "$(Split-Path $PSCommandPath)\generate-test-file.ps1" `
                -TrialNumber $fileCounter `
                -TargetDirectory $targetDir `
                -DirectoryDepth 1 `
                -RiskLevel $config.RiskLevel `
                -OutputFile $outputFile -ErrorAction Stop

            if (-not (Test-Path $outputFile)) {
                Write-Host " FAILED (file not created)" -ForegroundColor Red
                continue
            }

            # Record test file info
            $resultLine = "$fileCounter,$($testFile.FilePath),$($testFile.CreationTime),$targetDir,$($testFile.RiskLevel)"
            Add-Content -Path $configResultsFile -Value $resultLine

            # Delay to let detector find it (important!)
            Start-Sleep -Milliseconds 800

            Write-Host " OK"
        }
        catch {
            Write-Host " ERROR: $_" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "All files created. Waiting for detector to complete scans..." -ForegroundColor Cyan
Write-Host "Keep detector running for at least 30 more seconds" -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "Results saved to: $configResultsFile" -ForegroundColor Green

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "Experiment Complete for Depth $TestDepth" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Session Results Directory:"
Write-Host "  $sessionDir"
Write-Host ""
Write-Host "Data logged to CSV: $configResultsFile"
Write-Host ""
Write-Host "NEXT STEPS:"
Write-Host "  1. Check C:\WSB_Quarantine\performance.csv for detection results"
Write-Host "  2. Run remaining depths: Test with -TestDepth 3 and -TestDepth 5"
Write-Host "  3. Compare DetectionLatencyMs across all depths"
Write-Host ""

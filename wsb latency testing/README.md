# WSB-Hunter Detection Latency Research

## Overview

This directory contains scripts and tools for measuring WSB file detection latency at different directory nesting depths. The research evaluates how filesystem depth impacts detection performance across realistic attack scenarios.

## Scripts

- wsb-hunter-instrumented.ps1 - Enhanced detector with millisecond-precision timestamps and CSV logging
- generate-test-file.ps1 - Creates test .wsb files with configurable depth and risk levels
- run-experiment.ps1 - Orchestrates test file generation across multiple depths
- visualization.py - Python tools for analyzing and visualizing results

## CSV Output

Results are logged to: C:\WSB_Quarantine\performance.csv

### Format

Timestamp (datetime)
EventType (string: FileQuarantined / FileQuarantineFailed)
FilePath (string: full path)
DetectionLatencyMs (integer) <- PRIMARY METRIC
QuarantineLatencyMs (integer)
AnalysisLatencyMs (integer)
TotalResponseTimeMs (integer)
RiskScore (integer: 0-135+)
Details (string: analysis findings)

### Example Output

Timestamp,EventType,FilePath,DetectionLatencyMs,QuarantineLatencyMs,AnalysisLatencyMs,TotalResponseTimeMs,RiskScore,Details
2025-11-29 12:00:01.234,FileQuarantined,C:\Users\user\Downloads\test-1.wsb,142,48,67,257,0,
2025-11-29 12:00:02.456,FileQuarantined,C:\Users\user\Downloads\level2\level3\test-2.wsb,387,52,89,528,20,Networking enabled (+20)

## Running Experiments

Experiments are organized by directory depth to simulate different attack scenarios.

### Depth 1 - Shallow (Obvious Locations)

Files placed in commonly accessed directories:
- C:\Users\<user>\Downloads
- C:\Users\<user>\Desktop
- C:\Windows\Temp

Terminal 1:
\\\powershell
cd C:\Users\itsam\OneDrive\Documents\GitHub\DigitalForensic-G31\wsb latency testing
powershell -ExecutionPolicy Bypass -File .\wsb-hunter-instrumented.ps1 -ScanScope Shallow -ScanDepth 1
\\\

Terminal 2 (after detector reports "Real-time monitoring active"):
\\\powershell
cd C:\Users\itsam\OneDrive\Documents\GitHub\DigitalForensic-G31\wsb latency testing
powershell -ExecutionPolicy Bypass -File .\run-experiment.ps1 -TestDepth 1 -TrialsPerConfig 100
\\\

### Depth 3 - Medium (User Directory Nesting)

Files hidden in nested user directories:
- C:\Users\<user>\AppData\Local\Temp
- C:\Users\<user>\Documents\Work
- C:\Users\<user>\Downloads\Archive

Terminal 1:
\\\powershell
powershell -ExecutionPolicy Bypass -File .\wsb-hunter-instrumented.ps1 -ScanScope Medium -ScanDepth 3
\\\

Terminal 2:
\\\powershell
powershell -ExecutionPolicy Bypass -File .\run-experiment.ps1 -TestDepth 3 -TrialsPerConfig 100
\\\

### Depth 5 - Deep (System Directory Nesting)

Files hidden in deeply nested system paths:
- C:\ProgramData\Microsoft\Windows\Caches\Temp\Work
- C:\Windows\Temp\System\Cache\Data
- C:\Users\<user>\AppData\Local\Microsoft\Edge\Cache\Storage

Terminal 1:
\\\powershell
powershell -ExecutionPolicy Bypass -File .\wsb-hunter-instrumented.ps1 -ScanScope Deep -ScanDepth 5
\\\

Terminal 2:
\\\powershell
powershell -ExecutionPolicy Bypass -File .\run-experiment.ps1 -TestDepth 5 -TrialsPerConfig 100
\\\

## Test Configuration

| Depth | Scenario | Example Locations | Test Files |
|-------|----------|-------------------|-----------|
| 1 | Shallow | Downloads, Desktop, Temp | 100 total (3 dirs) |
| 3 | Medium | AppData\Temp, Documents, Downloads\Archive | 100 total (3 dirs) |
| 5 | Deep | ProgramData paths, Windows\Temp, Edge\Cache | 100 total (3 dirs) |

Total: 300 test files across realistic attack locations

## Analysis

### Primary Metric

Detection Latency (ms) - Time elapsed from file creation to detection by the scanner.

File Created at T=0ms

Detector polls filesystem

DetectionLatencyMs = Time elapsed

### Data Analysis

The CSV output is ready for analysis in multiple tools:

**Excel:**
1. Open C:\WSB_Quarantine\performance.csv
2. Create charts (Timestamp vs DetectionLatencyMs)
3. Generate pivot tables by depth

**Python:**
\\\python
import pandas as pd
df = pd.read_csv('C:\\\\WSB_Quarantine\\\\performance.csv')
print(df['DetectionLatencyMs'].describe())
print(f"95th percentile: {df['DetectionLatencyMs'].quantile(0.95)}")
\\\

**R:**
\\\
df <- read.csv('C:\\\\WSB_Quarantine\\\\performance.csv')
boxplot(df\, main="Detection Latency Distribution")
\\\

## Output Files

After running experiments, the following files are generated:

- C:\WSB_Quarantine\performance.csv - Raw detection data (300+ rows)

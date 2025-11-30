# WSB-Hunter Detection Latency Research - Quick Start

## ✅ What Has Been Created

```
C:\Users\itsam\OneDrive\Documents\GitHub\DigitalForensic-G31\wsb latency testing\
├── wsb-hunter-instrumented.ps1      ← Modified detector with CSV logging
├── generate-test-file.ps1            ← Creates test .wsb files
├── run-experiment.ps1                ← Orchestrates test file generation
├── visualization.py                  ← Python visualization tools
└── QUICKSTART.md                     ← This file
```

## 📊 CSV Output Location

**Main Performance Data**: `C:\WSB_Quarantine\performance.csv`

Format:
```
Timestamp,EventType,FilePath,DetectionLatencyMs,QuarantineLatencyMs,AnalysisLatencyMs,TotalResponseTimeMs,RiskScore,Details
```

All values are **numeric** and ready for graphing in Excel, Python, or R.

## ⚡ Quick Start (Run Per Depth)

**Realistic attack scenarios across actual system directories**

### Iteration 1 - Depth 1 (Shallow - Easy to Find)

Files hidden in obvious places where attackers leave initial payloads:
- `C:\Users\<user>\Downloads`
- `C:\Users\<user>\Desktop`
- `C:\Windows\Temp`

**Terminal 1** (Keep running):
```powershell
cd C:\Users\itsam\OneDrive\Documents\GitHub\DigitalForensic-G31\wsb latency testing
powershell -ExecutionPolicy Bypass -File .\wsb-hunter-instrumented.ps1 -ScanScope Shallow -ScanDepth 1
```

Wait for it to say: "Real-time monitoring active"

**Terminal 2** (After detector is ready):
```powershell
cd C:\Users\itsam\OneDrive\Documents\GitHub\DigitalForensic-G31\wsb latency testing
powershell -ExecutionPolicy Bypass -File .\run-experiment.ps1 -TestDepth 1 -TrialsPerConfig 100
```

Generates 100 test files distributed across 3 shallow directories (~33 each).

### Iteration 2 - Depth 3 (Medium - Hidden by Attackers)

Files hidden deeper in user directories (common attacker pattern):
- `C:\Users\<user>\AppData\Local\Temp`
- `C:\Users\<user>\Documents\Work`
- `C:\Users\<user>\Downloads\Archive`

**Terminal 1**:
```powershell
powershell -ExecutionPolicy Bypass -File .\wsb-hunter-instrumented.ps1 -ScanScope Medium -ScanDepth 3
```

**Terminal 2**:
```powershell
powershell -ExecutionPolicy Bypass -File .\run-experiment.ps1 -TestDepth 3 -TrialsPerConfig 100
```

Generates 100 test files distributed across 3 medium-depth directories.

### Iteration 3 - Depth 5 (Deep - System-Level Hiding)

Files hidden DEEP in system directories (sophisticated attackers):
- `C:\ProgramData\Microsoft\Windows\Caches\Temp\Work`
- `C:\Windows\Temp\System\Cache\Data`
- `C:\Users\<user>\AppData\Local\Microsoft\Edge\Cache\Storage`

**Terminal 1**:
```powershell
powershell -ExecutionPolicy Bypass -File .\wsb-hunter-instrumented.ps1 -ScanScope Deep -ScanDepth 5
```

**Terminal 2**:
```powershell
powershell -ExecutionPolicy Bypass -File .\run-experiment.ps1 -TestDepth 5 -TrialsPerConfig 100
```

Generates 100 test files distributed across 3 deep system directories. Detector must traverse actual Windows system paths.

**Result**: 100 records per depth across REALISTIC attack locations. Measure detection latency in actual threat scenarios.

## 📈 CSV Analysis Options

### Excel
1. Open `C:\WSB_Quarantine\performance.csv`
2. Create charts (Timestamp vs DetectionLatencyMs)
3. Generate pivot tables

### Python
```python
import pandas as pd
df = pd.read_csv('C:\\WSB_Quarantine\\performance.csv')
print(df['DetectionLatencyMs'].describe())  # Statistics
```

### R
```r
df <- read.csv('C:\\WSB_Quarantine\\performance.csv')
hist(df$DetectionLatencyMs)  # Histogram
```

## 🎯 What Gets Tested

| Depth | Scenario | Example Locations | Files |
|---|---|---|---|
| **1** | Shallow (obvious) | Downloads, Desktop, Temp | 100 total (3 dirs) |
| **3** | Medium (user-hidden) | AppData\Temp, Documents, Downloads\Archive | 100 total (3 dirs) |
| **5** | Deep (system-hidden) | ProgramData paths, Windows\Temp, Edge\Cache | 100 total (3 dirs) |

**Total**: 300 test files in realistic attack locations

## 📊 Primary Metric: Detection Latency (ms)

This is what you'll measure:

```
File Created at T=0ms
↓
Detector polls and finds file
↓
DetectionLatencyMs = Time elapsed (your research metric!)
```

## ✅ All Data to CSV - No Manual Work!

- ✅ Every detection logged automatically
- ✅ Timestamps precise to millisecond
- ✅ Risk scores calculated automatically
- ✅ All latency components recorded
- ✅ Ready for statistical analysis

## 🚀 Test Status

**Tests have NOT been run yet** - you need to:

1. ✅ Create and configure scripts → DONE
2. ⏳ Run experiments (3 depths) → YOUR TURN
3. ⏳ Analyze and compare results → After step 2

## Next: Run Your First Experiment

See **Step 1** above - open that PowerShell window and start collecting data for Depth 1! 🎯

After collecting all 3 depths, compare your `DetectionLatencyMs` values across depths in `C:\WSB_Quarantine\performance.csv`.

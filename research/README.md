# 📊 WSB-Hunter Detection Latency Research

## Summary

**CSV Output: ✅ YES - All results automatically logged to CSV**

Your research infrastructure is now ready. All experimental results will be saved in CSV format for analysis.

---

## What You Have

### Scripts Created (in `\research\` folder)

1. **wsb-hunter-instrumented.ps1**
   - Enhanced detector with millisecond-precision timestamps
   - Logs all detections to `C:\WSB_Quarantine\performance.csv`
   - Configurable scan scope and depth
   - CSV columns: Timestamp, EventType, FilePath, DetectionLatencyMs, QuarantineLatencyMs, AnalysisLatencyMs, TotalResponseTimeMs, RiskScore, Details

2. **generate-test-file.ps1**
   - Creates test `.wsb` files with configurable:
     - Directory depth (1-10 levels)
     - Risk levels (empty, low, medium, high)
     - Precise creation timestamps

3. **run-experiment.ps1**
   - Orchestrates test generation
   - Runs 3 isolated depth tests × 30 trials each = 90 test cases
   - Creates test files in isolated directory structures

4. **analyze-results.ps1**
   - Processes performance CSV
   - Generates statistical summary (mean, stddev, min, max, median)
   - Creates human-readable report

5. **CSV_OUTPUT_FORMAT.md**
   - Complete CSV format documentation
   - Examples and use cases
   - Python/R/Excel analysis templates

6. **PHASE1_QUICKSTART.md**
   - Quick reference guide
   - 3-step quick start
   - Troubleshooting

---

## CSV Output Details

### Location
`C:\WSB_Quarantine\performance.csv`

### Format (9 columns)
```
Timestamp (datetime)
EventType (string: FileQuarantined / FileQuarantineFailed)
FilePath (string: full path)
DetectionLatencyMs (integer) ← PRIMARY METRIC
QuarantineLatencyMs (integer)
AnalysisLatencyMs (integer)
TotalResponseTimeMs (integer)
RiskScore (integer: 0-135+)
Details (string: analysis findings)
```

### Example Rows
```csv
Timestamp,EventType,FilePath,DetectionLatencyMs,QuarantineLatencyMs,AnalysisLatencyMs,TotalResponseTimeMs,RiskScore,Details
2025-11-29 12:00:01.234,FileQuarantined,C:\Users\user\Downloads\test-1.wsb,142,48,67,257,0,
2025-11-29 12:00:02.456,FileQuarantined,C:\Users\user\Downloads\level2\level3\test-2.wsb,387,52,89,528,20,Networking enabled (+20)
```

### Ready for Analysis
- ✅ Excel: Open directly, create charts
- ✅ Python: `pd.read_csv()`, statistical analysis
- ✅ R: `read.csv()`, ggplot2 visualizations
- ✅ PowerBI: Direct import for dashboards

---

## Has Testing Been Run?

**No, not yet.** The scripts are created but you need to execute them. Here's what to do:

### Run Tests Now (3 simple steps per depth)

**For EACH depth (1, 3, 5):**

**Terminal 1 - Detector** (Keep running)
```powershell
cd C:\Users\itsam\OneDrive\Documents\GitHub\DigitalForensic-G31\research
powershell -ExecutionPolicy Bypass -File .\wsb-hunter-instrumented.ps1 -ScanScope Shallow -ScanDepth 1
```

**Terminal 2 - Test Generator** (After 5 seconds)
```powershell
cd C:\Users\itsam\OneDrive\Documents\GitHub\DigitalForensic-G31\research
powershell -ExecutionPolicy Bypass -File .\run-experiment.ps1 -TestDepth 1
```

**Then repeat with -ScanScope Medium -ScanDepth 3 and -ScanScope Deep -ScanDepth 5**

---

## Expected Outcomes

After running:

### Files Created
1. `C:\WSB_Quarantine\performance.csv` - Raw data (150+ rows)
2. `C:\Research\WSB-Hunter-Latency\analysis\summary-report.txt` - Statistics
3. `C:\Research\WSB-Hunter-Latency\analysis\performance-analysis.csv` - Formatted for charting

### Metrics You'll Get
- **Mean Detection Latency**: e.g., 245ms
- **Standard Deviation**: e.g., ±67ms
- **Min/Max Range**: e.g., 89ms - 512ms
- **95% Confidence Interval**: e.g., 113ms - 377ms
- **Risk Score Distribution**: How many scored 0, 20, 80, 135, etc.

### For Your Paper
- Tables of statistics
- Graphs showing depth impact
- Latency component breakdown
- Risk score accuracy verification

---

## Configuration Details

### Test Configurations

3 isolated depth tests × 30 trials each:

| Name | Description | Depth | Directory |
|------|-------------|-------|-----------|
| Default_Depth1 | Shallow baseline | 1 | Downloads root |
| Default_Depth3 | Medium nesting | 3 | Downloads/level2/level3 |
| Default_Depth5 | Deep nesting | 5 | Downloads/level2/level3/level4/level5 |

### Threat Model
- Realistic: Attackers use non-admin paths
- Obfuscation: Nested directory structures
- Staging: %TEMP% and Public folders

---

## CSV Analysis Quick Examples

### Python: Basic Statistics
```python
import pandas as pd
df = pd.read_csv('C:\\WSB_Quarantine\\performance.csv')

# Get stats for all detections
print(df['DetectionLatencyMs'].describe())
print(f"95th percentile: {df['DetectionLatencyMs'].quantile(0.95)}")

# By configuration (if you add config column)
# grouped = df.groupby('Configuration')['DetectionLatencyMs'].describe()
```

### Excel: Create Chart
1. Select columns A (Timestamp) and D (DetectionLatencyMs)
2. Insert → Line Chart
3. Title: "Detection Latency Over Time"

### R: Visualization
```r
df <- read.csv('C:\\WSB_Quarantine\\performance.csv')
boxplot(df$DetectionLatencyMs, main="Detection Latency Distribution")
```

---

## Next Steps

1. **✅ Done**: Infrastructure created
2. **→ NOW**: Run experiments for each depth (Depth 1, 3, 5)
3. **→ ANALYZE**: Compare DetectionLatencyMs across depths in CSV
4. **→ VISUALIZE**: Create charts from CSV data
5. **→ DOCUMENT**: Add findings to research paper

---

## Questions?

Refer to:
- **Quick Start**: `QUICKSTART.md`
- **CSV Format**: `CSV_OUTPUT_FORMAT.md`
- **Script Help**: Read comments in each `.ps1` file

**Ready to collect your first data! 🚀**

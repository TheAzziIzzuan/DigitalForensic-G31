import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
from pathlib import Path

# Set style for publication-quality graphs
sns.set_style("whitegrid")
plt.rcParams['figure.dpi'] = 300
plt.rcParams['savefig.dpi'] = 300
plt.rcParams['font.size'] = 11
plt.rcParams['figure.figsize'] = (12, 7)

# Load the three CSV files
files = {
    'Shallow': 'dataset/100shallow.csv',
    'Medium': 'dataset/100med.csv',
    'Deep': 'dataset/100deep.csv'
}

data = {}
for scan_type, filename in files.items():
    try:
        data[scan_type] = pd.read_csv(filename)
        print(f"✓ Loaded {scan_type} scan: {len(data[scan_type])} records")
    except FileNotFoundError:
        print(f"✗ File not found: {filename}")
        print("  Make sure CSV files are in the same directory as this script")

if not data:
    print("No files loaded. Exiting.")
    exit()

# ============================================================================
# ANALYSIS 1: Response Time Comparison (Bar Chart)
# ============================================================================
print("\n--- ANALYSIS 1: Response Time Comparison ---")
response_times = {}
for scan_type, df in data.items():
    avg_time = df['TotalResponseTimeMs'].mean()
    response_times[scan_type] = avg_time
    print(f"{scan_type}: {avg_time:.2f}ms (±{df['TotalResponseTimeMs'].std():.2f}ms)")

fig, ax = plt.subplots(figsize=(10, 6))
colors = ['#2ecc71', '#f39c12', '#e74c3c']  # Green for shallow, orange for med, red for deep
bars = ax.bar(response_times.keys(), response_times.values(), color=colors, alpha=0.8, edgecolor='black', linewidth=1.5)

# Add value labels on bars
for bar in bars:
    height = bar.get_height()
    ax.text(bar.get_x() + bar.get_width()/2., height,
            f'{height:.2f}ms',
            ha='center', va='bottom', fontweight='bold', fontsize=12)

ax.set_ylabel('Average Response Time (ms)', fontsize=12, fontweight='bold')
ax.set_xlabel('Scan Type', fontsize=12, fontweight='bold')
ax.set_title('Scan Speed Comparison: Shallow vs Medium vs Deep', fontsize=14, fontweight='bold', pad=20)
ax.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig('01_response_time_comparison.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 01_response_time_comparison.png\n")
plt.close()

# ============================================================================
# ANALYSIS 2: Response Time Distribution (Box Plot)
# ============================================================================
print("--- ANALYSIS 2: Response Time Distribution ---")
fig, ax = plt.subplots(figsize=(10, 6))
box_data = [data[st]['TotalResponseTimeMs'].values for st in ['Shallow', 'Medium', 'Deep']]
bp = ax.boxplot(box_data, labels=['Shallow', 'Medium', 'Deep'], patch_artist=True)

# Color the boxes
for patch, color in zip(bp['boxes'], colors):
    patch.set_facecolor(color)
    patch.set_alpha(0.7)

ax.set_ylabel('Response Time (ms)', fontsize=12, fontweight='bold')
ax.set_title('Response Time Distribution Across Scan Types', fontsize=14, fontweight='bold', pad=20)
ax.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig('02_response_time_distribution.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 02_response_time_distribution.png\n")
plt.close()

# ============================================================================
# ANALYSIS 3: Detection Count vs Speed Trade-off (Scatter)
# ============================================================================
print("--- ANALYSIS 3: Detection Rate vs Speed ---")
fig, ax = plt.subplots(figsize=(10, 6))

detection_counts = {}
for idx, (scan_type, df) in enumerate(data.items()):
    detection_count = len(df)
    detection_counts[scan_type] = detection_count
    avg_response_time = df['TotalResponseTimeMs'].mean()
    ax.scatter(avg_response_time, detection_count, s=300, alpha=0.7, 
               color=colors[idx], label=scan_type, edgecolors='black', linewidth=2)
    ax.annotate(scan_type, (avg_response_time, detection_count), 
                xytext=(5, 5), textcoords='offset points', fontweight='bold', fontsize=11)

ax.set_xlabel('Average Response Time (ms)', fontsize=12, fontweight='bold')
ax.set_ylabel('Number of Detections', fontsize=12, fontweight='bold')
ax.set_title('Detection Efficiency: Speed vs Detection Count', fontsize=14, fontweight='bold', pad=20)
ax.grid(alpha=0.3)
ax.legend(fontsize=11)
plt.tight_layout()
plt.savefig('03_detection_vs_speed.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 03_detection_vs_speed.png\n")
plt.close()

# ============================================================================
# ANALYSIS 4: File Path Analysis (Where are threats detected?)
# ============================================================================
print("--- ANALYSIS 4: File Path Analysis ---")
fig, axes = plt.subplots(1, 3, figsize=(16, 5))

for idx, (scan_type, df) in enumerate(data.items()):
    # Extract directory depth from FilePath
    path_counts = df['FilePath'].value_counts().head(8)
    
    axes[idx].barh(range(len(path_counts)), path_counts.values, color=colors[idx], alpha=0.8, edgecolor='black')
    axes[idx].set_yticks(range(len(path_counts)))
    axes[idx].set_yticklabels([p.replace('C:\\ProgramData\\', '')[:30] for p in path_counts.index], fontsize=9)
    axes[idx].set_xlabel('Detection Count', fontsize=11, fontweight='bold')
    axes[idx].set_title(f'{scan_type} Scan\n({len(df)} total detections)', fontsize=12, fontweight='bold')
    axes[idx].grid(axis='x', alpha=0.3)

plt.tight_layout()
plt.savefig('04_file_path_distribution.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 04_file_path_distribution.png\n")
plt.close()

# ============================================================================
# ANALYSIS 5: Latency Breakdown (Detection vs Quarantine vs Analysis)
# ============================================================================
print("--- ANALYSIS 5: Latency Component Breakdown ---")
fig, axes = plt.subplots(1, 3, figsize=(15, 5))

for idx, (scan_type, df) in enumerate(data.items()):
    avg_detection = df['DetectionLatencyMs'].mean()
    avg_quarantine = df['QuarantineLatencyMs'].mean()
    avg_analysis = df['AnalysisLatencyMs'].mean()
    
    components = ['Detection', 'Quarantine', 'Analysis']
    values = [avg_detection, avg_quarantine, avg_analysis]
    
    bars = axes[idx].bar(components, values, color=['#3498db', '#9b59b6', '#e67e22'], alpha=0.8, edgecolor='black', linewidth=1.5)
    
    # Add value labels
    for bar in bars:
        height = bar.get_height()
        axes[idx].text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.2f}ms',
                ha='center', va='bottom', fontsize=10, fontweight='bold')
    
    axes[idx].set_ylabel('Latency (ms)', fontsize=11, fontweight='bold')
    axes[idx].set_title(f'{scan_type} Scan', fontsize=12, fontweight='bold')
    axes[idx].grid(axis='y', alpha=0.3)

plt.tight_layout()
plt.savefig('05_latency_breakdown.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 05_latency_breakdown.png\n")
plt.close()

# ============================================================================
# SUMMARY STATISTICS TABLE (for research paper)
# ============================================================================
print("\n" + "="*80)
print("SUMMARY STATISTICS FOR RESEARCH PAPER")
print("="*80)

summary_data = []
for scan_type, df in data.items():
    summary_data.append({
        'Scan Type': scan_type,
        'Test Files': len(df),
        'Avg Response Time (ms)': f"{df['TotalResponseTimeMs'].mean():.2f}",
        'Min Response Time (ms)': f"{df['TotalResponseTimeMs'].min()}",
        'Max Response Time (ms)': f"{df['TotalResponseTimeMs'].max()}",
        'Std Dev (ms)': f"{df['TotalResponseTimeMs'].std():.2f}",
        'Avg Risk Score': f"{df['RiskScore'].mean():.2f}"
    })

summary_df = pd.DataFrame(summary_data)
print(summary_df.to_string(index=False))

# ============================================================================
# SCAN COVERAGE AND SPEED TABLE (for your report section)
# ============================================================================
print("\n" + "="*80)
print("SCAN COVERAGE AND SPEED (for your report)")
print("="*80)
print("\nUse this format for your research paper:\n")

coverage_data = []
for scan_type, df in data.items():
    files_tested = len(df)
    files_detected = len(df[df['RiskScore'] > 0])  # Files with risk score > 0
    avg_response_ms = df['TotalResponseTimeMs'].mean()
    avg_response_s = avg_response_ms / 1000
    
    # Calculate detection percentage
    detection_rate = (files_detected / files_tested * 100) if files_tested > 0 else 0
    
    coverage_data.append({
        'Scan Type': scan_type,
        'Test Files': files_tested,
        'Files Detected': files_detected,
        'Detection Rate': f"{detection_rate:.1f}%",
        'Avg Response Time': f"{avg_response_ms:.2f}ms ({avg_response_s:.3f}s)"
    })
    
    print(f"  {scan_type.upper()} SCAN:")
    print(f"    • Tested {files_tested} sample .wsb files")
    print(f"    • Detected {files_detected} malicious threats")
    print(f"    • Detection rate: {detection_rate:.1f}%")
    print(f"    • Average response time: {avg_response_ms:.2f}ms ({avg_response_s:.3f}s)")
    print()

coverage_df = pd.DataFrame(coverage_data)
print("\nSummary Table:")
print(coverage_df.to_string(index=False))

# ============================================================================
# KEY FINDINGS & CALCULATIONS
# ============================================================================
print("\n" + "="*80)
print("KEY FINDINGS FOR YOUR RESEARCH PAPER")
print("="*80)

shallow_time = response_times['Shallow']
medium_time = response_times['Medium']
deep_time = response_times['Deep']

shallow_detections = detection_counts['Shallow']
medium_detections = detection_counts['Medium']
deep_detections = detection_counts['Deep']

print(f"\n1. SPEED IMPROVEMENTS:")
print(f"   • Shallow vs Medium: {((medium_time - shallow_time) / shallow_time * 100):.1f}% slower")
print(f"   • Shallow vs Deep:   {((deep_time - shallow_time) / shallow_time * 100):.1f}% slower")
print(f"   • Medium vs Deep:    {((deep_time - medium_time) / medium_time * 100):.1f}% slower")
print(f"   • Deep scan is {(deep_time / shallow_time):.2f}x slower than shallow scan")

print(f"\n2. DETECTION EFFICIENCY:")
shallow_per_ms = shallow_detections / shallow_time
medium_per_ms = medium_detections / medium_time
deep_per_ms = deep_detections / deep_time

print(f"   • Shallow: {shallow_per_ms:.2f} detections/ms")
print(f"   • Medium:  {medium_per_ms:.2f} detections/ms")
print(f"   • Deep:    {deep_per_ms:.2f} detections/ms")

print(f"\n3. DETECTION COVERAGE:")
shallow_pct = (shallow_detections / deep_detections * 100)
medium_pct = (medium_detections / deep_detections * 100)
print(f"   • Shallow captures {shallow_pct:.1f}% of threats found by deep scan")
print(f"   • Medium captures {medium_pct:.1f}% of threats found by deep scan")
print(f"   • Deep scan finds only {deep_detections - shallow_detections} additional threats ({100 - shallow_pct:.1f}% more)")

print(f"\n4. COST-BENEFIT ANALYSIS:")
speed_gain = ((deep_time - shallow_time) / deep_time * 100)
threat_loss = (100 - shallow_pct)
print(f"   • Shallow scan is {speed_gain:.1f}% faster")
print(f"   • but misses only {threat_loss:.1f}% of threats")
print(f"   • Speed gain / Threat loss ratio: {speed_gain / threat_loss:.2f}x favorable")

print(f"\n" + "="*80)
print("✓ All visualizations generated successfully!")
print("="*80)
print("\nGenerated files:")
print("  - 01_response_time_comparison.png")
print("  - 02_response_time_distribution.png")
print("  - 03_detection_vs_speed.png")
print("  - 04_file_path_distribution.png")
print("  - 05_latency_breakdown.png")
print("\nUse the 'SCAN COVERAGE AND SPEED' section above for your research paper.")
print("="*80 + "\n")
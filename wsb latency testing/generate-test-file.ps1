param(
    [int]$TrialNumber = 1,
    [string]$TargetDirectory = "$env:USERPROFILE\Downloads",
    [int]$DirectoryDepth = 1,
    [ValidateSet("empty","low","medium","high")]
    [string]$RiskLevel = "low",
    [string]$OutputFile = ""
)

# If no explicit OutputFile provided, use default
if ([string]::IsNullOrWhiteSpace($OutputFile)) {
    $OutputFile = "$TargetDirectory\test-$TrialNumber.wsb"
}

# Create nested directories if needed
if ($DirectoryDepth -gt 1) {
    $nestedPath = $TargetDirectory
    for ($i = 2; $i -lt $DirectoryDepth; $i++) {
        $nestedPath = Join-Path $nestedPath "level$i"
    }
    if (-not (Test-Path $nestedPath)) {
        New-Item -ItemType Directory -Path $nestedPath -Force | Out-Null
    }
    $OutputFile = Join-Path $nestedPath "test-$TrialNumber.wsb"
}

# Create directory if it doesn't exist
$outputDir = Split-Path $OutputFile
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Generate test .wsb file based on risk level
$wsbContent = ""

switch ($RiskLevel) {
    "empty" {
        $wsbContent = "<Configuration></Configuration>"
    }
    "low" {
        $wsbContent = @"
<Configuration>
  <MemoryInMB>2048</MemoryInMB>
</Configuration>
"@
    }
    "medium" {
        $wsbContent = @"
<Configuration>
  <Networking>Enable</Networking>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>C:\Users\Public\WSB_Test</HostFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>cmd.exe /c echo hello</Command>
  </LogonCommand>
  <MemoryInMB>2048</MemoryInMB>
</Configuration>
"@
    }
    "high" {
        $wsbContent = @"
<Configuration>
  <Networking>Enable</Networking>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>C:\Users\Public\WSB_Test</HostFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>C:\WSB_Test\malware.exe</Command>
  </LogonCommand>
  <MemoryInMB>4096</MemoryInMB>
</Configuration>
"@
    }
}

# Write file with timestamp
$creationTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
Set-Content -LiteralPath $OutputFile -Value $wsbContent -Encoding UTF8

return @{
    FilePath = $OutputFile
    CreationTime = $creationTime
    RiskLevel = $RiskLevel
    DirectoryDepth = $DirectoryDepth
    TrialNumber = $TrialNumber
}

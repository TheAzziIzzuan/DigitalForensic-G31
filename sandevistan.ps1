<#
sandevistan.ps1
This is a prototype cli tool that checks for Sysmon's existence, 
writes sysmon-config.xml tailored for Windows Sandbox, generates artifacts + .wsb, produces manifest.json.
Usage:
  # Generate artifacts + wsb in C:\Sandy-Temp\run1
  powershell -ExecutionPolicy Bypass -File .\sandevistan.ps1 generate-wsb -OutDir C:\Sandy-Temp\run1 -CountFiles 6 -Profile medium -Verbose

  # Check sysmon version
  powershell -ExecutionPolicy Bypass -File .\sandevistan.ps1 check-sysmon

  # Create sysmon-config for sandbox (writes file only)
  powershell -ExecutionPolicy Bypass -File .\sandevistan.ps1 make-sysmon-config -OutFile C:\Sandy-Temp\sysmon-config.xml
#>

param(
  [Parameter(Mandatory=$true,Position=0)]
  [ValidateSet("check-sysmon","make-sysmon-config","generate-wsb","install-sysmon-config","run-demo")]
  [string]$Command,

  [string]$OutDir = "$env:USERPROFILE\Desktop\sandevistan_run",
  [int]$CountFiles = 6,
  [ValidateSet("light","medium","heavy")]
  [string]$Profile = "medium",
  [string]$OutFile = "$env:USERPROFILE\Desktop\sysmon-config.xml",
  [switch]$VerboseMode
)


function Write-Log([string]$m){ Write-Host "[Sandevistan] $m" }

function Check-Sysmon {
    $sysmonPath = (Get-Command sysmon.exe -ErrorAction SilentlyContinue).Source
    if (-not $sysmonPath) {
        Write-Log "Sysmon not found in PATH."
        return @{ installed = $false }
    }

    # Run Sysmon with minimal flags to avoid XML spam
    $info = & sysmon.exe -accepteula -nologo -s 2>&1 | Out-String

    # Try multiple patterns for version detection
    $verRegexes = @(
        'Sysmon v\d+(\.\d+)?',
        'System Monitor v\d+(\.\d+)?'
    )

    $verLine = $null
    foreach ($regex in $verRegexes) {
        $match = [regex]::Match($info, $regex)
        if ($match.Success) {
            $verLine = $match.Value
            break
        }
    }

    if ($verLine) {
        Write-Log "Sysmon detected: $verLine"
        return @{
            installed = $true
            version   = $verLine
            path      = $sysmonPath
        }
    }
    else {
        Write-Log "Sysmon detected but version parse failed (output format changed)."
        # Return only the first 10 lines of info
        $shortInfo = ($info -split "`n" | Select-Object -First 10) -join "`n"
        return @{
            installed = $true
            version   = "Unknown"
            info      = $shortInfo
            path      = $sysmonPath
        }
    }
}

function Make-Sysmon-Config {
    param(
        [string]$OutFile = "C:\Sandy-Temp\run1\sysmon-config.xml"
    )

    # Step 1: detect Sysmon version
    $sysmon = Check-Sysmon
    $schemaVersion = "4.90"  # default for recent versions
    if ($sysmon.version -match "v(\d+)\.(\d+)") {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]

        # Map Sysmon versions to schema versions
        switch ($major) {
            13 { $schemaVersion = "4.30" }
            14 { $schemaVersion = "4.40" }
            15 { $schemaVersion = "4.90" }
            default { $schemaVersion = "4.90" }
        }
    }

    Write-Log "Generating Sysmon config for schema version $schemaVersion"

    # Step 2: build config dynamically
    $config = @"
<Sysmon schemaversion="$schemaVersion">
  <HashAlgorithms>sha256</HashAlgorithms>
  <EventFiltering>

    <!-- Process Creation -->
    <ProcessCreate onmatch="include">
      <Image condition="contains">WindowsSandbox.exe</Image>
      <Image condition="contains">wsb.exe</Image>
      <Image condition="contains">WindowsSandboxClient.exe</Image>
      <Image condition="contains">WindowsSandboxServer.exe</Image>
    </ProcessCreate>

    <!-- Network Connections -->
    <NetworkConnect onmatch="include">
      <Image condition="contains">WindowsSandbox</Image>
    </NetworkConnect>

    <!-- File Creation -->
    <FileCreate onmatch="include">
      <TargetFilename condition="end with">.wsb</TargetFilename>
      <TargetFilename condition="end with">.vhdx</TargetFilename>
    </FileCreate>

    <!-- Registry Key Access -->
    <RegistryEvent onmatch="include">
      <TargetObject condition="contains">Sandbox</TargetObject>
    </RegistryEvent>

    <!-- Image Load -->
    <ImageLoad onmatch="include">
      <ImageLoaded condition="contains">WindowsSandbox</ImageLoaded>
    </ImageLoad>

  </EventFiltering>
</Sysmon>
"@

    # Step 3: write config to disk
    try {
        $config | Out-File -FilePath $OutFile -Encoding utf8 -Force
        Write-Log "Sysmon config created successfully at: $OutFile"
        return @{ success = $true; schema = $schemaVersion; path = $OutFile }
    }
    catch {
        Write-Log "Error writing Sysmon config: $_"
        return @{ success = $false; error = $_.Exception.Message }
    }
}


function Generate-WSB {
  param($OutDir, $CountFiles, $Profile)

  # prepare dirs
  if (Test-Path $OutDir) { Remove-Item -Recurse -Force $OutDir }
  New-Item -ItemType Directory -Path $OutDir | Out-Null
  $artifacts = Join-Path $OutDir "artifacts"
  New-Item -ItemType Directory -Path $artifacts | Out-Null

  # helper RNG
  function RandString($n){ -join ((48..57)+(65..90)+(97..122)|Get-Random -Count $n|%{[char]$_}) }

  $manifest = [ordered]@{
    run_id = ("sandevistan-{0}" -f (Get-Date -Format "yyyyMMddTHHmmss"))
    created = (Get-Date).ToString("o")
    profile = $Profile
    artifacts = @()
  }

  for ($i=0; $i -lt $CountFiles; $i++) {
    $name = ("{0}_{1}.txt" -f (RandString 6), (Get-Random -Minimum 1000 -Maximum 9999))
    $path = Join-Path $artifacts $name
    $content = @(
      "HONEYFILE: $name",
      "Created: $(Get-Date -Format o)",
      "GUID: $(New-Guid)",
      "Note: Sandbox bait"
    ) -join "`r`n"
    Set-Content -LiteralPath $path -Value $content -Encoding UTF8
    $sha = (Get-FileHash -Path $path -Algorithm SHA256).Hash
    $manifest.artifacts += @{path=$path; sha256=$sha; action="read"}
  }

  # bait registry file
  $regPath = Join-Path $artifacts "bait_setting.reg"
  $regContent = @"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\SandevistanBait]
"Timestamp"="$(Get-Date -Format s)"
"ID"="$(New-Guid)"
"@
  Set-Content -LiteralPath $regPath -Value $regContent -Encoding ASCII
  $manifest.artifacts += @{path=$regPath; sha256=(Get-FileHash $regPath -Algorithm SHA256).Hash; action="reg_import"}

  # startup script
  $startupBat = Join-Path $artifacts "startup.bat"
  $firstFile = (Get-ChildItem $artifacts -File | Where-Object { $_.Name -ne "bait_setting.reg" -and $_.Name -ne "startup.bat" } | Select-Object -First 1).Name
  $bat = @"
@echo off
echo Sandevistan startup running...
type "%~dp0\$firstFile" > "%USERPROFILE%\Desktop\sandbox_honey_preview.txt"
regedit /s "%~dp0\bait_setting.reg" > "%USERPROFILE%\Desktop\sandbox_reg_import_log.txt" 2>&1
timeout /t 2 > nul
"@
  Set-Content -LiteralPath $startupBat -Value $bat -Encoding ASCII
  $manifest.artifacts += @{path=$startupBat; sha256=(Get-FileHash $startupBat -Algorithm SHA256).Hash; action="run"}

  # create .wsb
  $absArtifacts = (Get-Item $artifacts).FullName
  $wsbPath = Join-Path $OutDir "SandevistanRandom.wsb"
  $wsbXml = @"
<Configuration>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$absArtifacts</HostFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>cmd.exe /c %USERPROFILE%\Desktop\startup.bat</Command>
  </LogonCommand>
</Configuration>
"@
  Set-Content -LiteralPath $wsbPath -Value $wsbXml -Encoding UTF8
  $manifest.wsb = $wsbPath

  $manifestJson = $manifest | ConvertTo-Json -Depth 5
  $manifestPath = Join-Path $OutDir "manifest.json"
  Set-Content -LiteralPath $manifestPath -Value $manifestJson -Encoding UTF8

  Write-Log "Generated artifacts in $OutDir"
  Write-Log "WSB: $wsbPath"
  Write-Log "Manifest: $manifestPath"
  return @{out=$OutDir; wsb=$wsbPath; manifest=$manifestPath}
}

function Install-Sysmon-Config {
  param($ConfigPath)
  # Requires Administrator
  if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Log "ERROR: install-sysmon-config requires Administrator. Re-run PowerShell as Admin."
    return $false
  }
  $sysmon = (Get-Command sysmon.exe -ErrorAction SilentlyContinue).Source
  if (-not $sysmon) { Write-Log "ERROR: sysmon.exe not found in PATH."; return $false }
  Write-Log "Applying Sysmon config via sysmon -c `"$ConfigPath`""
  & sysmon.exe -c $ConfigPath 2>&1 | ForEach-Object { Write-Log $_ }
  return $true
}

### Dispatch ###
switch ($Command) {
  "check-sysmon" {
    $r=Check-Sysmon
    $r | ConvertTo-Json
    break
  }
  "make-sysmon-config" {
    Make-Sysmon-Config -File $OutFile
    break
  }
  "generate-wsb" {
    $res = Generate-WSB -OutDir $OutDir -CountFiles $CountFiles -Profile $Profile
    $res | ConvertTo-Json -Depth 5
    break
  }
  "install-sysmon-config" {
    $cfg = Make-Sysmon-Config -File $OutFile
    Install-Sysmon-Config -ConfigPath $cfg
    break
  }
  "run-demo" {
    $r = Generate-WSB -OutDir $OutDir -CountFiles $CountFiles -Profile $Profile
    Start-Process $r.wsb
    break
  }
}

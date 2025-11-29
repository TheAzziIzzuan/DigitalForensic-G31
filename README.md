# Sandevistan – Windows Sandbox Sysmon & Honeyfile Generator

`Sandevistan` is a prototype PowerShell CLI tool that:

- Detects Sysmon installation and version  
- Generates a Sysmon configuration XML tailored for Windows Sandbox  
- Produces honeyfile artifacts, a `.wsb` Windows Sandbox configuration file, and a `manifest.json`  
- Optionally installs the generated Sysmon configuration into Sysmon  
- Can automatically launch a Sandbox demo environment  

All functionality is contained in a single script: `sandevistan.ps1`.

---

## Prerequisites

- Windows 10/11 (Sandbox available on Pro/Enterprise)  
- Windows PowerShell 5.x or later  
- Windows Sandbox enabled (required for `.wsb` execution)  
- Sysmon installed and available in `PATH`  
- Administrator rights (only required for `install-sysmon-config`)

---

## Basic Usage

All commands follow this format:

```powershell
powershell -ExecutionPolicy Bypass -File .\sandevistan.ps1 <command> [options]
``` 

---

## Example Workflows
### Quick Sysmon Check 
```powershell
powershell -ExecutionPolicy Bypass -File .\sandevistan.ps1 check-sysmon
```

### Generate Sysmon Config Only
```powershell
powershell -ExecutionPolicy Bypass -File .\sandevistan.ps1 make-sysmon-config -OutFile C:\Temp\sysmon.xml
```

### Generate Full Sandbox Environment
```powershell
powershell -ExecutionPolicy Bypass -File .\sandevistan.ps1 generate-wsb `
  -OutDir C:\Sandy-Temp\run1 `
  -CountFiles 10 `
  -Profile heavy
```
Then launch the sandbox manually: 

```powershell
Start-Process "C:\Sandy-Temp\run1\SandevistanRandom.wsb"
```

## wsb-hunter usage

### Create first .wsb file
First, create a test .wsb file to demonstrate wsb-hunter's initial scan detection
```powershell
echo "<Configuration></Configuration>" > C:\Users\seanl\Downloads\rogue.wsb
```

For the above command, and all commands below, adjust the path of rogue.wsb as needed.
Testing must be done under one of these paths:

- `C:\Users\[Your User]\`
- `C:\Users\Public\`
- `C:\Users\[Your User]\AppData\Local\Temp\`
  

### Running wsb-hunter
```powershell
powershell -ExecutionPolicy Bypass -File wsb-hunter.ps1
```


### Initial scan
After running and waiting for a short while, you will encounter something like:

- `\======== WSB RISK ANALYSIS ========\`
- `\File: C:\WSB_Quarantine\rogue.wsb\`
- `\Risk Score: 0\`
- `\Details:\`

- `\Delete this quarantined file? [y/N]:\`

You can choose to delete the quarantined file, or keep it in quarantine.


### Testing real-time detection
Run the same line of code that generates rogue.wsb again on another Powershell terminal.
```powershell
echo "<Configuration></Configuration>" > C:\Users\seanl\Downloads\rogue.wsb
```

After a short while, you should reencounter the same analysis result as above.


### Testing risk-level capability
Note how rogue.wsb gave a Risk Score of 0, since it is empty.

On your second Powershell terminal, type:
```powershell
@"
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
"@ > C:\Users\seanl\Downloads\mediumrisk.wsb
```
A new analysis result will appear on the first Powershell screen, returning a Risk Score of 80 and explaining the rationale behind the score.

Next, try:
```powershell
@"
<Configuration>
  <Networking>Enable</Networking>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>C:\Users\Public\WSB_Test</HostFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>C:\WSB_Test\start.bat</Command>
  </LogonCommand>
  <MemoryInMB>2048</MemoryInMB>
</Configuration>
"@ > C:\Users\seanl\Downloads\highrisk.wsb
```
A new analysis result will appear on the first Powershell screen, returning a Risk Score of 135 and explaining the rationale behind the score.



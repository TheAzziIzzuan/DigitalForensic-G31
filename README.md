# Sandevistan – Host-Side Sandbox Abuse Detection and Telemetry Analysis System


`Sandevistan` is a prototype PowerShell CLI tool, with two different parts split between `wsb-hunter.ps1` and `sandevistan.ps1` :

### wsb-hunter.ps1
- Performs a hunt for .wsb files in directories commonly exploited by APTs, that may potentially be malicious
- Examine configuration contents of each identified .wsb file and gives the user a risk score
- Detects configurations that could potentially be misused, such as writable folder mappings, networking enablement, and auto-execution commands
- Offers a list of action for user to undertake for each identified .wsb: ignore, quarantine with integrity preservation, or delete
- Generates a log file in the quarantine folder that records all actions taken during its execution

### sandevistan.ps1
- Detects Sysmon installation and version  
- Generates a Sysmon configuration XML tailored for Windows Sandbox  
- Produces honeyfile artifacts, a `.wsb` Windows Sandbox configuration file, and a `manifest.json`  
- Optionally installs the generated Sysmon configuration into Sysmon  
- Can automatically launch a Sandbox demo environment


---

## Prerequisites

- Windows 10/11 (Sandbox available on Pro/Enterprise)  
- Windows PowerShell 5.x or later  
- Windows Sandbox enabled (required for `.wsb` execution)  
- Sysmon installed and available in `PATH`  
- Administrator rights (only required for `install-sysmon-config`)

---
# USER MANUAL 

## wsb-hunter.ps1 usage

- Navigate to the folder that contains wsb-hunter.ps1 to execute the following commands

### Running wsb-hunter
```powershell
powershell -ExecutionPolicy Bypass -File wsb-hunter.ps1
```

### Create a harm .wsb file for testing
First, create a test .wsb file to demonstrate wsb-hunter's initial scan detection
```powershell
echo "<Configuration></Configuration>" > "$env:USERPROFILE\Downloads\harmless.wsb"
```
Downloads is one of the default directories the hunter monitors. These are all the directories it monitors by default, so test .wsb files can be inserted into any one of these:

- `C:\Users\$env:USERPROFILE\`
- `C:\Users\Public\`
- `C:\Users\$env:USERPROFILE\AppData\Local\Temp\`
  
### Initial scan
After running and waiting for a short while, you will encounter this:

- `======== WSB RISK ANALYSIS ========`
- `Path: C:\$env:USERPROFILE\Downloads\harmless.wsb`
- `SHA256 hash: [hash]`
- `Risk Score: 0`
- `Details:`

- `[A] Allow (leave it)`
- `[Q] Quarantine it`
- `[D] Delete immediately`

If you so happen to have your own, other .wsb files on your system that are identified, their risk analysis may pop up first before harmless.wsb's risk analysis, as identified .wsb files appear one by one. Just input 'A' to leave these .wsb files alone

- The user can choose one of three options, depending on what letter they input:
- A: Leave the .wsb as is. If they know for a fact it is harmless, for example
- Q: Sends the .wsb file to a quarantine folder, WSB_Quarantine, located on the C drive
- D: Completely removes the .wsb file


### Real-time detection
The hunter is also capable of detecting .wsb files that are newly introduced while it is running. You can try this by creating a new .wsb file while it is running on a second Powershell terminal, like so:
```powershell
echo "<Configuration></Configuration>" > C:\Users\$env:USERPROFILE\Downloads\harmless2.wsb
```

After a short while, you should reencounter the same analysis result as above.


### Risk-level capability
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
"@ > C:\Users\$env:USERPROFILE\Downloads\mediumrisk.wsb
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
"@ > C:\Users\$env:USERPROFILE\Downloads\highrisk.wsb
```

A new analysis result will appear on the first Powershell screen, returning a Risk Score of 135 and explaining the rationale behind the score.

You can try the various other test cases we have in our test-cases folder in the repository.


### Quarantine folder
The quarantine folder is located at C:\WSB_Quarantine. All quarantined files are relocated here

### Log file
The log file is also placed into the quarantine folder, containing logs of all the events that occur in the hunter.

## Sysmon Visibility
  
### Basic Usage
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

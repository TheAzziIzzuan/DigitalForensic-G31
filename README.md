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


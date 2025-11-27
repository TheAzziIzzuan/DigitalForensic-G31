# DigitalForensic-G31

### Sandevistan: Windows Sandbox Detection Validation Toolkit

Sandevistan is a two-part detection validation toolkit composed of a Sandbox Simulation Engine (done through powershell) that generates malicious-like activity inside Windows Sandbox, and a tailored host-side Sysmon configuration that captures and forwards all Sandbox-originated telemetry to a SIEM for detection testing.

This toolkit includes:
- yyy.ps1: The Sandbox Simulation Engine. This
      - Launches Windows Sandbox automatically
      - Deploy deception artifacts
      - Trigger malicious-like activity
- sysmon-config.xml: A Host-Side Observability Engine
      - A sysmon configuration that enables detection on the "infected" host machine"
- Wazuh rules: to validate the sysmon alerts on SIEM platform (!! this part i not sure, to double check)

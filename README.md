# Puya‑32 Development Environment Setup

A PowerShell-based setup script for configuring a development environment targeting Puya PY32 series microcontrollers (ARM Cortex‑M0).

What this script does:
- Installs (or verifies) Chocolatey package manager
- Installs make, curl, and ARM GCC (arm-none-eabi-gcc)
- Downloads and runs the SEGGER J-Link installer (auto-detects x86_64 vs ARM64)
- Creates JLinkDevices\Puya\PY32 in your roaming profile and copies files there
- Adds the newest "C:\Program Files\SEGGER\JLink_*" folder to the System PATH

## Installation

Clone the repository:
```bash
git clone https://github.com/paulscalise1/puya-32-environment-setup.git
cd puya-32-environment-setup
```

## Usage

Prior to running the script, adjust the parameters in ```./PY32/Devices.xml``` to suit your working PUYA32 target.
By default, ```./PY32/Devices.xml``` is loaded with values for the ```py32f030x8```.

Run the setup script as administrator in Powershell:
```bash
.\py32-env-setup.ps1 --AcceptSEGGERLicense
```
If your system does not allow scripts to run, bypass the protection by running the script with:
```bash
powershell -NoProfile -ExecutionPolicy Bypass -File ".\py32-env-setup.ps1" --AcceptSEGGERLicense
```
Once finished, restart your terminal sessions for the new system PATH to be recognized.

# Puya‑32 Development Environment Setup

A PowerShell-based setup script for configuring a development environment targeting Puya PY32 series microcontrollers (ARM Cortex‑M0).

    Features
	•	Automated setup for GNU Arm Embedded Toolchain, CMake, JLink Device Details
	•	Scripts to configure VS Code devcontainer or local setup
	•	Enables building, flashing, and debugging toolchains for PY32 projects

    Prerequisites
	•	Windows (PowerShell)
	•	Puya PY32 dev board (e.g. PY32F002A)
	•	SWD debug probe (DAPLink / J-Link)

## Installation

Clone the repository:
```bash
git clone https://github.com/paulscalise1/puya-32-environment-setup.git
cd puya-32-environment-setup
```

Run the setup script as administrator in Powershell:
```bash
sudo .\py32-env-setup.ps1
```

param (
    [switch]$AcceptSEGGERLicense
)

$architecture = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'ARM' } else { 'x86' }

$x86_JLink          = "JLink_Windows_x86_64.exe"
$arm64_JLink        = "JLink_Windows_arm64.exe"

$downloads         = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
$segger_DL_Path    = Join-Path $downloads 'SEGGER'
$x86programPath    = Join-Path $segger_DL_Path $x86_JLink
$arm64programPath  = Join-Path $segger_DL_Path $arm64_JLink

# Must be admin for system-wide installs and PATH changes
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "Script is not running as administrator. Please run as admin."
    exit
}

if (-not $AcceptSEGGERLicense) {
    Write-Host "Please accept the SEGGER License to download the software. Add --AcceptSEGGERLicense in the command line."
    exit
}

# Chocolatey install (if missing), then deps
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "Chocolatey is already installed. Version: $(choco --version)"
} else {
    Write-Host "Chocolatey is not installed. Installing now..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    Start-Sleep -Seconds 5
    # Refresh this session's PATH so choco is available immediately
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path','User')
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "Chocolatey installed successfully. Version: $(choco --version)"
    } else {
        Write-Host "Chocolatey installation failed."
    }
}

# Dependencies
if (Get-Command make -ErrorAction SilentlyContinue) {
    Write-Host "Make is installed."
} else {
    Write-Host "Installing Make..."
    choco install make -y
}

if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    Write-Host "Curl is installed."
} else {
    Write-Host "Installing Curl..."
    choco install curl -y
}

if (Get-Command arm-none-eabi-gcc -ErrorAction SilentlyContinue) {
    Write-Host "ARM GCC Tools are installed."
} else {
    Write-Host "Installing ARM GCC Tools..."
    choco install gcc-arm-embedded -y
}

# SEGGER J-Link install (only if V8+ not present)
$existingJLink = Get-ChildItem "C:\Program Files\SEGGER" -Directory -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -like 'JLink_V8*' }

if (-not $existingJLink) {
    New-Item -Path $segger_DL_Path -ItemType Directory -Force | Out-Null
    Write-Host "Downloading latest SEGGER J-Link Tools. This may take a minute..."

    if ($architecture -eq 'x86') {
        $downloadTarget = $x86programPath
        $downloadUrl    = 'https://www.segger.com/downloads/jlink/JLink_Windows_x86_64.exe'
    } else {
        $downloadTarget = $arm64programPath
        $downloadUrl    = 'https://www.segger.com/downloads/jlink/JLink_Windows_arm64.exe'
    }

    $verboseOutput = curl.exe -L -v -d "accept_license_agreement=accepted&submit=Download+software" `
        $downloadUrl -o $downloadTarget 2>&1

    $httpCodes = $verboseOutput | Select-String -Pattern 'HTTP/.*\s(\d{3})' | ForEach-Object {
        if ($_ -match 'HTTP/.*\s(\d{3})') { $matches[1] }
    }
    $httpCode = $httpCodes | Select-Object -Last 1

    if ($httpCode -eq '200' -and (Test-Path $downloadTarget)) {
        Write-Host "J-Link software download successful (HTTP Status Code: $httpCode)"
        Write-Host "Opening J-Link installer... Continue with the install wizard."
        Start-Process -FilePath $downloadTarget -Wait
    } else {
        Write-Host "Download failed (HTTP Status Code: $httpCode). Run the script again."
        exit 1
    }
} else {
    Write-Host "J-Link tools V8+ already installed."
}

# Ensure JLinkDevices directory structure exists
$jlinkDevices   = Join-Path $env:USERPROFILE 'AppData\Roaming\SEGGER\JLinkDevices'
$puyadir        = Join-Path $jlinkDevices 'Puya'
$fullPuyaPath   = Join-Path $puyadir 'PY32'

if (-not (Test-Path $jlinkDevices)) {
    New-Item -Path $jlinkDevices -ItemType Directory -Force | Out-Null
    Write-Host "Creating JLinkDevices directory."
} else {
    Write-Host "JLinkDevices directory exists."
}

if (-not (Test-Path $puyadir))   { New-Item -Path $puyadir -ItemType Directory -Force   | Out-Null }
if (-not (Test-Path $fullPuyaPath)) { New-Item -Path $fullPuyaPath -ItemType Directory -Force | Out-Null }

# Copy flash algorithm files & JLinkDevices.xml to PY32 folder
$scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$sourceDirectory = Join-Path $scriptDirectory 'PY32'
if (Test-Path $sourceDirectory) {
    Copy-Item -Path (Join-Path $sourceDirectory '*') -Destination $fullPuyaPath -Recurse -Force
} else {
    Write-Warning "Source directory '$sourceDirectory' not found; skipping file copy."
}

# Add newest SEGGER J-Link bin dir to System PATH (idempotent)
$latestSeggerVersionPath = (
    Get-ChildItem "C:\Program Files\SEGGER" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'JLink*' } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
).FullName

if (-not $latestSeggerVersionPath) {
    Write-Warning "Could not locate a SEGGER J-Link folder under 'C:\Program Files\SEGGER'."
} else {
    $machinePath = [Environment]::GetEnvironmentVariable('Path','Machine')
    $pathEntries = $machinePath -split ';' | Where-Object { $_ -and $_.Trim() -ne '' }

    $normalized  = $pathEntries | ForEach-Object { $_.Trim().TrimEnd('\').ToLowerInvariant() }
    $targetNorm  = $latestSeggerVersionPath.TrimEnd('\').ToLowerInvariant()

    if ($normalized -notcontains $targetNorm) {
        $newMachinePath = ($pathEntries + $latestSeggerVersionPath) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $newMachinePath, 'Machine')

        # Refresh current session PATH so it's usable immediately here
        $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                    [Environment]::GetEnvironmentVariable('Path','User')

        Write-Host "Added $latestSeggerVersionPath to the System PATH."
    } else {
        Write-Host "SEGGER J-Link path already present in System PATH."
    }
}

Write-Host "`nIf there are no errors, setup is complete. Open (or restart if already open) VS Code.`n"

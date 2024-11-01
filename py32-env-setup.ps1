param (
    [switch]$AcceptSEGGERLicense
)

$x86_JLink = "JLink_Windows_x86_64.exe"
$downloads = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
$segger_DL_Path = -join($downloads,'\SEGGER\')
$x86programPath = -join($segger_DL_Path, $x86_JLink)

$arm64_JLink = "JLink_Windows_arm64.exe"
$arm64programPath = -join($segger_DL_Path, $arm86_JLink)

$architecture = (Get-CimInstance -ClassName Win32_OperatingSystem).OSArchitecture

if ($architecture -match "64") {
    $architecture = "x86"
} elseif ($architecture -match "ARM") {
    $architecture = "ARM"
}

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "Script is not running as administrator. Please run as admin."
    exit
} else {
    if ($AcceptSEGGERLicense) {
            # Check if Chocolatey is installed
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-Host "Chocolatey is already installed. Version: $(choco --version)"
        } else {
            Write-Host "Chocolatey is not installed. Installing now..."

            # Set execution policy to allow script execution
            Set-ExecutionPolicy Bypass -Scope Process -Force

            # Download and install Chocolatey
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

            # Wait for installation to complete
            Start-Sleep -Seconds 5

            # Refresh the environment variable to include the new Chocolatey path
            $env:Path += ";$env:ProgramData\chocolatey\bin"

            # Check if installation was successful
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-Host "Chocolatey installed successfully. Version: $(choco --version)"
            } else {
                Write-Host "Chocolatey installation failed."
            }
        }

        #Check to see if depends are installed, if not, install them
        if (Get-Command make -ErrorAction SilentlyContinue) {
            Write-Host "Make is installed."
        } else {
            Write-Host "Installing Make..."
            choco install make -y
        }

        if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
            Write-Host "Curl is installed"
        } else {
            Write-Host "Installing Curl..."
            choco install curl -y
        }

        if (Get-Command arm-none-eabi-gcc -ErrorAction SilentlyContinue) {
            Write-Host "ARM GCC Tools are installed"
        } else {
            Write-Host "Installing ARM GCC Tools..."
            choco install gcc-arm-embedded -y
        }

        # Check if VSCode is installed
        if (Get-Command code -ErrorAction SilentlyContinue) {
            Write-Host "Visual Studio Code is installed. Version: $(code --version)"
        } else {
            Write-Host "Visual Studio Code is not installed."
            Write-Host "Installing Visual Studio Code.."
            choco install vscode -y

            $vscodePath = "C:\Program Files\Microsoft VS Code\bin"
            if (-Not ($env:PATH -like "*$vscodePath*")) {
                $env:PATH += ";$vscodePath"
            }

            # Check if VSCode is installed correctly and available in the current session
            if (Get-Command code -ErrorAction SilentlyContinue) {
                Write-Host "Visual Studio Code installed successfully. Version: $(code --version)"
            } else {
                Write-Host "Visual Studio Code installation failed or PATH is not set correctly."
            }

            # Check if VSCode is installed correctly and available in the current session
            if (Get-Command code -ErrorAction SilentlyContinue) {
                Write-Host "Visual Studio Code installed successfully. Version: $(code --version)"
            } else {
                Write-Host "Visual Studio Code installation failed or PATH is not set correctly."
                exit 1
            }
        }

        # Check if the Cortex-Debug extension is installed
        $installedExtensions = code --list-extensions
        if ($installedExtensions -like "*marus25.cortex-debug*") {
            Write-Host "Cortex-Debug extension is already installed."
        } else {
            Write-Host "Cortex-Debug extension is not installed. Installing now..."

            # Install the Cortex-Debug extension in VSCode
            code --install-extension marus25.cortex-debug

            # Verify the installation
            $installedExtensions = code --list-extensions
            if ($installedExtensions -like "*marus25.cortex-debug*") {
                Write-Host "Cortex-Debug extension installed successfully."
            } else {
                Write-Host "Failed to install the Cortex-Debug extension."
            }
        }

        # Check to see if Jlink V8+ is installed
        if (!(Test-Path "C:\Program Files\SEGGER\V8*")){
            # Download the updated SEGGER JLink software
            New-Item -Path $segger_DL_Path -ItemType Directory -ErrorAction SilentlyContinue
            Write-Host "Downloading Latest SEGGER JLink Tools..."
            if ($architecture -eq "x86"){
                $statusCode = (curl.exe -d 'accept_license_agreement=accepted&submit=Download+software' https://www.segger.com/downloads/jlink/JLink_Windows_x86_64.exe --output $x86programPath --write-out "%{http_code}")
            } elseif ($architecture -eq "ARM"){
                $statusCode = (curl.exe -d 'accept_license_agreement=accepted&submit=Download+software' https://www.segger.com/downloads/jlink/JLink_Windows_arm64.exe --output $arm64programPath --write-out "%{http_code}")
            }
            if ($statusCode -eq "200") {
                Write-Host "JLink Software Download successful (HTTP Status Code: $statusCode)"
                Write-Host "Opening JLink Installer..."
                Write-Host "Script will continue after the installation of JLink Software is complete... Continue with the install wizard."
                if ($architecture -eq "x86"){
                    Start-Process -FilePath $x86programPath -Wait
                } elseif ($architecture -eq "ARM"){
                    Start-Process -FilePath $arm64programPath -Wait
                }
            } else {
                Write-Host "Download failed (HTTP Status Code: $statusCode). Run the script again."
            }		
        } else {
            Write-Host "JLink tools V8+ already installed."
        }

        # Check if JLinkDevices folder exists
        $jlinkDevices = "$env:USERPROFILE\AppData\Roaming\SEGGER\JLinkDevices"
        if (!(Test-Path $jlinkDevices)){
            New-Item -Path $jlinkDevices -ItemType Directory
            Write-Host "Creating JLinkDevices directory."
        } else {
            Write-Host "JLinkDevices directory exists."
        }

        # Check if Puya parent folder exists
        $puyadir = "$env:USERPROFILE\AppData\Roaming\SEGGER\JLinkDevices\Puya"
        $fullPuyaPath = "$env:USERPROFILE\AppData\Roaming\SEGGER\JLinkDevices\Puya\PY32"
        if (!(Test-Path $puyadir)){
            # Add Puya Parent folder if it does not exist
            New-Item -Path $fullPuyaPath -ItemType Directory
        } else {
            if (!(Test-Path $fullPuyaPath)){
                # Add PY32 family folder
                New-Item -Path $fullPuyaPath -ItemType Directory
            } else {
                Host-Write "\JLinkDevices\Puya\PY32 already exists"
            }
        }

        $scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
        $sourceDirectory = "$scriptDirectory\PY32"

        # Copy the flash algorithm files and JLinkDevices.xml to the PY32 folder.
        Copy-Item -Path "$sourceDirectory\*" -Destination $fullPuyaPath -Recurse -Force

        # Define the SEGGER base directory
        $baseDirectory = "C:\Program Files\SEGGER"

        # Get all subdirectories with version numbers
        $versionDirectories = Get-ChildItem -Path $baseDirectory -Directory | Where-Object { $_.Name -match '^\d+(\.\d+)*$' }

        # Parse and find the directory with the highest version number
        $highestVersionDirectory = $versionDirectories | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1

        if ($highestVersionDirectory) {
            # Output the path of the highest version directory
            $highestVersionPath = $highestVersionDirectory.FullName
            Write-Host "The highest version directory is: $highestVersionPath"

            # Check if the path is already in the system PATH
            $currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    
            if ($currentPath -notlike "*$highestVersionPath*") {
                # Add the path if it's not already present
                [System.Environment]::SetEnvironmentVariable("Path", $currentPath + ";$highestVersionPath", [System.EnvironmentVariableTarget]::Machine)
                Write-Host "Path updated with the highest version directory."
            } else {
                Write-Host "The path is already in the PATH environment variable."
            }
        } else {
            Write-Host "No version directories found in $baseDirectory."
        }

    } else {
        Write-Host "Please accept the SEGGER License to download the software. Add --AcceptSEGGERLicense in the command line."
    }
}
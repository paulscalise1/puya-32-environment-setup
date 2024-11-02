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
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

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


        # Check to see if Jlink V8+ is installed
        if (!(Test-Path "C:\Program Files\SEGGER\V8*")){
            # Download the updated SEGGER JLink software
            New-Item -Path $segger_DL_Path -ItemType Directory -ErrorAction SilentlyContinue
            Write-Host "Downloading Latest SEGGER JLink Tools. This may take a minute..."
            if ($architecture -eq "x86"){
                $verboseOutput = curl.exe -v -d "accept_license_agreement=accepted&submit=Download+software" https://www.segger.com/downloads/jlink/JLink_Windows_x86_64.exe -o $x86programPath 2>&1
	    } elseif ($architecture -eq "ARM"){
                $verboseOutput = curl.exe -v -d "accept_license_agreement=accepted&submit=Download+software" https://www.segger.com/downloads/jlink/JLink_Windows_arm64.exe -o $arm64programPath 2>&1
            }

	    # Extract the HTTP status code from the verbose output
	    $httpCode = $verboseOutput | Select-String -Pattern "HTTP/.*" | ForEach-Object { 
   	    	if ($_ -match 'HTTP/.* (\d{3}) OK') { 
        		$matches[1] 
    	    	}
	    } | Select-Object -First 1
	    
            if ($httpCode -eq "200") {
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
               
            }
        }

        $scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
        $sourceDirectory = "$scriptDirectory\PY32"

        # Copy the flash algorithm files and JLinkDevices.xml to the PY32 folder.
        Copy-Item -Path "$sourceDirectory\*" -Destination $fullPuyaPath -Recurse -Force

	# Get the path to the recently added SEGGER exe's
        $latestSeggerVersionPath = (Get-ChildItem "C:\Program Files\SEGGER" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName

        $pathExists = $env:Path -split ';' | Where-Object { $_ -eq $latestSeggerVersionPath }

	if ($pathExists) {
    		"SEGGER Binaries already exist in the PATH. No action necessary."
	} else {
    		[Environment]::SetEnvironmentVariable("Path", $env:Path + $latestSeggerVersionPath, [EnvironmentVariableTarget]::Machine)
		Write-Host "Added $atestSeggerVersionPath to the System PATH."
	}
	
	Write-Host "`nIf there are no errors setup is complete. Open (or restart if already open) vscode.`n"

    } else {
        Write-Host "Please accept the SEGGER License to download the software. Add --AcceptSEGGERLicense in the command line."
    }
}

# Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

# Configuration
$FEMR_WSL_DISTRO = "femr-wsl"

# Determine paths based on whether we're testing or installed
if (Test-Path (Join-Path $PSScriptRoot "..\..\common\femr-images.tar")) {
    # Testing: installer\windows\scripts -> go to installer\common
    $IMAGES_TAR = Join-Path $PSScriptRoot "..\..\common\femr-images.tar"
    $COMPOSE_YML = Join-Path $PSScriptRoot "..\..\common\docker-compose.yml"
} else {
    # Installed: all files in same directory (C:\Program Files\fEMR)
    $INSTALL_DIR = Split-Path -Parent $PSScriptRoot
    $IMAGES_TAR = Join-Path $INSTALL_DIR "femr-images.tar"
    $COMPOSE_YML = Join-Path $INSTALL_DIR "docker-compose.yml"
}

function Write-Status {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-WSLInstalled {
    try {
        $wslOutput = wsl --status 2>&1
        return $true
    } catch {
        return $false
    }
}

function Install-WSL {
    Write-Status "Installing WSL..."
    
    # Enable WSL feature if not already enabled
    $wslfeat = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    if ($wslfeat.State -ne "Enabled") {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
        Write-Status "WSL feature enabled. A system restart will be required."
        return $false
    }
    
    # Install WSL
    wsl --install --no-distribution
    
    # Enable WSL2 as default
    wsl --set-default-version 2
    
    return $true
}

function Install-UbuntuDistro {
    Write-Status "Installing Ubuntu distribution..."
    
    # Check if Ubuntu is already installed (handle null characters in WSL output)
    $distros = wsl --list --quiet 2>$null
    $cleanDistros = $distros | ForEach-Object { $_.Trim().Trim([char]0x0000) } | Where-Object { $_ -ne "" }
    
    if ($cleanDistros -contains "Ubuntu") {
        Write-Status "Ubuntu is already installed"
        
        # Make sure it's started and configured
        Write-Status "Starting Ubuntu..."
        wsl -d Ubuntu -u root echo "Ubuntu is ready" 2>&1 | Out-Null
        
        return $true
    }
    
    # Install Ubuntu using official WSL command
    Write-Status "Downloading and installing Ubuntu (this may take a few minutes)..."
    try {
        wsl --install -d Ubuntu --no-launch 2>&1 | Out-Null
    } catch {
        # If it fails because it already exists, that's okay
        if ($LASTEXITCODE -ne 0) {
            $distros = wsl --list --quiet 2>$null
            $cleanDistros = $distros | ForEach-Object { $_.Trim().Trim([char]0x0000) } | Where-Object { $_ -ne "" }
            if (-not ($cleanDistros -contains "Ubuntu")) {
                throw "Ubuntu installation failed: $_"
            }
        }
    }
    
    # Wait for installation to complete
    Start-Sleep -Seconds 5
    
    # Verify installation
    $distros = wsl --list --quiet 2>$null
    $cleanDistros = $distros | ForEach-Object { $_.Trim().Trim([char]0x0000) } | Where-Object { $_ -ne "" }
    
    if (-not ($cleanDistros -contains "Ubuntu")) {
        throw "Ubuntu installation failed - not found in WSL list"
    }
    
    Write-Status "Ubuntu installed successfully"
    return $true
}

function Install-DockerEngine {
    Write-Status "Installing Docker Engine in WSL..."
    
    # Check if Docker is already installed (check for actual docker-ce package, not Docker Desktop)
    $dockerCheck = wsl -d Ubuntu -u root bash -c "dpkg -l | grep docker-ce" 2>$null
    if ($dockerCheck) {
        Write-Status "Docker Engine is already installed"
        
        # Make sure Docker service is running
        Write-Status "Starting Docker service..."
        wsl -d Ubuntu -u root service docker start 2>&1 | Out-Null
        
        return $true
    }
    
    Write-Status "Installing Docker Engine (this will take 5-10 minutes)..."
    Write-Host "  This is a one-time setup. Please be patient..." -ForegroundColor Gray
    
    # Step 1: Update package list and install prerequisites
    Write-Host "  [1/7] Updating package list..." -ForegroundColor Gray
    $output = wsl -d Ubuntu -u root bash -c "export DEBIAN_FRONTEND=noninteractive && apt-get update 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error during apt-get update:" -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
        throw "Failed to update package list"
    }
    
    Write-Host "  [2/7] Installing prerequisites..." -ForegroundColor Gray
    $output = wsl -d Ubuntu -u root bash -c "export DEBIAN_FRONTEND=noninteractive && apt-get install -y ca-certificates curl gnupg 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error installing prerequisites:" -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
        throw "Failed to install prerequisites"
    }
    
    # Step 2: Set up Docker repository
    Write-Host "  [3/7] Setting up Docker repository..." -ForegroundColor Gray
    wsl -d Ubuntu -u root bash -c "install -m 0755 -d /etc/apt/keyrings"
    
    # Get Ubuntu version info for debugging
    $ubuntuVersion = wsl -d Ubuntu -u root bash -c "cat /etc/os-release | grep VERSION_CODENAME"
    Write-Host "    Ubuntu version: $ubuntuVersion" -ForegroundColor Gray
    
    # Download GPG key with better error handling - use wget as fallback
    Write-Host "    Downloading Docker GPG key..." -ForegroundColor Gray
    $output = wsl -d Ubuntu -u root bash -c "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.gpg 2>&1; if [ ! -f /tmp/docker.gpg ]; then wget -q -O /tmp/docker.gpg https://download.docker.com/linux/ubuntu/gpg 2>&1; fi; exit 0"
    
    # Verify the GPG key was downloaded
    $keyCheck = wsl -d Ubuntu -u root bash -c "ls -la /tmp/docker.gpg 2>&1"
    if ($keyCheck -notmatch "docker.gpg") {
        Write-Host "Error: GPG key file not found after download attempt" -ForegroundColor Red
        Write-Host "Download output: $output" -ForegroundColor Red
        Write-Host "File check: $keyCheck" -ForegroundColor Red
        throw "Failed to download Docker GPG key. Please check your internet connection."
    }
    Write-Host "    GPG key downloaded successfully" -ForegroundColor Gray
    
    # Convert and install the GPG key
    Write-Host "    Installing GPG key..." -ForegroundColor Gray
    $output = wsl -d Ubuntu -u root bash -c "gpg --dearmor < /tmp/docker.gpg > /etc/apt/keyrings/docker.gpg 2>&1; chmod a+r /etc/apt/keyrings/docker.gpg; exit 0"
    Write-Host "    GPG key installed successfully" -ForegroundColor Gray
    
    Write-Host "  [4/7] Adding Docker repository..." -ForegroundColor Gray
    # Determine the Ubuntu codename inside WSL and the architecture
    $codename = (wsl -d Ubuntu -u root bash -lc 'source /etc/os-release >/dev/null; echo $VERSION_CODENAME' 2>$null)
    $codename = $codename -replace "\r|\n", ""
    Write-Host "    Detected Ubuntu codename: $codename" -ForegroundColor Gray

    # If we couldn't detect or it's not in the supported list, fall back to a stable LTS (jammy)
    $supported = @('noble','jammy','focal','bionic')
    if (-not $codename -or $supported -notcontains $codename) {
        Write-Host "    Ubuntu codename '$codename' not known/supported; falling back to 'jammy'" -ForegroundColor Yellow
        $codename = 'jammy'
    }

    $arch = (wsl -d Ubuntu -u root bash -lc 'dpkg --print-architecture' 2>$null) -replace "\r|\n", ""
    $repoLine = "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable"
    Write-Host "    Repository line: $repoLine" -ForegroundColor Gray

    # Write the repository file
    wsl -d Ubuntu -u root bash -c "echo '$repoLine' > /etc/apt/sources.list.d/docker.list"

    # Verify the repository file was created and show contents
    $repoCheck = wsl -d Ubuntu -u root bash -c "cat /etc/apt/sources.list.d/docker.list 2>&1"
    if (-not $repoCheck) {
        Write-Host "Docker repository file was not created. Last output: $repoLine" -ForegroundColor Red
        throw "Docker repository file was not created"
    }
    Write-Host "    Repository file contents: $repoCheck" -ForegroundColor Gray
    
    # Step 3: Update package list with Docker repository
    Write-Host "  [5/7] Updating package list with Docker repository..." -ForegroundColor Gray
    $output = wsl -d Ubuntu -u root bash -c "apt-get update 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error updating package list:" -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
        throw "Failed to update package list after adding Docker repository"
    }
    
    # Step 4: Install Docker
    Write-Host "  [6/7] Installing Docker (this is the longest step)..." -ForegroundColor Gray
    $output = wsl -d Ubuntu -u root bash -c "export DEBIAN_FRONTEND=noninteractive && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error installing Docker:" -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
        throw "Failed to install Docker Engine"
    }
    
    # Step 5: Start Docker service
    Write-Host "  [7/7] Starting Docker service..." -ForegroundColor Gray
    $output = wsl -d Ubuntu -u root bash -c "service docker start 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error starting Docker:" -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
        throw "Failed to start Docker service"
    }
    
    # Verify Docker is working
    Write-Host "  Verifying Docker installation..." -ForegroundColor Gray
    $output = wsl -d Ubuntu -u root bash -c "docker --version 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker installation verification failed:" -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
        throw "Docker installed but not working properly"
    }
    
    Write-Status "Docker Engine installed successfully"
    Write-Host "  Docker version: $output" -ForegroundColor Green
}

function Import-DockerImages {
    Write-Status "Importing fEMR Docker images (this may take 2-3 minutes)..."
    
    if (-not (Test-Path $IMAGES_TAR)) {
        throw "Docker images file not found: $IMAGES_TAR"
    }
    
    # Convert Windows path to WSL path (C:\Path\file -> /mnt/c/path/file)
    $resolvedPath = (Resolve-Path $IMAGES_TAR).Path
    
    # Get drive letter and convert to lowercase
    $driveLetter = $resolvedPath.Substring(0, 1).ToLower()
    # Get path without drive and colon
    $pathWithoutDrive = $resolvedPath.Substring(2)
    # Convert backslashes to forward slashes
    $unixPath = $pathWithoutDrive -replace '\\', '/'
    # Build final WSL path
    $wslPath = "/mnt/$driveLetter$unixPath"
    
    Write-Status "Loading Docker images directly from Windows filesystem..."
    Write-Status "Path: $wslPath"
    
    # Load images directly from /mnt/c/... path (no copy needed!)
    wsl -d Ubuntu -u root docker load -i $wslPath
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to load Docker images"
    }
    
    Write-Status "Docker images imported successfully"
}

function Install-FemrService {
    Write-Status "Setting up fEMR service..."
    
    # Create fEMR directory in WSL
    wsl -d Ubuntu mkdir -p /opt/femr
    
    # Copy docker-compose.yml
    Get-Content $COMPOSE_YML | wsl -d Ubuntu tee "/opt/femr/docker-compose.yml" > $null
    
    # Create systemd service for fEMR
    $serviceContent = @'
[Unit]
Description=fEMR Application Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
WorkingDirectory=/opt/femr
ExecStart=/usr/bin/docker compose up
ExecStop=/usr/bin/docker compose down
Restart=always

[Install]
WantedBy=multi-user.target
'@
    
    $serviceContent | wsl -d Ubuntu -u root tee "/etc/systemd/system/femr.service" > $null
    
    # Enable and start the service
    wsl -d Ubuntu -u root systemctl enable femr
    wsl -d Ubuntu -u root systemctl start femr
}

# Main installation flow
try {
    Write-Status "Starting fEMR installation..."
    
    if (-not (Test-WSLInstalled)) {
        $wslInstalled = Install-WSL
        if (-not $wslInstalled) {
            Write-Host "Please restart your computer to complete WSL installation, then run this script again."
            exit 0
        }
    }
    
    Install-UbuntuDistro
    Install-DockerEngine
    Import-DockerImages
    Install-FemrService
    
    Write-Host "`nfEMR installation completed successfully!" -ForegroundColor Green
    Write-Host "You can access fEMR at http://localhost:9000"
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
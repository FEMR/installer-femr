# fEMR Launcher - Starts fEMR application without Docker Desktop
# This script uses Docker Engine inside WSL

param(
    [Parameter()]
    [switch]$Stop
)

# Auto-elevate to administrator if not already running as admin
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
    $isAdmin = $false
}

if (-not $isAdmin) {
    try {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($Stop) { $arguments += " -Stop" }
        Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
    } catch {
        Write-Host "Failed to request administrator privileges: $_" -ForegroundColor Red
        Read-Host "Press Enter to exit"
    }
    exit
}

# Now running as administrator
$ErrorActionPreference = "Continue"
try {
    $installDir = Split-Path -Parent $PSCommandPath
} catch {
    Write-Host "Error getting installation directory: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

function Write-Status {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Cyan
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
}

function Wait-ForExit {
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Test-WSLInstalled {
    try {
        wsl --list 2>&1 | Out-Null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Test-UbuntuInstalled {
    try {
        $distros = wsl --list --quiet 2>$null
        # Clean null characters and empty entries from WSL output
        $cleanDistros = $distros | ForEach-Object { $_.Trim().Trim([char]0x0000) } | Where-Object { $_ -ne "" }
        return ($cleanDistros -contains "Ubuntu")
    } catch {
        return $false
    }
}

function Test-DockerInWSL {
    try {
        # Check for docker-ce package (actual Docker Engine, not Docker Desktop)
        $dockerCheck = wsl -d Ubuntu -u root bash -c "dpkg -l | grep docker-ce" 2>$null
        return ($null -ne $dockerCheck -and $dockerCheck.Length -gt 0)
    } catch {
        return $false
    }
}

function Start-FemrService {
    Write-Status "Starting fEMR..."
    
    # Verify WSL is installed
    if (-not (Test-WSLInstalled)) {
        Write-ErrorMsg "WSL is not installed. Please reinstall fEMR."
        Wait-ForExit
        exit 1
    }
    
    # Verify Ubuntu is installed
    if (-not (Test-UbuntuInstalled)) {
        Write-ErrorMsg "Ubuntu is not installed in WSL. Please reinstall fEMR."
        Wait-ForExit
        exit 1
    }
    
    # Verify Docker is installed in WSL
    if (-not (Test-DockerInWSL)) {
        Write-ErrorMsg "Docker is not installed in WSL."
        Write-Host "Running setup to install Docker..." -ForegroundColor Yellow
        $setupScript = Join-Path $installDir "setup.ps1"
        if (Test-Path $setupScript) {
            & $setupScript
        } else {
            Write-ErrorMsg "Setup script not found. Please reinstall fEMR."
            Wait-ForExit
            exit 1
        }
    }
    
    # Stop any Docker Desktop containers that might conflict
    Write-Status "Checking for conflicting containers..."
    try {
        # Check if Docker Desktop is running
        $dockerDesktopRunning = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
        if ($dockerDesktopRunning) {
            Write-Host "Warning: Docker Desktop is running. Stopping conflicting containers..." -ForegroundColor Yellow
            docker stop $(docker ps -q) 2>&1 | Out-Null
        }
    } catch {
        # Docker Desktop not running, that's fine
    }
    
    # Start Docker service in WSL
    Write-Status "Starting Docker service..."
    
    # Try multiple methods to start Docker
    wsl -d Ubuntu -u root service docker start 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        # Try with nohup and dockerd directly
        wsl -d Ubuntu -u root bash -c "nohup dockerd > /var/log/docker.log 2>&1 < /dev/null &" 2>&1 | Out-Null
    }
    
    # Wait for Docker daemon to be ready
    Write-Status "Waiting for Docker daemon to be ready..."
    $maxAttempts = 30
    $attempt = 0
    $dockerReady = $false
    
    while (-not $dockerReady -and $attempt -lt $maxAttempts) {
        $dockerCheck = wsl -d Ubuntu -u root docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            $dockerReady = $true
            Write-Status "Docker daemon is ready"
        } else {
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 1
            $attempt++
        }
    }
    
    if (-not $dockerReady) {
        Write-ErrorMsg "Docker daemon failed to start."
        Write-Host ""
        Write-Host "This can happen if WSL needs to be restarted after Docker installation." -ForegroundColor Yellow
        Write-Host "Please run these commands and try again:" -ForegroundColor Yellow
        Write-Host "  1. wsl --shutdown" -ForegroundColor Cyan
        Write-Host "  2. Wait 5 seconds" -ForegroundColor Cyan  
        Write-Host "  3. Launch fEMR again" -ForegroundColor Cyan
        Wait-ForExit
        exit 1
    }
    
    Write-Host ""
    
    # Check if images are loaded
    Write-Status "Checking Docker images..."
    $images = wsl -d Ubuntu -u root docker images -q
    if ([string]::IsNullOrWhiteSpace($images)) {
        Write-Status "Loading Docker images (first time only, takes 2-3 minutes)..."
        
        # Find images file (testing vs installed)
        $imagesFile = $null
        if (Test-Path (Join-Path $installDir "femr-images.tar")) {
            $imagesFile = Join-Path $installDir "femr-images.tar"
        } elseif (Test-Path (Join-Path $PSScriptRoot "..\..\common\femr-images.tar")) {
            $imagesFile = Join-Path $PSScriptRoot "..\..\common\femr-images.tar"
        }
        
        if ($imagesFile -and (Test-Path $imagesFile)) {
            $resolvedPath = (Resolve-Path $imagesFile).Path
            $driveLetter = $resolvedPath.Substring(0, 1).ToLower()
            $pathWithoutDrive = $resolvedPath.Substring(2)
            $unixPath = $pathWithoutDrive -replace '\\', '/'
            $wslImagePath = "/mnt/$driveLetter$unixPath"
            
            wsl -d Ubuntu -u root docker load -i $wslImagePath
        } else {
            Write-ErrorMsg "Docker images file not found."
            Wait-ForExit
            exit 1
        }
    }
    
    # Find docker-compose.yml (testing vs installed)
    $composeFile = $null
    if (Test-Path (Join-Path $installDir "docker-compose.yml")) {
        $composeFile = Join-Path $installDir "docker-compose.yml"
    } elseif (Test-Path (Join-Path $PSScriptRoot "..\..\common\docker-compose.yml")) {
        $composeFile = Join-Path $PSScriptRoot "..\..\common\docker-compose.yml"
    }
    
    if (-not $composeFile -or -not (Test-Path $composeFile)) {
        Write-ErrorMsg "docker-compose.yml not found."
        Wait-ForExit
        exit 1
    }
    
    # Convert docker-compose.yml path to WSL path
    $resolvedCompose = (Resolve-Path $composeFile).Path
    $driveLetter = $resolvedCompose.Substring(0, 1).ToLower()
    $pathWithoutDrive = $resolvedCompose.Substring(2)
    $unixPath = $pathWithoutDrive -replace '\\', '/'
    $wslComposePath = "/mnt/$driveLetter$unixPath"
    
    # Start containers using -f flag to specify compose file location
    Write-Status "Starting fEMR containers..."
    
    # First, forcefully stop and remove ALL existing containers (not just compose ones)
    Write-Host "  Cleaning up any existing containers..." -ForegroundColor Gray
    wsl -d Ubuntu -u root docker stop $(wsl -d Ubuntu -u root docker ps -aq) 2>&1 | Out-Null
    wsl -d Ubuntu -u root docker rm $(wsl -d Ubuntu -u root docker ps -aq) 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    
    # Now start fresh
    $composeOutput = wsl -d Ubuntu -u root docker compose -f $wslComposePath up -d 2>&1
    
    # Don't rely on exit code - Docker Compose can return non-zero even when containers start
    # Instead, check if containers are actually running
    Start-Sleep -Seconds 3
    
    $runningContainers = wsl -d Ubuntu -u root docker ps --filter "status=running" --format "{{.Names}}" 2>&1
    $dbRunning = $runningContainers -match "db-1"
    $femrRunning = $runningContainers -match "femr-1"
    
    if (-not $dbRunning -or -not $femrRunning) {
        Write-ErrorMsg "Failed to start containers"
        
        # Check for specific error conditions
        if ($composeOutput -match "port is already allocated") {
            Write-Host ""
            Write-Host "Port conflict detected! Another application is using ports 3306 or 9000." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "If you have Docker Desktop running, please:" -ForegroundColor Yellow
            Write-Host "  1. Open Docker Desktop" -ForegroundColor Cyan
            Write-Host "  2. Stop all containers" -ForegroundColor Cyan
            Write-Host "  3. Or run: docker stop `$(docker ps -q)" -ForegroundColor Cyan
            Write-Host "  4. Then launch fEMR again" -ForegroundColor Cyan
        }
        
        Write-Host ""
        Write-Host "Debug info:" -ForegroundColor Yellow
        Write-Host $composeOutput -ForegroundColor Gray
        Write-Host ""
        Write-Host "Running containers:" -ForegroundColor Yellow
        Write-Host $runningContainers -ForegroundColor Gray
        
        Wait-ForExit
        exit 1
    }
    
    Write-Status "Containers started successfully!"
    
    # Wait for fEMR to be ready
    Write-Status "Waiting for fEMR to be ready (this may take a minute)..."
    $maxAttempts = 60
    $attempt = 0
    $ready = $false
    
    while (-not $ready -and $attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:9000" -UseBasicParsing -Method Head -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                $ready = $true
            }
        } catch {
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 2
            $attempt++
        }
    }
    
    Write-Host ""
    
    if ($ready) {
        Write-Status "fEMR is ready!"
        Write-Host ""
        Write-Host "Opening browser to http://localhost:9000" -ForegroundColor Green
        Start-Process "http://localhost:9000"
        Write-Host ""
        Write-Host "fEMR is now running!" -ForegroundColor Green
        Wait-ForExit
    } else {
        Write-Host ""
        Write-Host "fEMR is taking longer than expected." -ForegroundColor Yellow
        Write-Host "Please try accessing: http://localhost:9000" -ForegroundColor Yellow
        Wait-ForExit
    }
}

function Stop-FemrService {
    Write-Status "Stopping fEMR..."
    $wslPath = "/mnt/c/$($installDir -replace '\\','/' -replace 'C:','')".Replace(' ','\ ')
    wsl -d Ubuntu -u root bash -c "cd $wslPath && docker compose down"
    Write-Status "fEMR stopped."
    Wait-ForExit
}

# Main execution
try {
    if ($Stop) {
        Stop-FemrService
    } else {
        Start-FemrService
    }
} catch {
    Write-Host ""
    Write-Host "==================== ERROR ====================" -ForegroundColor Red
    Write-Host "An error occurred while starting fEMR:" -ForegroundColor Red
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please take a screenshot of this error and report it." -ForegroundColor Yellow
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

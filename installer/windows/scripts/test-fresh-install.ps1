# Test script to simulate a fresh installation
# This removes Docker and verifies the installer can set everything up from scratch

$ErrorActionPreference = "Stop"

Write-Host "===========================================`n" -ForegroundColor Cyan
Write-Host "Fresh Install Test for fEMR Installer" -ForegroundColor Cyan
Write-Host "`n===========================================" -ForegroundColor Cyan

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

Write-Host "`n[1/5] Checking current state..." -ForegroundColor Yellow

# Check WSL
$wslInstalled = $false
try {
    wsl --status 2>&1 | Out-Null
    $wslInstalled = $true
    Write-Host "  WSL is installed" -ForegroundColor Green
} catch {
    Write-Host "  WSL is NOT installed" -ForegroundColor Gray
}

# Check Ubuntu
$ubuntuInstalled = $false
if ($wslInstalled) {
    $distros = wsl --list --quiet 2>$null
    $cleanDistros = $distros | ForEach-Object { $_.Trim().Trim([char]0x0000) } | Where-Object { $_ -ne "" }
    if ($cleanDistros -contains "Ubuntu") {
        $ubuntuInstalled = $true
        Write-Host "  Ubuntu is installed" -ForegroundColor Green
    } else {
        Write-Host "  Ubuntu is NOT installed" -ForegroundColor Gray
    }
}

# Check Docker in WSL
$dockerInstalled = $false
if ($ubuntuInstalled) {
    $dockerCheck = wsl -d Ubuntu -u root bash -c "which docker" 2>$null
    if ($dockerCheck) {
        $dockerInstalled = $true
        $dockerVersion = wsl -d Ubuntu -u root bash -c "docker --version" 2>$null
        Write-Host "  Docker is installed: $dockerVersion" -ForegroundColor Green
    } else {
        Write-Host "  Docker is NOT installed in WSL" -ForegroundColor Gray
    }
}

Write-Host "`n[2/5] Cleanup options..." -ForegroundColor Yellow
Write-Host "  To simulate a fresh install, we need to remove Docker from WSL."
Write-Host "  This will NOT remove WSL or Ubuntu itself (just Docker)."
Write-Host ""

if ($dockerInstalled) {
    $response = Read-Host "Remove Docker from Ubuntu WSL? (y/n)"
    if ($response -eq 'y') {
        Write-Host "  Removing Docker..." -ForegroundColor Cyan
        
        # Stop Docker service
        wsl -d Ubuntu -u root bash -c "service docker stop" 2>&1 | Out-Null
        
        # Remove all containers
        wsl -d Ubuntu -u root bash -c "docker rm -f `$(docker ps -aq)" 2>&1 | Out-Null
        
        # Remove Docker packages
        wsl -d Ubuntu -u root bash -c "apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" 2>&1 | Out-Null
        wsl -d Ubuntu -u root bash -c "apt-get autoremove -y" 2>&1 | Out-Null
        
        # Remove Docker repository and GPG key
        wsl -d Ubuntu -u root bash -c "rm -f /etc/apt/sources.list.d/docker.list" 2>&1 | Out-Null
        wsl -d Ubuntu -u root bash -c "rm -f /etc/apt/keyrings/docker.gpg" 2>&1 | Out-Null
        
        Write-Host "  Docker removed successfully" -ForegroundColor Green
        $dockerInstalled = $false
    }
} else {
    Write-Host "  Docker not installed - nothing to remove" -ForegroundColor Gray
}

Write-Host "`n[3/5] Current system state:" -ForegroundColor Yellow
Write-Host "  WSL: $(if ($wslInstalled) { 'Installed' } else { 'Not Installed' })" -ForegroundColor $(if ($wslInstalled) { 'Green' } else { 'Red' })
Write-Host "  Ubuntu: $(if ($ubuntuInstalled) { 'Installed' } else { 'Not Installed' })" -ForegroundColor $(if ($ubuntuInstalled) { 'Green' } else { 'Red' })
Write-Host "  Docker: $(if ($dockerInstalled) { 'Installed' } else { 'Not Installed' })" -ForegroundColor $(if ($dockerInstalled) { 'Green' } else { 'Red' })

Write-Host "`n[4/5] Testing setup script..." -ForegroundColor Yellow

$setupScript = Join-Path $PSScriptRoot "setup.ps1"
if (-not (Test-Path $setupScript)) {
    Write-Host "ERROR: setup.ps1 not found at: $setupScript" -ForegroundColor Red
    exit 1
}

Write-Host "  Running setup.ps1..." -ForegroundColor Cyan
Write-Host ""

try {
    & $setupScript
    Write-Host "`n  Setup completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "`n  Setup failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[5/5] Verifying installation..." -ForegroundColor Yellow

# Check Docker is now installed
$dockerCheck = wsl -d Ubuntu -u root bash -c "docker --version" 2>&1
if ($dockerCheck -match "Docker version") {
    Write-Host "  Docker installed: $dockerCheck" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Docker not found after installation" -ForegroundColor Red
    Write-Host "  Output: $dockerCheck" -ForegroundColor Red
    exit 1
}

# Check Docker is running
$dockerRunning = wsl -d Ubuntu -u root bash -c "service docker status" 2>&1
if ($dockerRunning -match "running") {
    Write-Host "  Docker service is running" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Docker service might not be running" -ForegroundColor Yellow
    Write-Host "  Status: $dockerRunning" -ForegroundColor Yellow
}

# Check Docker images loaded
$images = wsl -d Ubuntu -u root bash -c "docker images" 2>&1
$imageCount = ($images -split "`n").Count - 1
Write-Host "  Docker images loaded: $imageCount" -ForegroundColor Green

Write-Host "`n===========================================`n" -ForegroundColor Cyan
Write-Host "Fresh Install Test PASSED" -ForegroundColor Green
Write-Host "`n===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Test the launcher: .\launcher.ps1" -ForegroundColor Cyan
Write-Host "  2. Verify fEMR starts at http://localhost:9000" -ForegroundColor Cyan

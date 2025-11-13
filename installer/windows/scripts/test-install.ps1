# Test script for fEMR Windows Installation
# Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
$global:TestsFailed = 0
$global:TestsPassed = 0

function Write-TestHeader {
    param([string]$TestName)
    Write-Host ""
    Write-Host "=== Running Test: $TestName ===" -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$ErrorMessage = ""
    )
    
    if ($Success) {
        Write-Host "PASS - $TestName" -ForegroundColor Green
        $global:TestsPassed++
    } else {
        Write-Host "FAIL - $TestName" -ForegroundColor Red
        if ($ErrorMessage) {
            Write-Host "  Error: $ErrorMessage" -ForegroundColor Red
        }
        $global:TestsFailed++
    }
}

function Test-Prerequisites {
    Write-TestHeader "Prerequisites Check"
    
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-TestResult "Admin Privileges" $isAdmin "Script must be run as Administrator"
    
    $psVersion = $PSVersionTable.PSVersion.Major -ge 5
    Write-TestResult "PowerShell Version" $psVersion "PowerShell 5 or higher is required"
    
    $is64Bit = [Environment]::Is64BitOperatingSystem
    Write-TestResult "64-bit Windows" $is64Bit "64-bit Windows is required"
    
    $winVer = [System.Environment]::OSVersion.Version
    $isWin10OrHigher = ($winVer.Major -eq 10 -and $winVer.Build -ge 19041) -or ($winVer.Major -gt 10)
    Write-TestResult "Windows Version" $isWin10OrHigher "Windows 10 version 2004 or higher required"
}

function Test-RequiredFiles {
    Write-TestHeader "Required Files Check"
    
    $requiredFiles = @(
        ".\installer\common\docker-images.sh",
        ".\installer\windows\scripts\setup.ps1",
        ".\installer\windows\scripts\launcher.ps1",
        ".\installer\windows\inno-setup\femr.iss"
    )
    
    foreach ($file in $requiredFiles) {
        $exists = Test-Path $file
        $fileName = Split-Path $file -Leaf
        Write-TestResult "Required File: $fileName" $exists "File not found"
    }
}

function Show-TestSummary {
    Write-Host ""
    Write-Host "=== Test Summary ===" -ForegroundColor Cyan
    Write-Host "Tests Passed: $global:TestsPassed" -ForegroundColor Green
    Write-Host "Tests Failed: $global:TestsFailed" -ForegroundColor Red
    
    if ($global:TestsFailed -eq 0) {
        Write-Host ""
        Write-Host "All tests passed!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Some tests failed." -ForegroundColor Yellow
    }
}

try {
    Write-Host ""
    Write-Host "Starting fEMR Installation Verification Tests" -ForegroundColor Cyan
    Write-Host ""
    
    Test-Prerequisites
    Test-RequiredFiles
    
    Show-TestSummary
    
    if ($global:TestsFailed -gt 0) {
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "Error during test execution" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

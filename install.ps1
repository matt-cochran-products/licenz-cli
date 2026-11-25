# licenz CLI Installer for Windows
#
# Quick install:
#   irm https://raw.githubusercontent.com/matt-cochran-products/licenz-cli/main/install.ps1 | iex
#
# Options (via environment variables):
#   $env:INSTALL_DIR  - Installation directory (default: $env:LOCALAPPDATA\bin)
#   $env:VERSION      - Specific version to install (default: latest)

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

# Configuration
$REPO = "matt-cochran-products/licenz-cli"
$BINARY_NAME = "licenz"

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "info: $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "success: $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "warning: $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "error: $Message" -ForegroundColor Red
    exit 1
}

# Detect architecture
function Get-Architecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64" { return "x86_64" }
        "ARM64" { return "aarch64" }
        default {
            if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
                return "x86_64"
            }
            Write-Error "Unsupported architecture: $arch"
        }
    }
}

# Get target triple
function Get-Target {
    param([string]$Arch)
    return "${Arch}-pc-windows-msvc"
}

# Get latest version from GitHub
function Get-LatestVersion {
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/${REPO}/releases/latest" -MaximumRedirection 10
        $version = $response.tag_name -replace '^v', ''
        return $version
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }

        if ($statusCode -eq 404) {
            try {
                $allReleases = Invoke-RestMethod -Uri "https://api.github.com/repos/${REPO}/releases" -MaximumRedirection 10 -ErrorAction Stop
                if ($allReleases -and $allReleases.Count -gt 0) {
                    $version = $allReleases[0].tag_name -replace '^v', ''
                    Write-Info "Using latest available release: v${version}"
                    return $version
                }
                $noRelease = $true
            }
            catch {
                return $null
            }
        }

        if ($noRelease) {
            Write-Error "no licenz release published yet. See https://github.com/${REPO}/releases, or set `$env:VERSION once one exists."
        }

        if ($statusCode -ne 404) {
            Write-Error "Failed to get latest version: $_"
        }

        return $null
    }
}

# Download file
function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath
    )

    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -MaximumRedirection 10 -ErrorAction Stop
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }

        $errorMessage = if ($statusCode -eq 404) {
            "File not found: $Url`n`nThis usually means the release exists but the Windows build wasn't uploaded."
        }
        else {
            "Failed to download $Url (HTTP $statusCode): $_"
        }

        throw $errorMessage
    }
}

# Verify checksum
function Verify-Checksum {
    param(
        [string]$FilePath,
        [string]$ChecksumFilePath
    )

    $expectedChecksum = Get-Content $ChecksumFilePath -Raw
    $expectedChecksum = ($expectedChecksum -split '\s+')[0].Trim()

    $actualChecksum = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()

    if ($actualChecksum -ne $expectedChecksum) {
        Write-Error "Checksum verification failed! Expected: $expectedChecksum, Got: $actualChecksum"
    }
}

# Setup PATH
function Setup-Path {
    param([string]$InstallDir)

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -split ';' -contains $InstallDir) {
        Write-Info "PATH already configured in Windows environment"
        return
    }

    try {
        $newPath = "$currentPath;$InstallDir"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Success "Added $InstallDir to Windows user PATH"
        Write-Warning "Please restart your terminal for changes to take effect"
    }
    catch {
        Write-Warning "Could not automatically configure PATH: $_"
        Write-Warning "Please add $InstallDir to your PATH manually:"
        Write-Warning "  1. Press Win+R, type 'sysdm.cpl', press Enter"
        Write-Warning "  2. Go to Advanced tab > Environment Variables"
        Write-Warning "  3. Edit User PATH variable"
        Write-Warning "  4. Add: $InstallDir"
    }

    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not (Test-Path $profilePath)) {
        $profileDir = Split-Path $profilePath -Parent
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }

    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    $pathLine = "`$env:PATH += `";$InstallDir`""

    if ($profileContent -notmatch [regex]::Escape($InstallDir)) {
        Add-Content -Path $profilePath -Value "`n# Added by ${BINARY_NAME} installer"
        Add-Content -Path $profilePath -Value $pathLine
        Write-Info "Added $InstallDir to PowerShell profile at $profilePath"
        Write-Info "Run '& `"$profilePath`"' or restart PowerShell to use ${BINARY_NAME} immediately"
    }
    else {
        Write-Info "PATH already configured in PowerShell profile"
    }
}

# Main installation function
function Main {
    Write-Info "Installing ${BINARY_NAME}..."

    $arch = Get-Architecture
    $target = Get-Target -Arch $arch

    Write-Info "Detected platform: windows ($arch)"

    $version = $env:VERSION
    if (-not $version) {
        $version = Get-LatestVersion
    }
    if (-not $version) {
        Write-Error "Failed to determine latest version. Set `$env:VERSION to install a specific version."
    }
    Write-Info "Installing version: v${version}"

    $installDir = $env:INSTALL_DIR
    if (-not $installDir) {
        $installDir = Join-Path $env:LOCALAPPDATA "bin"
    }

    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    $tmpDir = Join-Path $env:TEMP "licenz-install-$(New-Guid)"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    try {
        $archiveName = "${BINARY_NAME}-v${version}-${target}.zip"
        $checksumName = "${archiveName}.sha256"
        $archivePath = Join-Path $tmpDir $archiveName
        $checksumPath = Join-Path $tmpDir $checksumName

        $downloadUrl = "https://github.com/${REPO}/releases/download/v${version}/${archiveName}"
        Write-Info "Downloading from: ${downloadUrl}"
        Download-File -Url $downloadUrl -OutputPath $archivePath

        $checksumUrl = "${downloadUrl}.sha256"
        try {
            Download-File -Url $checksumUrl -OutputPath $checksumPath
        }
        catch {
            Write-Warning "Failed to download checksum file"
        }

        # Verify checksum
        if ((Test-Path $checksumPath)) {
            Write-Info "Verifying checksum..."
            Verify-Checksum -FilePath $archivePath -ChecksumFilePath $checksumPath
            Write-Success "Checksum verified"
        }
        else {
            Write-Warning "Checksum verification skipped (checksum file not available)"
        }

        # Extract archive
        Write-Info "Extracting..."
        $extractPath = Join-Path $tmpDir "extract"
        Expand-Archive -Path $archivePath -DestinationPath $extractPath -Force

        # Install binary
        $binaryName = "${BINARY_NAME}.exe"
        $sourceBinary = Join-Path $extractPath $binaryName
        $destBinary = Join-Path $installDir $binaryName

        if (-not (Test-Path $sourceBinary)) {
            Write-Error "Binary not found in archive: $sourceBinary"
        }

        Copy-Item -Path $sourceBinary -Destination $destBinary -Force
        Write-Success "Installed ${BINARY_NAME} to ${destBinary}"

        # Check if install_dir is in PATH
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $pathArray = $currentPath -split ';'

        if ($pathArray -contains $installDir) {
            Write-Success "$installDir is already in your PATH"
        }
        else {
            Write-Warning "$installDir is not in your PATH"
            Setup-Path -InstallDir $installDir
        }

        # Verify installation
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        if (Get-Command $BINARY_NAME -ErrorAction SilentlyContinue) {
            Write-Success "Installation complete! Run '${BINARY_NAME} --version' to verify."
        }
        else {
            Write-Info "Installation complete! You may need to restart your terminal or run:"
            Write-Info "  `$env:PATH += `";$installDir`""
        }
    }
    finally {
        if (Test-Path $tmpDir) {
            Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Run main
Main

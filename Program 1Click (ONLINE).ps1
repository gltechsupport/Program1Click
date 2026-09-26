# ============================================================
# GL TECH SUPPORT - PROGRAM 1 CLICK
# ============================================================

$ErrorActionPreference = "Stop"
# ============================================================
# FORCE CONSOLE RESIZE & CENTER
# ============================================================

$ConsoleCode = @"
using System;
using System.Runtime.InteropServices;

public class WinConsole {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int nIndex);

    public static void ResizeAndCenter(int width, int height) {
        IntPtr hWnd = GetConsoleWindow();
        if (hWnd == IntPtr.Zero) return;

        int screenWidth = GetSystemMetrics(0);  // SM_CXSCREEN
        int screenHeight = GetSystemMetrics(1); // SM_CYSCREEN

        int x = (screenWidth - width) / 2;
        int y = (screenHeight - height) / 2;

        MoveWindow(hWnd, x, y, width, height, true);
    }
}
"@

try {
    # Set internal buffer and window character height so full menu fits
    $rawUI =$host.UI.RawUI
    $rawUI.BufferSize = New-Object System.Management.Automation.Host.Size(60, 9999)$rawUI.WindowSize = New-Object System.Management.Automation.Host.Size(60, 45)
    
    # Add Win32 class and force dimensions (520px wide x 780px high)
    Add-Type -TypeDefinition $ConsoleCode
    [WinConsole]::ResizeAndCenter(520, 600)
} catch {}

# ============================================================
# CONFIGURATION
# ============================================================

$ConfigUrl = "https://github.com/gltechsupport/Program1Click/raw/refs/heads/main/settings.json"

$ConfigFile = Join-Path$env:TEMP "gltech_settings.json"

# Set target directory in AppData\Roaming\GL-TECH\Program1ClickAIO
$RoamingPath    = [Environment]::GetFolderPath('ApplicationData')
$GlTechFolder   = Join-Path$RoamingPath "GL-TECH"
$DownloadFolder = Join-Path$GlTechFolder "Program1ClickAIO"

# Create download directory structure if it doesn't exist
if (-not (Test-Path $DownloadFolder)) {
    New-Item -ItemType Directory -Path $DownloadFolder -Force | Out-Null
}


# ============================================================
# PAUSE
# ============================================================

function Pause-Menu {

    Write-Host ""
    Read-Host "Press Enter to continue"
}


# ============================================================
# CHECK INTERNET
# ============================================================

function Check-Internet {

    Write-Host ""
    Write-Host "Checking Internet connection..." -ForegroundColor Cyan
    Write-Host ""

    try {

        Invoke-WebRequest `
            -Uri "https://raw.githubusercontent.com/" `
            -Method Head `
            -TimeoutSec 10 `
            -UseBasicParsing `
            -ErrorAction Stop | Out-Null

        Write-Host "Internet connection: OK" -ForegroundColor Green

        return $true
    }
    catch {

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host "                NO INTERNET CONNECTION" -ForegroundColor Red
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "This PC does not have Internet access." -ForegroundColor Yellow
        Write-Host ""

        return $false
    }
}


# ============================================================
# DOWNLOAD SETTINGS.JSON
# ============================================================

function Download-Config {

    Write-Host ""
    Write-Host "Downloading settings.json..." -ForegroundColor Cyan
    Write-Host ""

    try {

        Invoke-WebRequest `
            -Uri $ConfigUrl `
            -OutFile $ConfigFile `
            -UseBasicParsing `
            -TimeoutSec 30 `
            -ErrorAction Stop

        Write-Host "settings.json downloaded." -ForegroundColor Green

        return $true
    }
    catch {

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host "          FAILED TO DOWNLOAD SETTINGS.JSON" -ForegroundColor Red
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Write-Host ""

        return $false
    }
}


# ============================================================
# LOAD JSON
# ============================================================

function Load-Configuration {

    try {

        $JsonText = Get-Content `
            -Path $ConfigFile `
            -Raw `
            -Encoding UTF8

        $Config = $JsonText | ConvertFrom-Json

        return $Config
    }
    catch {

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host "                    INVALID JSON" -ForegroundColor Red
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Write-Host ""

        return $null
    }
}


# ============================================================
# DETECT WINDOWS
# ============================================================

function Get-WindowsVersion {

    try {

        $OS = Get-CimInstance Win32_OperatingSystem

        $Build = [int]$OS.BuildNumber

        if ($Build -ge 22000) {

            return @{
                Name  = "Windows11"
                Build = $Build
            }

        }
        else {

            return @{
                Name  = "Windows10"
                Build = $Build
            }
        }
    }
    catch {

        Write-Host ""
        Write-Host "Unable to determine Windows version." -ForegroundColor Red

        exit 1
    }
}


# ============================================================
# GET FILE NAME
# ============================================================

function Get-DownloadFileName {

    param(
        [string]$Url,
        [string]$SpecifiedFileName
    )

    # If JSON specifies a filename, use it.
    if (-not [string]::IsNullOrWhiteSpace($SpecifiedFileName)) {

        return $SpecifiedFileName
    }

    try {

        $Uri = [System.Uri]$Url

        $FileName = [System.IO.Path]::GetFileName(
            $Uri.AbsolutePath
        )

        if (-not [string]::IsNullOrWhiteSpace($FileName)) {

            return [System.Uri]::UnescapeDataString($FileName)
        }
    }
    catch {
    }

    return "downloaded_file"
}


# ============================================================
# DOWNLOAD APPLICATION
# ============================================================

function Download-Application {

    param(
        [string]$Name,
        [string]$Url,
        [string]$FileName
    )
	
    Clear-Host

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                        DOWNLOAD" -ForegroundColor Magenta
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Application : " -NoNewline -ForegroundColor Gray
    Write-Host "$Name" -ForegroundColor Yellow
    Write-Host ""

    # Determine filename
    $FileName = Get-DownloadFileName `
        -Url $Url `
        -SpecifiedFileName $FileName

    # Prevent a path supplied through JSON from escaping TEMP
    $FileName = [System.IO.Path]::GetFileName($FileName)

    $OutputFile = Join-Path `
        $DownloadFolder `
        $FileName

    Write-Host "File        : " -NoNewline -ForegroundColor Gray
    Write-Host "$FileName" -ForegroundColor White
    Write-Host "Destination : " -NoNewline -ForegroundColor Gray
    Write-Host "$OutputFile" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "Downloading..." -ForegroundColor Cyan
    Write-Host ""

    try {

        # ----------------------------------------------------
        # CURL
        # ----------------------------------------------------

        & curl.exe `
            -L `
            --fail `
            --progress-bar `
            --connect-timeout 15 `
            --retry 2 `
            -o "$OutputFile" `
            "$Url"

        if ($LASTEXITCODE -ne 0) {

            Write-Host ""
            Write-Host "============================================================" -ForegroundColor Red
            Write-Host "                    DOWNLOAD FAILED" -ForegroundColor Red
            Write-Host "============================================================" -ForegroundColor Red
            Write-Host ""

            return
        }

        if (-not (Test-Path $OutputFile)) {

            Write-Host ""
            Write-Host "Download command completed but the file was not found." -ForegroundColor Red

            return
        }

        Write-Host ""
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Green
        Write-Host "                   DOWNLOAD COMPLETE" -ForegroundColor Green
        Write-Host "============================================================" -ForegroundColor Green
        Write-Host ""

        Write-Host "Saved to:" -ForegroundColor Gray
        Write-Host $OutputFile -ForegroundColor Cyan

        Write-Host ""

    }
    catch {

        Write-Host ""
        Write-Host "DOWNLOAD ERROR:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow

        return
    }


    # ========================================================
    # DETERMINE FILE TYPE
    # ========================================================

    $Extension = [System.IO.Path]::GetExtension($OutputFile
    ).ToLowerInvariant()


    # ========================================================
    # EXECUTABLE
    # ========================================================

    if ($Extension -eq ".exe") {

        Write-Host "Starting application..." -ForegroundColor Cyan
        Write-Host ""

        try {

            Start-Process `
                -FilePath $OutputFile

            Write-Host "Application started." -ForegroundColor Green

        }
        catch {

            Write-Host ""
            Write-Host "Unable to start application." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }

        Pause-Menu

        return
    }


    # ========================================================
    # BATCH FILE
    # ========================================================

    if ($Extension -eq ".bat") {

        Write-Host "Starting batch file..." -ForegroundColor Cyan
        Write-Host ""

        try {

            Start-Process `
                -FilePath "cmd.exe" `
                -ArgumentList @(
                    "/c"
                    "`"$OutputFile`""
                )

            Write-Host "Batch file started." -ForegroundColor Green

        }
        catch {

            Write-Host ""
            Write-Host "Unable to start BAT file." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }

        Pause-Menu

        return
    }

    # ========================================================
    # CMD FILE
    # ========================================================

    if ($Extension -eq ".cmd") {

        Write-Host "Starting CMD file..." -ForegroundColor Cyan
        Write-Host ""

        try {

            Start-Process `
                -FilePath "cmd.exe" `
                -ArgumentList @(
                    "/c"
                    "`"$OutputFile`""
                )

            Write-Host "CMD file started." -ForegroundColor Green

        }
        catch {

            Write-Host ""
            Write-Host "Unable to start CMD file." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }

        Pause-Menu

        return
    }


    # ========================================================
    # OTHER FILE
    # ========================================================

    Write-Host "File downloaded successfully." -ForegroundColor Green
    Write-Host ""
    Write-Host "This file type is not automatically executed." -ForegroundColor Yellow
    Write-Host ""

    Pause-Menu
}


# ============================================================
# SUBMENU
# ============================================================

function Show-SubMenu {

    param(
        $Application
    )

    while ($true) {

        Clear-Host

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "                    $($Application.name)" -ForegroundColor Magenta
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""

        # Show submenu items with 10 leading spaces
        foreach ($Property in $Application.submenu.PSObject.Properties) {

            Write-Host "          " -NoNewline
            Write-Host "$($Property.Name)." -NoNewline -ForegroundColor Yellow
            Write-Host " $($Property.Value.name)" -ForegroundColor White
        }


        # Show note
        if (-not [string]::IsNullOrWhiteSpace($Application.note)) {

            Write-Host ""
            Write-Host "Note: $($Application.note)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "          " -NoNewline
        Write-Host "0." -NoNewline -ForegroundColor Red
        Write-Host " Back" -ForegroundColor White

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""

        $Choice = Read-Host "Select an option"


        # Back
        if ($Choice -eq "0") {

            return
        }


        # Find selected submenu item
        $SelectedProperty =
            $Application.submenu.PSObject.Properties |
            Where-Object {
                $_.Name -eq $Choice
            }


        if ($null -eq $SelectedProperty) {

            Write-Host ""
            Write-Host "Invalid selection." -ForegroundColor Red

            Start-Sleep -Seconds 2

            continue
        }


        $SelectedItem = $SelectedProperty.Value


        # Item without URL
        if (
            [string]::IsNullOrWhiteSpace(
                $SelectedItem.url
            )
        ) {

            continue
        }


        # Optional filename
        $FileName = $null

        if ($SelectedItem.PSObject.Properties.Name -contains "filename") {

            $FileName = $SelectedItem.filename
        }


        Download-Application `
            -Name $SelectedItem.name `
            -Url $SelectedItem.url `
            -FileName $FileName
    }
}


# ============================================================
# MAIN MENU
# ============================================================

function Show-MainMenu {

    param(
        $Config,$Windows
    )

    while ($true) {

        Clear-Host

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "                    GL TECH SUPPORT" -ForegroundColor Magenta
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "Operating System : " -NoNewline -ForegroundColor Gray
        Write-Host "$($Windows.Name)" -ForegroundColor Green
        Write-Host "Build            : " -NoNewline -ForegroundColor Gray
        Write-Host "$($Windows.Build)" -ForegroundColor Green

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""


        # Get applications for Windows version
        $Applications =
            $Config.($Windows.Name).applications


        # Display applications with 10 leading spaces
        foreach ($Property in$Applications.PSObject.Properties) {

            Write-Host "          " -NoNewline
            Write-Host "$($Property.Name)." -NoNewline -ForegroundColor Yellow
            Write-Host " $($Property.Value.name)" -ForegroundColor White
        }


        Write-Host ""
        Write-Host "          " -NoNewline
        Write-Host "0." -NoNewline -ForegroundColor Red
        Write-Host " Exit" -ForegroundColor White
        Write-Host ""

        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""


        $Choice = Read-Host "Select an option"


        # Exit
        if ($Choice -eq "0") {

            return
        }


        # Find application
        $SelectedProperty =$Applications.PSObject.Properties |
            Where-Object {
                $_.Name -eq$Choice
            }


        if ($null -eq$SelectedProperty) {

            Write-Host ""
            Write-Host "Invalid selection." -ForegroundColor Red

            Start-Sleep -Seconds 2

            continue
        }


        $Application =$SelectedProperty.Value


        # ====================================================
        # SUBMENU
        # ====================================================

        if ($null -ne$Application.submenu) {

            Show-SubMenu `
                -Application $Application

            continue
        }


        # ====================================================
        # NORMAL APPLICATION
        # ====================================================

        if (
            [string]::IsNullOrWhiteSpace(
                $Application.url
            )
        ) {

            Write-Host ""
            Write-Host "No URL configured for this application." `
                -ForegroundColor Yellow

            Pause-Menu

            continue
        }


        # Optional filename
        $FileName =$null

        if ($Application.PSObject.Properties.Name -contains "filename") {

            $FileName =$Application.filename
        }


        Download-Application `
            -Name $Application.name `
            -Url $Application.url `
            -FileName $FileName
    }
}


# ============================================================
# START PROGRAM
# ============================================================

Clear-Host

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                    GL TECH SUPPORT" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""


# ============================================================
# INTERNET
# ============================================================

if (-not (Check-Internet)) {

    Pause-Menu

    exit
}


# ============================================================
# DOWNLOAD CONFIGURATION
# ============================================================

if (-not (Download-Config)) {

    Pause-Menu

    exit
}


# ============================================================
# LOAD JSON
# ============================================================

$Config = Load-Configuration

if ($null -eq $Config) {

    Pause-Menu

    exit
}


# ============================================================
# WINDOWS DETECTION
# ============================================================

$Windows = Get-WindowsVersion


# ============================================================
# MAIN MENU
# ============================================================

Show-MainMenu `
    -Config $Config `
    -Windows $Windows


# ============================================================
# CLEANUP
# ============================================================

# Remove temporary settings JSON file
Remove-Item `
    -Path $ConfigFile `
    -Force `
    -ErrorAction SilentlyContinue

# Remove Program1ClickAIO download folder and its contents on exit
if (Test-Path $DownloadFolder) {
    Remove-Item `
        -Path $DownloadFolder `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}

Clear-Host

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                    GL TECH SUPPORT" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Goodbye." -ForegroundColor Green
Write-Host ""

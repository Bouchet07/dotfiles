param(
    [switch]$noinstall = $false,
    [switch]$Relaunched = $false
)

<#
.Synopsis
    Modern Windows Post-Install/Setup Script
    Optimized for execution from within the dotfiles repository.
#>

# --- 1. Auto-Elevation to Admin ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "`n 🔑 Requesting Administrator access..." -ForegroundColor Cyan
    
    # Reconstruct the arguments to pass them to the new window
    $passParams = ""
    if ($noinstall) { $passParams += " -noinstall" }
    
    $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
    
    # We add $passParams and -Relaunched to the end of the file path
    Start-Process "wt.exe" -ArgumentList "-w 0 new-tab -p `"PowerShell`" $shell -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $passParams -Relaunched" -Verb RunAs
    exit
}

# --- 2. Dynamic Path Discovery ---
$dotfilesDir  = $PSScriptRoot 
$envPath      = Join-Path $HOME "Desktop\env"
$scriptPath   = Join-Path $dotfilesDir "scripts"
$sourceProfile = Join-Path $dotfilesDir "Microsoft.PowerShell_profile.ps1"

# Utility function with improved alignment for wide icons
function Write-Status($icon, $label, $status, $isAction = $false) {
    $color = if ($isAction) { "Cyan" } else { "DarkGray" }
    $statusColor = if ($isAction) { "White" } else { "Gray" }
    
    # Create a 4-character fixed-width string for the icon area
    $iconSlot = " $icon "
    if ($iconSlot.Length -lt 4) { $iconSlot = $iconSlot.PadRight(4) }

    Write-Host $iconSlot -NoNewline -ForegroundColor $color
    Write-Host "$($label.PadRight(25))" -NoNewline -ForegroundColor $statusColor
    Write-Host $status -ForegroundColor DarkGray
}

Write-Host "`n── Windows Setup ──────────────────────────────────" -ForegroundColor Cyan
Write-Host "  Location: " -NoNewline -ForegroundColor Gray
Write-Host $dotfilesDir -ForegroundColor White

# --- 3. Package Installation ---
$packages = @(
    "Microsoft.VisualStudioCode", "Google.Chrome", "Microsoft.WindowsTerminal",
    "junegunn.fzf", "ajeetdsouza.zoxide", "voidtools.Everything.Alpha",
    "Microsoft.PowerToys", "lin-ycv.EverythingCmdPal", "7zip.7zip",
    "Obsidian.Obsidian", "Spotify.Spotify", "Gyan.FFmpeg", "Microsoft.Edit",
    "JanDeDobbeleer.OhMyPosh", "VideoLAN.VLC", "Google.GoogleDrive", "astral-sh.uv"
)

Write-Host "`n 📦 Packages" -ForegroundColor Cyan
if ($noinstall) {
    Write-Host "    Skipping installation check (switch enabled)." -ForegroundColor DarkGray
} else {
    # Get a list of installed apps once to speed up the loop
    $installedApps = (winget list --accept-source-agreements | Out-String)
    
    foreach ($pkg in $packages) {
        if ($installedApps -match [regex]::Escape($pkg)) {
            Write-Host "    · " -NoNewline -ForegroundColor DarkGray
            Write-Host $pkg -ForegroundColor DarkGray
        } else {
            Write-Host "    → " -NoNewline -ForegroundColor Cyan
            Write-Host "$($pkg.PadRight(35))" -NoNewline -ForegroundColor White
            Write-Host "Installing..." -ForegroundColor Gray
            winget install --id $pkg --accept-source-agreements --accept-package-agreements -e --silent --no-upgrade | Out-Null
        }
    }
}

Write-Host "`n ⚙️  System Configuration" -ForegroundColor Cyan

$osName = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName
$osBuild = [System.Environment]::OSVersion.Version.Build
Write-Status "💻" "OS Version" "$osName (Build $osBuild)"

# --- 4. Profile Symlinking ---
$targetProfile = $PROFILE
if (Test-Path $sourceProfile) {
    $isLink = (Get-Item $targetProfile -ErrorAction SilentlyContinue).Attributes -match "ReparsePoint"
    if ($isLink) {
        Write-Status "🔗" "PowerShell Profile" "Linked"
    } else {
        Write-Status "🔗" "PowerShell Profile" "Updating..." $true
        if (Test-Path $targetProfile) { 
            $backup = "$targetProfile.bak_$(Get-Date -Format 'yyyyMMdd')"
            Move-Item $targetProfile $backup -Force 
        }
        New-Item -ItemType SymbolicLink -Path $targetProfile -Target $sourceProfile -Force | Out-Null
    }
} else {
    Write-Status "❌" "PowerShell Profile" "Source Missing" $true
}

# --- 5. UV Environment Setup ---
if (Test-Path $envPath) {
    Write-Status "🐍" "Python Environment" "Ready"
} else {
    Write-Status "🐍" "Python Environment" "Creating..." $true
    if (!(Get-Command uv -ErrorAction SilentlyContinue)) {
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
        $env:Path += ";$HOME\.cargo\bin"
    }
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        uv init $envPath | Out-Null
        $reqs = Join-Path $dotfilesDir "requirements.txt"
        if (Test-Path $reqs) {
            Push-Location $envPath
            uv add -r $reqs | Out-Null
            Pop-Location
        }
    }
}

# --- 6. Font Installation (Caskaydia Cove) ---
Add-Type -AssemblyName System.Drawing
$hasFont = (New-Object System.Drawing.Text.InstalledFontCollection).Families | Where-Object { $_.Name -match "Caskaydia" }
if ($hasFont) {
    Write-Status "🖋️" "Caskaydia Font" "Installed"
} else {
    Write-Status "🖋️" "Caskaydia Font" "Downloading..." $true
    $apiUrl = "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
    $tempFolder = Join-Path $env:TEMP "CaskaydiaNF"
    $zipFile = Join-Path $env:TEMP "Caskaydia.zip"

    try {
        $release = Invoke-RestMethod -Uri $apiUrl -Headers @{"User-Agent"="PowerShell"}
        $fontUrl = ($release.assets | Where-Object { $_.name -eq "CaskaydiaCove.zip" }).browser_download_url
        New-Item $tempFolder -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $fontUrl -OutFile $zipFile -UseBasicParsing
        Expand-Archive $zipFile -DestinationPath $tempFolder -Force
        
        $shell = New-Object -ComObject Shell.Application
        $fontsNamespace = $shell.Namespace(0x14) 
        Get-ChildItem $tempFolder -Filter "*.ttf" -Recurse | ForEach-Object {
            if (!(Test-Path "C:\Windows\Fonts\$($_.Name)")) {
                $fontsNamespace.CopyHere($_.FullName, 0x10)
            }
        }
    } finally {
        Remove-Item $zipFile, $tempFolder -Recurse -ErrorAction SilentlyContinue
    }
}

# --- 7. Terminal-Icons ---
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Write-Status "📁" "Terminal Icons" "Active"
} else {
    Write-Status "📁" "Terminal Icons" "Installing..." $true
    Install-Module -Name Terminal-Icons -Repository PSGallery -Force -Scope CurrentUser | Out-Null
}

# --- 8. Path Update ---
$currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -like "*$scriptPath*") {
    Write-Status "🚀" "Scripts Path" "Mapped"
} else {
    Write-Status "🚀" "Scripts Path" "Adding..." $true
    [System.Environment]::SetEnvironmentVariable("PATH", "$currentPath;$scriptPath", "User")
}

# --- 9. Python File Association ---
$pythonPath = Join-Path $envPath ".venv\Scripts\python.exe"
if (Test-Path $pythonPath) {
    $progId = "UV.PythonFile"
    $command = "`"$pythonPath`" `"%1`" %*"
    $classes = "HKCU:\Software\Classes"
    
    $currentAssoc = (Get-ItemProperty "$classes\.py" -ErrorAction SilentlyContinue)."(default)"
    if ($currentAssoc -eq $progId) {
        Write-Status "🐍" "Python Association" "Mapped"
    } else {
        Write-Status "🐍" "Python Association" "Fixing..." $true
        New-Item "$classes\$progId\shell\open\command" -Force | Out-Null
        Set-ItemProperty "$classes\$progId\shell\open\command" -Name "(default)" -Value $command
        New-Item "$classes\.py" -Force | Out-Null
        Set-ItemProperty "$classes\.py" -Name "(default)" -Value $progId
    }
}

# --- 10. Windows Explorer Tweaks ---
$explorerSettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$alreadyTweaked = ($explorerSettings.HideFileExt -eq 0 -and $explorerSettings.Hidden -eq 1)

if ($alreadyTweaked) {
    Write-Status "👁️" "Explorer Tweaks" "Applied"
} else {
    Write-Status "👁️" "Explorer Tweaks" "Applying..." $true
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
}

# --- 11. Git Identity ---
if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitName = git config --global user.name
    
    if ($gitName) {
        Write-Status "🐙" "Git Identity" "Configured"
    } else {
        Write-Status "🐙" "Git Identity" "Setting up..." $true
        git config --global user.name "Bouchet07"
        git config --global user.email "diegobouchet88@gmail.com"
        git config --global init.defaultBranch main
    }
}

# --- 12. Windows Terminal Settings Link ---
$wtSettingsDir  = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$wtSettingsFile = Join-Path $wtSettingsDir "settings.json"
$sourceSettings = Join-Path $dotfilesDir "settings.json" # Assumes it's in your dotfiles root

if (Test-Path $sourceSettings) {
    # Ensure the Terminal directory exists (it might not on a brand new install)
    if (!(Test-Path $wtSettingsDir)) { New-Item -ItemType Directory -Path $wtSettingsDir -Force | Out-Null }

    $isLink = (Get-Item $wtSettingsFile -ErrorAction SilentlyContinue).Attributes -match "ReparsePoint"
    
    if ($isLink) {
        Write-Status "🎨" "Terminal Settings" "Linked"
    } else {
        Write-Status "🎨" "Terminal Settings" "Linking..." $true
        # Backup the default one if it exists
        if (Test-Path $wtSettingsFile) { Move-Item $wtSettingsFile "$wtSettingsFile.bak" -Force }
        New-Item -ItemType SymbolicLink -Path $wtSettingsFile -Target $sourceSettings -Force | Out-Null
    }
} else {
    Write-Status "❌" "Terminal Settings" "Source Missing"
}

Write-Host "`n── Final Summary ──────────────────────────────────" -ForegroundColor Cyan
$done = Get-Date -Format "HH:mm:ss"
Write-Host "  ✨ All tasks verified at $done" -ForegroundColor Gray
Write-Host "  🚀 System is fully optimized" -ForegroundColor White
Write-Host "────────────────────────────────────────────────────`n" -ForegroundColor Cyan

# Play the finish sound
[System.Media.SystemSounds]::Asterisk.Play()

# --- 16. Smart Exit ---
if ($Relaunched) {
    Write-Host "`n  ✨ Setup Complete. Press any key to close this window..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} else {
    Write-Host "`n  ✨ Setup Complete. Returning to prompt..." -ForegroundColor Gray
}
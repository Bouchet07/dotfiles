param(
    [switch]$noinstall = $false,
    [switch]$Relaunched = $false
)

<#
.SYNOPSIS
    Premium Windows Environment Bootstrap Script
.DESCRIPTION
    Asynchronous, idempotent post-install configuration tool.
#>

#region 1. GLOBAL CONFIGURATION
$Config = @{
    DotfilesDir   = $PSScriptRoot
    EnvPath       = Join-Path $HOME "Desktop\env"
    ScriptPath    = Join-Path $PSScriptRoot "scripts"
    SourceProfile = Join-Path $PSScriptRoot "Microsoft.PowerShell_profile.ps1"
    SourceWtSet   = Join-Path $PSScriptRoot "settings.json"
    Requirements  = Join-Path $PSScriptRoot "requirements.txt"
    LogPath       = Join-Path $env:TEMP "windows_setup_errors.log"
    WingetStatus  = Join-Path $env:TEMP "winget_status.txt"
    UvLiveLog     = Join-Path $env:TEMP "uv_live_output.log"
}

$Packages = @(
    "Microsoft.VisualStudioCode", "Google.Chrome", "Microsoft.WindowsTerminal",
    "junegunn.fzf", "ajeetdsouza.zoxide", "voidtools.Everything.Alpha",
    "Microsoft.PowerToys", "lin-ycv.EverythingCmdPal", "7zip.7zip",
    "Obsidian.Obsidian", "Spotify.Spotify", "Gyan.FFmpeg", "Microsoft.Edit",
    "JanDeDobbeleer.OhMyPosh", "VideoLAN.VLC", "Google.GoogleDrive", "astral-sh.uv",
    "JAMSoftware.TreeSize.Free", "HandBrake.HandBrake"
)

# Initialize timer & clean previous logs
$GlobalTimer = [System.Diagnostics.Stopwatch]::StartNew()
if (Test-Path $Config.LogPath) { Remove-Item $Config.LogPath -Force }
#endregion

#region 2. CORE UTILITY FUNCTIONS
function Ensure-Admin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "`n  🔑 Requesting Administrator elevation..." -ForegroundColor Cyan
        $args = if ($noinstall) { "-noinstall" } else { "" }
        $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
        Start-Process "wt.exe" -ArgumentList "-w 0 new-tab -p `"PowerShell`" $shell -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $args -Relaunched" -Verb RunAs
        exit
    }
}

function Write-TaskStatus($icon, $label, $status, $isAction = $false) {
    $color = if ($isAction) { "Cyan" } else { "DarkGray" }
    $statusColor = if ($isAction) { "White" } else { "Gray" }
    
    # 1. Print the icon and label normally
    Write-Host "    $icon  " -NoNewline -ForegroundColor $color
    Write-Host $label -NoNewline -ForegroundColor $statusColor
    
    # 2. Force the cursor to snap to exactly column 38
    [Console]::CursorLeft = 38
    
    # 3. Print the status
    Write-Host $status -ForegroundColor DarkGray
}

function Show-Header {
    Clear-Host
    Write-Host "`n  ██████╗ ██████╗ ████████╗███████╗██╗██╗     ███████╗" -ForegroundColor Cyan
    Write-Host "  ██╔══██╗██╔══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝" -ForegroundColor Cyan
    Write-Host "  ██║  ██║██║  ██║   ██║   █████╗  ██║██║     █████╗  " -ForegroundColor Blue
    Write-Host "  ██║  ██║██║  ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  " -ForegroundColor DarkBlue
    Write-Host "  ██████╔╝██████╔╝   ██║   ██║     ██║███████╗███████╗" -ForegroundColor DarkGray
    Write-Host "  ╚═════╝ ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝" -ForegroundColor DarkGray
    Write-Host "`n  ── Windows Environment Setup ────────────────────────" -ForegroundColor Cyan
    Write-Host "  Target: " -NoNewline -ForegroundColor Gray; Write-Host $Config.DotfilesDir -ForegroundColor White
    Write-Host "  Logs:   " -NoNewline -ForegroundColor Gray; Write-Host $Config.LogPath -ForegroundColor DarkGray
}
#endregion

#region 3. ASYNC INSTALLATION ENGINE
function Start-AsyncInstallations {
    Write-Host "`n  🔄 Parallel Downloads & Installations" -ForegroundColor Cyan
    
    if (Test-Path $Config.WingetStatus) { Remove-Item $Config.WingetStatus -Force }
    if (Test-Path $Config.UvLiveLog) { Remove-Item $Config.UvLiveLog -Force }

    # 1. Winget Job
    $wingetJob = Start-Job -ScriptBlock {
        param($packages, $noinstall, $cfg)
        if ($noinstall) { return "Skipped" }
        $installed = (winget list --accept-source-agreements | Out-String)
        $total = $packages.Count; $current = 0
        foreach ($pkg in $packages) {
            $current++
            "$current/{$total}: $pkg" | Out-File -FilePath $cfg.WingetStatus -Force
            if ($installed -notmatch [regex]::Escape($pkg)) {
                try { winget install --id $pkg --accept-source-agreements --accept-package-agreements -e --silent --disable-interactivity --no-upgrade 2>> $cfg.LogPath | Out-Null } 
                catch { "Winget failed ($pkg): $_" | Out-File -Append -FilePath $cfg.LogPath }
            }
        }
        return "Complete"
    } -ArgumentList $Packages, $noinstall, $Config

    # 2. UV Environment Job
    $uvJob = Start-Job -ScriptBlock {
        param($cfg)
        try {
            if (-not (Test-Path $cfg.EnvPath)) {
                "Checking dependencies..." | Out-File -FilePath $cfg.UvLiveLog -Force
                if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
                    "Installing UV package manager..." | Out-File -Append -FilePath $cfg.UvLiveLog
                    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex" *>> $cfg.UvLiveLog
                    $env:Path += ";$HOME\.cargo\bin"
                }
                "Initializing virtual environment..." | Out-File -Append -FilePath $cfg.UvLiveLog
                uv init $cfg.EnvPath *>> $cfg.UvLiveLog
                if (Test-Path $cfg.Requirements) {
                    "Resolving Python dependencies..." | Out-File -Append -FilePath $cfg.UvLiveLog
                    Push-Location $cfg.EnvPath
                    uv add -r $cfg.Requirements *>> $cfg.UvLiveLog 
                    Pop-Location
                }
            }
            "Environment configuration optimized." | Out-File -Append -FilePath $cfg.UvLiveLog
            return "Complete"
        } catch {
            "CRITICAL ERROR: $_" | Out-File -Append -FilePath $cfg.LogPath
            return "Failed"
        }
    } -ArgumentList $Config

    # 3. Render Loop
    $frames = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    $frameIdx = 0; $cursorTop = [Console]::CursorTop; $allDone = $false
    $jobs = [ordered]@{ "Winget Packages" = $wingetJob; "Python Env (UV)" = $uvJob }

    # Perfect box dimensions
    $bodyWidth = 60
    $topDashes = 44 # Calculated to perfectly align the ┌ and ┐ borders
    $topBorder = "    ┌── UV Live Output $([string]::new('─', $topDashes))┐"
    $bottomBorder = "    └$([string]::new('─', 62))┘"

    while (-not $allDone) {
        [Console]::SetCursorPosition(0, $cursorTop)
        $allDone = $true; $spinner = $frames[$frameIdx % $frames.Count]
        
        # Draw Jobs Status
        foreach ($task in $jobs.Keys) {
            $job = $jobs[$task]
            $padName = $task.PadRight(18)
            $statusStr = " Working...   "; $color = "DarkGray"

            if ($job.State -eq 'Running') {
                $allDone = $false
                if ($task -eq "Winget Packages" -and (Test-Path $Config.WingetStatus)) {
                    $live = (Get-Content $Config.WingetStatus -ErrorAction SilentlyContinue) | Select-Object -First 1
                    if ($live) { $statusStr = " Working... [$live]" }
                }
                Write-Host "    $spinner " -NoNewline -ForegroundColor Cyan; Write-Host $padName -NoNewline -ForegroundColor White
            } elseif ($job.State -eq 'Completed') {
                $statusStr = " Done"
                Write-Host "    ✔️ " -NoNewline -ForegroundColor Green; Write-Host $padName -NoNewline -ForegroundColor Gray
            } else {
                $statusStr = " $($job.State)"; $color = "Red"
                Write-Host "    ❌ " -NoNewline -ForegroundColor Red; Write-Host $padName -NoNewline -ForegroundColor Gray
            }
            Write-Host "$($statusStr.PadRight(65))" -ForegroundColor $color
        }

        # Draw Transient Box
        if (-not $allDone) {
            Write-Host $topBorder -ForegroundColor DarkGray
            $logs = if (Test-Path $Config.UvLiveLog) { Get-Content $Config.UvLiveLog -Tail 5 -ErrorAction SilentlyContinue } else { @() }
            for ($i = 0; $i -lt 5; $i++) {
                $line = if ($i -lt $logs.Count) { $logs[$i] -replace "`e\[[0-9;]*[mK]", "" } else { "" }
                if ($line.Length -gt $bodyWidth) { $line = $line.Substring(0, $bodyWidth - 3) + "..." }
                Write-Host "    │ " -NoNewline -ForegroundColor DarkGray
                Write-Host $line.PadRight($bodyWidth) -NoNewline -ForegroundColor Gray
                Write-Host " │" -ForegroundColor DarkGray
            }
            Write-Host $bottomBorder -ForegroundColor DarkGray
        }

        $frameIdx++; Start-Sleep -Milliseconds 80
    }

    # Erase Transient Box (7 lines total: Top border + 5 body + bottom border)
    [Console]::SetCursorPosition(0, $cursorTop + $jobs.Count)
    for ($i = 0; $i -lt 7; $i++) { Write-Host "".PadRight(80) }
    [Console]::SetCursorPosition(0, $cursorTop + $jobs.Count)

    Receive-Job -Job $wingetJob, $uvJob | Out-Null
    Remove-Job -Job $wingetJob, $uvJob
    Remove-Item $Config.WingetStatus, $Config.UvLiveLog -ErrorAction SilentlyContinue
}
#endregion

#region 4. SYSTEM TWEAKS & CONFIGURATION
function Set-ProfileSymlinks {
    if (Test-Path $Config.SourceProfile) {
        $isLink = (Get-Item $PROFILE -ErrorAction SilentlyContinue).Attributes -match "ReparsePoint"
        if ($isLink) { Write-TaskStatus "🔗" "PowerShell Profile" "Linked" } else {
            Write-TaskStatus "🔗" "PowerShell Profile" "Updating..." $true
            if (Test-Path $PROFILE) { Move-Item $PROFILE "$PROFILE.bak_$(Get-Date -Format 'yyyyMMdd')" -Force }
            New-Item -ItemType SymbolicLink -Path $PROFILE -Target $Config.SourceProfile -Force | Out-Null
        }
    } else { Write-TaskStatus "❌" "PowerShell Profile" "Source Missing" $true }
}

function Install-CaskaydiaFont {
    Add-Type -AssemblyName System.Drawing
    $hasFont = (New-Object System.Drawing.Text.InstalledFontCollection).Families | Where-Object { $_.Name -match "Caskaydia" }
    if ($hasFont) { Write-TaskStatus "🖋️" "Caskaydia Font" "Installed" } else {
        Write-TaskStatus "🖋️" "Caskaydia Font" "Downloading..." $true
        $temp = Join-Path $env:TEMP "CaskaydiaNF"; $zip = Join-Path $env:TEMP "Caskaydia.zip"
        try {
            $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
            $url = ($rel.assets | Where-Object { $_.name -eq "CaskaydiaCove.zip" }).browser_download_url
            New-Item $temp -ItemType Directory -Force | Out-Null
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
            Expand-Archive $zip -DestinationPath $temp -Force
            $shell = New-Object -ComObject Shell.Application
            $ns = $shell.Namespace(0x14) 
            Get-ChildItem $temp -Filter "*.ttf" -Recurse | ForEach-Object {
                if (!(Test-Path "C:\Windows\Fonts\$($_.Name)")) { $ns.CopyHere($_.FullName, 0x10) }
            }
        } finally { Remove-Item $zip, $temp -Recurse -ErrorAction SilentlyContinue }
    }
}

function Set-SystemConfigurations {
    # 1. Terminal Icons
    if (Get-Module -ListAvailable -Name Terminal-Icons) { Write-TaskStatus "📁" "Terminal Icons" "Active" } else {
        Write-TaskStatus "📁" "Terminal Icons" "Installing..." $true
        Install-Module -Name Terminal-Icons -Repository PSGallery -Force -Scope CurrentUser | Out-Null
    }

    # 2. Path
    $path = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($path -like "*$($Config.ScriptPath)*") { Write-TaskStatus "🚀" "Scripts Path" "Mapped" } else {
        Write-TaskStatus "🚀" "Scripts Path" "Adding..." $true
        [Environment]::SetEnvironmentVariable("PATH", "$path;$($Config.ScriptPath)", "User")
    }

    # 3. Python Association
    $pyPath = Join-Path $Config.EnvPath ".venv\Scripts\python.exe"
    if (Test-Path $pyPath) {
        $classes = "HKCU:\Software\Classes"
        $current = (Get-ItemProperty "$classes\.py" -ErrorAction SilentlyContinue)."(default)"
        if ($current -eq "UV.PythonFile") { Write-TaskStatus "🐍" "Python File Assoc" "Mapped" } else {
            Write-TaskStatus "🐍" "Python File Assoc" "Fixing..." $true
            New-Item "$classes\UV.PythonFile\shell\open\command" -Force | Out-Null
            Set-ItemProperty "$classes\UV.PythonFile\shell\open\command" -Name "(default)" -Value "`"$pyPath`" `"%1`" %*"
            New-Item "$classes\.py" -Force | Out-Null
            Set-ItemProperty "$classes\.py" -Name "(default)" -Value "UV.PythonFile"
        }
    }

    # 4. Explorer Tweaks
    $exp = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if ($exp.HideFileExt -eq 0 -and $exp.Hidden -eq 1) { Write-TaskStatus "👁️" "Explorer Tweaks" "Applied" } else {
        Write-TaskStatus "👁️" "Explorer Tweaks" "Applying..." $true
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
    }

    # 5. Git Identity
    if (Get-Command git -ErrorAction SilentlyContinue) {
        if (git config --global user.name) { Write-TaskStatus "🐙" "Git Identity" "Configured" } else {
            Write-TaskStatus "🐙" "Git Identity" "Setting up..." $true
            git config --global user.name "Bouchet07"
            git config --global user.email "diegobouchet88@gmail.com"
            git config --global init.defaultBranch main
        }
    }

    # 6. Windows Terminal Linking
    $wtDir  = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
    $wtFile = Join-Path $wtDir "settings.json"
    if (Test-Path $Config.SourceWtSet) {
        if (!(Test-Path $wtDir)) { New-Item -ItemType Directory -Path $wtDir -Force | Out-Null }
        if ((Get-Item $wtFile -ErrorAction SilentlyContinue).Attributes -match "ReparsePoint") {
            Write-TaskStatus "🎨" "Terminal Settings" "Linked"
        } else {
            Write-TaskStatus "🎨" "Terminal Settings" "Linking..." $true
            if (Test-Path $wtFile) { Move-Item $wtFile "$wtFile.bak" -Force }
            New-Item -ItemType SymbolicLink -Path $wtFile -Target $Config.SourceWtSet -Force | Out-Null
        }
    }
}
#endregion

#region 5. MAIN EXECUTION
Ensure-Admin
[Console]::CursorVisible = $false

Show-Header

# Phase 1: Heavy Lifting (Async)
Start-AsyncInstallations

# Phase 2: Synchronous Configs
Write-Host "`n  ⚙️  System Configuration" -ForegroundColor Cyan
$os = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName
$build = [Environment]::OSVersion.Version.Build
Write-TaskStatus "💻" "OS Version" "$os (Build $build)"

Set-ProfileSymlinks
Install-CaskaydiaFont
Set-SystemConfigurations

[Console]::CursorVisible = $true
$GlobalTimer.Stop()

# Phase 3: Exit Summary
Write-Host "`n  ── Final Summary ────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  ⏱️ Completed in " -NoNewline -ForegroundColor Gray; Write-Host "$([math]::Round($GlobalTimer.Elapsed.TotalSeconds, 1))s" -ForegroundColor White
if (Test-Path $Config.LogPath) {
    if ((Get-Item $Config.LogPath).Length -gt 0) { Write-Host "  ⚠️ Background errors logged: " -NoNewline -ForegroundColor DarkYellow; Write-Host $Config.LogPath -ForegroundColor Gray }
}
Write-Host "  🚀 System is fully optimized and ready." -ForegroundColor Green
Write-Host "  ─────────────────────────────────────────────────────`n" -ForegroundColor Cyan

[System.Media.SystemSounds]::Asterisk.Play()

if ($Relaunched) {
    Write-Host "  ✨ Press any key to close this window..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
#endregion
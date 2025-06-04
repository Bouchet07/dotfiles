param(
    [switch]$noinstall = $false
)

# List of packages to install or upgrade
$packages = @(
    "Microsoft.VisualStudioCode",
    "Google.Chrome",
    "Microsoft.WindowsTerminal",
    "junegunn.fzf",
    "ajeetdsouza.zoxide",
    "voidtools.Everything.Alpha",
    "Microsoft.PowerToys",
    "lin-ycv.EverythingCmdPal",
    "7zip.7zip",
    "Obsidian.Obsidian",
    "Spotify.Spotify",
    "Gyan.FFmpeg",
    "Microsoft.Edit",
    "JanDeDobbeleer.OhMyPosh",
    "VideoLAN.VLC",
    "Google.GoogleDrive",
    "astral-sh.uv"
)

# Serial installation of packages
if ($noinstall) {
    Write-Host "Skipping installation of packages as requested."
} else {
    Write-Host "Starting installation of packages..."
    foreach ($pkg in $packages) {
        Write-Host "→ Installing: $pkg"
        try {
            # Consider adding error handling for winget if needed, e.g., checking $LASTEXITCODE
            winget install --id $pkg --accept-source-agreements --accept-package-agreements -e --silent
            Write-Host "✔ Finished: $pkg"
        } catch {
            Write-Host "❌ Failed to install: $pkg" -ForegroundColor Red
        }
    }
}

# Check and link PowerShell profile to dotfiles
$sourceProfile = "$HOME\Desktop\dotfiles\Microsoft.PowerShell_profile.ps1"
$targetProfile = $PROFILE

if (!(Test-Path -Path $targetProfile)) {
    Write-Host "🔗 Linking PowerShell profile from $sourceProfile to $targetProfile..."
    try {
        New-Item -ItemType SymbolicLink -Path $targetProfile -Target $sourceProfile -Force -ErrorAction Stop
        Write-Host "✅ PowerShell profile linked successfully."
    } catch {
        Write-Warning "⚠️ Failed to create symbolic link for PowerShell profile. Error: $($_.Exception.Message)"
        Write-Warning "Please ensure you are running PowerShell as Administrator if creating symlinks in system-protected directories, or check permissions."
    }
} else {
    $profileItem = Get-Item -LiteralPath $targetProfile -Force

    if ($profileItem.Attributes -match 'ReparsePoint') {
        $resolvedTarget = $null
        try {
            # For symlinks, Target is a property. For junctions, it might differ or need other access methods.
            # Get-Item on a symlink resolves it, so $profileItem.Target should work for symlinks.
             $resolvedTarget = (Get-Item $profileItem.FullName).Target
        } catch {
            Write-Warning "Could not resolve target of existing symlink at $targetProfile : $($_.Exception.Message)"
        }
        
        if ($resolvedTarget -and ($resolvedTarget -ne $sourceProfile)) {
            Write-Host "⚠️ PowerShell profile at $targetProfile is a symlink, but points to a different location:"
            Write-Host "  → Existing target: $resolvedTarget"
            Write-Host "  → Expected target: $sourceProfile"
            Write-Host "  You may want to manually update it."
        } elseif ($resolvedTarget -and ($resolvedTarget -eq $sourceProfile)) {
            Write-Host "✅ PowerShell profile is already linked correctly to $sourceProfile."
        } else {
             Write-Host "ℹ️ PowerShell profile at $targetProfile is a reparse point, but its target could not be confirmed or doesn't match."
        }
    } else {
        Write-Host "⚠️ PowerShell profile at $targetProfile exists but is not a symlink. You may want to review its content or back it up and replace with a symlink."
        Write-Host "  → Existing file: $targetProfile"
    }
}
# check if "C:\Users\diego\Desktop\env" exists, if not create it
$envPath = "C:\Users\diego\Desktop\env"
if (-not (Test-Path -Path $envPath)) {
    # search in "C:\Users\diego\AppData\Local\Microsoft\WinGet\Packages" for a package containing "astral-sh.uv"
    $uvPackage = Get-ChildItem -Path "C:\Users\diego\AppData\Local\Microsoft\WinGet\Packages" -Recurse -Filter "*astral-sh.uv*" -ErrorAction SilentlyContinue
    if ($uvPackage) {
        $uvPath = Join-Path -Path $uvPackage.FullName -ChildPath "uv.exe"
        # execute uv.exe init "C:\Users\diego\Desktop\env"
        if (Test-Path -Path $uvPath) {
            Write-Host "Found uv package at: $uvPath"
            Write-Host "Initializing uv..."
            & $uvPath init "C:\Users\diego\Desktop\env"
            Write-Host "✅ uv initialized successfully."
            # go to the environment directory
            $originalPath = Get-Location
            Set-Location -Path $envPath
            Write-Host "Installing common packages..."
            & $uvPath add -r $HOME\Desktop\dotfiles\requirements.txt
            Write-Host "✅ Common packages installed successfully."
            # Return to the original location
            Set-Location -Path $originalPath
        } else {
            Write-Host "❌ uv.exe not found in the package directory."
        }
    } else {
        Write-Host "❌ No uv package found in WinGet packages."
    }
} else {
    Write-Host "ℹ️ Environment directory already exists at $envPath. Skipping uv initialization."
}


Add-Type -AssemblyName System.Drawing

function Get-CaskaydiaFonts {
    $fonts = (New-Object System.Drawing.Text.InstalledFontCollection).Families
    return $fonts | Where-Object { $_.Name -match "Caskaydia" }
}

# Registry path and fonts folder
$fontsFolder = "$env:WINDIR\Fonts"
$fontRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

$caskaydiaFonts = Get-CaskaydiaFonts

if (-not $caskaydiaFonts) {
    Write-Host "🔍 Caskaydia Cove Nerd Font not detected. Installing..."

    # Step 1: Fetch latest CascaydiaCove.zip from GitHub API
    $apiUrl = "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
    $headers = @{ "User-Agent" = "PowerShell" }

    try {
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
        $asset = $release.assets | Where-Object { $_.name -eq "CaskaydiaCove.zip" }

        if (-not $asset) {
            Write-Host "❌ 'CaskaydiaCove.zip' not found in the latest release." -ForegroundColor Red
            return
        }

        $fontUrl = $asset.browser_download_url
        Write-Host "📥 Latest font URL: $fontUrl"
    } catch {
        Write-Host "❌ Failed to retrieve latest font release: $_" -ForegroundColor Red
        return
    }

    # Step 2: Prepare temp paths
    $tempFolder = Join-Path $env:TEMP "CaskaydiaNF"
    $zipFile = Join-Path $env:TEMP "CaskaydiaCove.zip"

    if (Test-Path $tempFolder) {
        Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null

    # Step 3: Download font zip
    Write-Host "⏬ Downloading Caskaydia Cove Nerd Font..."
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $fontUrl -OutFile $zipFile -UseBasicParsing
        $ProgressPreference = 'Continue'
    } catch {
        Write-Host "❌ Failed to download font: $_" -ForegroundColor Red
        return
    }

    # Step 4: Extract
    Write-Host "📦 Extracting font files..."
    try {
        Expand-Archive -Path $zipFile -DestinationPath $tempFolder -Force
    } catch {
        Write-Host "❌ Extraction failed: $_" -ForegroundColor Red
        return
    }

    # Step 5: Install fonts
    $ttfFiles = Get-ChildItem -Path $tempFolder -Recurse -Filter "*.ttf"
    if ($ttfFiles.Count -eq 0) {
        Write-Host "❌ No TTF font files found after extraction." -ForegroundColor Red
        return
    }

    Write-Host "🖋️ Installing fonts..."
    foreach ($font in $ttfFiles) {
        try {
            $targetPath = Join-Path $fontsFolder $font.Name
            Copy-Item -Path $font.FullName -Destination $targetPath -Force

            $fontRegName = $font.BaseName + " (TrueType)"
            New-ItemProperty -Path $fontRegistryPath -Name $fontRegName -Value $font.Name -PropertyType String -Force | Out-Null

            Write-Host "  ✓ Installed: $($font.Name)"
        } catch {
            Write-Host "  ⚠️ Failed to install: $($font.Name) - $_" -ForegroundColor Yellow
        }
    }

    # Step 6: Clean up
    Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "✅ Caskaydia Cove Nerd Font installation completed."

} else {
    Write-Host "✅ Caskaydia Cove Nerd Font is already installed."
    Write-Host "`n🖋️ Installed Caskaydia-related fonts:" -ForegroundColor Cyan
    foreach ($font in $caskaydiaFonts) {
        Write-Host "  - $($font.Name)"
    }
}




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
    "Google.GoogleDrive"
)

# Auto-scale concurrency
$logicalCores = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
$maxConcurrentJobs = [Math]::Min([Math]::Max([Math]::Floor($logicalCores / 2), 2), 10)

Write-Host "🧠 Auto-detected $logicalCores logical cores → Using $maxConcurrentJobs concurrent jobs."

$jobs = @() # Initialize as an empty array

foreach ($pkg in $packages) {
    # Wait if the number of running jobs reaches the maximum concurrency
    while (($jobs | Where-Object { $_.Job.State -eq 'Running' }).Count -ge $maxConcurrentJobs) {
        Start-Sleep -Seconds 1
        # Process any jobs that have finished while waiting
        $finishedEntriesInLoop = @($jobs | Where-Object { $_.Job.State -ne 'Running' }) # Iterate a static copy
        $idsToRemoveFromTracking = [System.Collections.Generic.List[int]]::new()

        foreach ($entry in $finishedEntriesInLoop) {
            $psJob = Get-Job -Id $entry.Job.Id -ErrorAction SilentlyContinue
            if ($psJob) {
                Receive-Job -Job $psJob -ErrorAction SilentlyContinue > $null
                Remove-Job -Job $psJob -ErrorAction SilentlyContinue
                Write-Host "✔ Finished: $($entry.Package)"
            }
            $idsToRemoveFromTracking.Add($entry.Job.Id)
        }
        if ($idsToRemoveFromTracking.Count -gt 0) {
            $jobs = @($jobs | Where-Object { $currentJobId = $_.Job.Id; -not ($idsToRemoveFromTracking.Contains($currentJobId)) })
        }
    }

    Write-Host "→ Starting: $pkg"
    $job = Start-Job -ArgumentList $pkg -ScriptBlock {
        param($package)
        # Consider adding error handling for winget if needed, e.g., checking $LASTEXITCODE
        winget upgrade --id $package --accept-source-agreements --accept-package-agreements -e --silent *> $null 2>&1
    }

    if ($job) {
        $jobs += [PSCustomObject]@{
            Job     = $job
            Package = $pkg
        }
    } else {
        Write-Warning "⚠️ Failed to start job for package: $pkg"
    }
}

# Wait for remaining jobs
Write-Host "`n⏳ Waiting for remaining installations..."
while ($jobs.Count -gt 0) {
    $processedItemThisPass = $false
    # Get jobs that are not in 'Running' state (based on potentially stale job object state)
    # or jobs that are no longer found in the PS job system (stale entries in our $jobs array)
    $itemsToProcess = @($jobs | Where-Object { $_.Job.State -ne 'Running' -or (Get-Job -Id $_.Job.Id -ErrorAction SilentlyContinue) -eq $null })

    if ($itemsToProcess.Count -eq 0) {
        # All jobs in $jobs array appear to be 'Running' and exist in PS job system
        Start-Sleep -Seconds 1
        continue # Skip to next iteration of the while loop
    }
    
    $idsToRemoveFromTrackingFinal = [System.Collections.Generic.List[int]]::new()

    foreach ($entry in $itemsToProcess) {
        $psJob = Get-Job -Id $entry.Job.Id -ErrorAction SilentlyContinue
        if ($psJob) {
            # Job still exists in PowerShell, so receive and remove it
            Receive-Job -Job $psJob -ErrorAction SilentlyContinue > $null
            Remove-Job -Job $psJob -ErrorAction SilentlyContinue
            # Only Write-Host if it was genuinely processed here, implying it might have been missed by the first loop's cleanup
            Write-Host "✔ Finished (in cleanup): $($entry.Package)"
        }
        # else: Job was already removed from PowerShell (likely by the first loop).
        # No "Finished" message here to avoid duplicates. It's just a stale entry to be cleaned.
        
        $idsToRemoveFromTrackingFinal.Add($entry.Job.Id)
        $processedItemThisPass = $true
    }

    if ($idsToRemoveFromTrackingFinal.Count -gt 0) {
         $jobs = @($jobs | Where-Object { $currentJobId = $_.Job.Id; -not ($idsToRemoveFromTrackingFinal.Contains($currentJobId)) })
    }

    # If we didn't process any items (e.g., all remaining jobs in $jobs are actually running and none were stale)
    # and $jobs is still not empty, sleep.
    if (-not $processedItemThisPass -and $jobs.Count -gt 0) {
        Start-Sleep -Seconds 1
    }
}

Write-Host "`n✅ All installations and updates completed."

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




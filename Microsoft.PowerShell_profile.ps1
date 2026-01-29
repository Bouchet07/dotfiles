# !! Contents within this block are managed by 'conda init' !!
#If (Test-Path "C:\Users\diego\miniconda3\Scripts\conda.exe") {
#    (& "C:\Users\diego\miniconda3\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression
#}
#endregion

(& uv generate-shell-completion powershell) | Out-String | Invoke-Expression
(& uvx --generate-shell-completion powershell) | Out-String | Invoke-Expression

# Oh-my-posh
oh-my-posh --init --shell pwsh --config ~\Desktop\dotfiles\new_prompt.json | Invoke-Expression

# Icons
Import-Module -Name Terminal-Icons

# zoxide (better cd commad)
Invoke-Expression (& { (zoxide init powershell --cmd cd| Out-String) })

# UTF-8 encoding
#$OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding =
#                    New-Object System.Text.UTF8Encoding
# Functions
Function time{
	$Command = "$args"
	Measure-Command {Invoke-Expression $command | Out-Default}
}
Function ntime{
	$Command = "$args"
	Measure-Command {Invoke-Expression $command}
}
Function bot{
	Set-Location "C:\Users\diego\Desktop\Programming\python\chess-auto-bot"
	$Command = "uv run src\gui.py"
	Invoke-Expression $command
}

function Clean-Clipboard {
    # 1. Get the content as a raw string.
    # This reads the text only, ignoring HTML/RTF formatting.
    $content = Get-Clipboard -Raw

    # 2. Check if clipboard is empty to avoid errors
    if ($null -ne $content) {
        # 3. Set the text back to clipboard.
        # This effectively strips the "Rich Text" metadata.
        Set-Clipboard -Value $content
        Write-Host "Clipboard stripped of formatting." -ForegroundColor Green
    }
}

#alias
New-Alias aff3ct C:\Users\diego\Desktop\toolbox\build_windows_gcc_x64_avx2\bin\aff3ct-3.0.2.exe
New-Alias stockfish C:\Users\diego\Desktop\Programming\chess\stockfish_14.1_win_x64_avx2\stockfish_14.1_win_x64_avx2.exe
New-Alias vlc "C:\Program Files\VideoLAN\VLC\vlc.exe"
New-Alias uvg "C:\Users\diego\Desktop\env\.venv\Scripts\activate.ps1"
New-Alias python "C:\Users\diego\Desktop\env\.venv\Scripts\python.exe"
New-Alias -Name fix-copy -Value Clean-Clipboard



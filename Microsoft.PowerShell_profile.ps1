#region conda initialize
# !! Contents within this block are managed by 'conda init' !!
#If (Test-Path "C:\Users\diego\miniconda3\Scripts\conda.exe") {
#    (& "C:\Users\diego\miniconda3\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression
#}
#endregion

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

#alias
New-Alias aff3ct C:\Users\diego\Desktop\toolbox\build_windows_gcc_x64_avx2\bin\aff3ct-3.0.2.exe
New-Alias stockfish C:\Users\diego\Desktop\Programming\chess\stockfish_14.1_win_x64_avx2\stockfish_14.1_win_x64_avx2.exe
New-Alias vlc "C:\Program Files\VideoLAN\VLC\vlc.exe"
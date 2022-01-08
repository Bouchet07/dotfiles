#region conda initialize
# !! Contents within this block are managed by 'conda init' !!
(& "C:\Users\diego\anaconda3\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | Invoke-Expression
#endregion

# Oh-my-posh
oh-my-posh --init --shell pwsh --config ~\Desktop\dotfiles\myprompt.json | Invoke-Expression

# Icons
Import-Module -Name Terminal-Icons
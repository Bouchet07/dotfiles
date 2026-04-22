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
function whisper {
    param(
        [Parameter(Mandatory=$true)][string]$archivo,
        [Parameter(Mandatory=$false)][string]$idioma = "es"
    )
    
    $basePath = "C:\Users\diego\Desktop\Programming\c++\whisper.cpp"
    $exe = "$basePath\build\bin\whisper-cli.exe"
    $model = "$basePath\models\ggml-base.bin"
    
    $ext = [System.IO.Path]::GetExtension($archivo).ToLower()
    $archivoFinal = $archivo
    $esTemporal = $false

    # Conversión si es necesario
    if ($ext -notmatch "\.(wav|flac|mp3|ogg)") {
        Write-Host "--- Convirtiendo a WAV (16kHz)... ---" -ForegroundColor Cyan
        $archivoFinal = "$archivo.temp.wav"
        ffmpeg -i $archivo -ar 16000 -ac 1 -c:a pcm_s16le $archivoFinal -y -loglevel error
        $esTemporal = $true
    }

    # Ejecución con el parámetro de idioma (-l)
    & $exe -m $model -f $archivoFinal -l $idioma -otxt -osrt -t 8

    if ($esTemporal) {
        Remove-Item $archivoFinal
        Write-Host "--- Finalizado. ---" -ForegroundColor Green
    }
}

#alias
New-Alias aff3ct C:\Users\diego\Desktop\toolbox\build_windows_gcc_x64_avx2\bin\aff3ct-3.0.2.exe
New-Alias stockfish C:\Users\diego\Desktop\Programming\chess\stockfish_14.1_win_x64_avx2\stockfish_14.1_win_x64_avx2.exe
New-Alias vlc "C:\Program Files\VideoLAN\VLC\vlc.exe"
New-Alias uvg "C:\Users\diego\Desktop\env\.venv\Scripts\activate.ps1"
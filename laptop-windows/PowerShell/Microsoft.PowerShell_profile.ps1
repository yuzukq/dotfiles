oh-my-posh init pwsh | Invoke-Expression

Get-Content ".\shell_ascii_art.txt" | ForEach-Object {
    Write-Host $_ -ForegroundColor Cyan
}

oh-my-posh init pwsh --config $env:POSH_THEMES_PATH/easy-term.omp.json | Invoke-Expression

# ドキュメントフォルダにあるアスキーアートファイルを出力する関数
function Show-AsciiArt {
    # $Home はユーザーのホームフォルダ ($env:USERPROFILE) を示す
    Get-Content -Path "$Home\Documents\icon_ascii_art.txt"
}

# 作成した関数に 'iam' というエイリアスを割り当てる
Set-Alias -Name iam -Value Show-AsciiArt
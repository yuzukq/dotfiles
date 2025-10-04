oh-my-posh init pwsh | Invoke-Expression

Get-Content "C:\Users\yuzup\Documents\shell_ascii_art.txt" | Write-Host

oh-my-posh init pwsh --config $env:POSH_THEMES_PATH/easy-term.omp.json | Invoke-Expression

# ドキュメントフォルダにあるアスキーアートファイルを出力する関数を定義
function Show-AsciiArt {
    # Get-Content (エイリアス: gc, cat, type) でファイルの内容を出力
    # $Home はユーザーのホームフォルダ ($env:USERPROFILE) を示す
    Get-Content -Path "$Home\Documents\icon_ascii_art.txt"
}

# 作成した関数に 'iam' というエイリアスを割り当てる
Set-Alias -Name iam -Value Show-AsciiArt
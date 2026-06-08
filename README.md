# Development-Environment-Configuration
```bash
  ████████   ████████     ██████   ██████  ███  █████                   
 ███▒▒▒▒███ ███▒▒▒▒███   ▒▒██████ ██████  ▒▒▒  ▒▒███                    
▒▒▒    ▒███▒███   ▒███    ▒███▒█████▒███  ████  ▒███ █████ █████ ████   
   ██████▒ ▒▒█████████    ▒███▒▒███ ▒███ ▒▒███  ▒███▒▒███ ▒▒███ ▒███    
  ▒▒▒▒▒▒███ ▒▒▒▒▒▒▒███    ▒███ ▒▒▒  ▒███  ▒███  ▒██████▒   ▒███ ▒███    
 ███   ▒███ ███   ▒███    ▒███      ▒███  ▒███  ▒███▒▒███  ▒███ ▒███    
▒▒████████ ▒▒████████     █████     █████ █████ ████ █████ ▒▒████████   
 ▒▒▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒     ▒▒▒▒▒     ▒▒▒▒▒ ▒▒▒▒▒ ▒▒▒▒ ▒▒▒▒▒   ▒▒▒▒▒▒▒▒                                                                                                       
```
---

## Mac セットアップ手順

### 1. Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 2. chezmoi
```bash
brew install chezmoi
```

### 3. dotfiles を clone
```bash
git clone https://github.com/yuzukq/dotfiles ~/dotfiles
```

### 4. chezmoi の設定ファイルを作成
git の名前・メールアドレスを設定する（リポジトリには含まれないためここで指定する）。
```bash
mkdir -p ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml << 'EOF'
sourceDir = "~/dotfiles"

[data]
  git_name = "YOUR_NAME"
  git_email = "YOUR_EMAIL"
EOF
```

### 5. dotfiles を適用
```bash
chezmoi apply
```

ツール類（fish, fzf, bat, ripgrep, ghostty, zellij, karabiner-elements など）が自動でインストールされる。

### 6. Raycast の設定を復元
1. Raycast を起動
2. Settings → Import から `dotfiles/raycast/` 内の `.rayconfig` ファイルを選択
3. パスワードを入力（パスワードマネージャーで管理）

### 7. システム設定

**Karabiner-Elements**
- アクセシビリティの許可を付与

**キーボード**
- ファンクションキー → 「F1、F2 などのキーを標準のファンクションキーとして使用」を ON
- キーボードショートカット → Spotlight → 「Spotlight 検索を表示」の Cmd+Space を**無効化**
- キーボードショートカット → 入力ソース → 「前の入力ソースを選択」に **Cmd+Space** を割り当て

**Raycast**
- Raycast のホットキーを **Hyper+Space** に設定
  （Karabiner により物理的な左 Cmd キーが Hyper Key に変換されるため、左 Cmd+Space で起動）

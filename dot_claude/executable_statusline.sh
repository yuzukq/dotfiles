#!/bin/bash

input=$(cat)

# ── カラー定義  ────────────────────────────────
TEAL=$'\033[38;2;57;197;187m'
TEAL_DIM=$'\033[38;2;28;140;133m'
LIGHT_BLUE=$'\033[38;2;134;194;220m'
WHITE=$'\033[38;2;220;240;240m'
ORANGE=$'\033[38;2;255;160;60m'
RED=$'\033[38;2;255;90;90m'
YELLOW=$'\033[38;2;255;215;80m'
RESET=$'\033[0m'
BOLD=$'\033[1m'

SEP="${TEAL_DIM} ❙ ${RESET}"

# ── モデル ────────────────────────────────────────────────────
MODEL=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
MODEL_SHORT=$(echo "$MODEL" \
  | sed 's/Claude //' \
  | sed 's/claude-//' \
  | sed -E 's/-[0-9]{8}$//' \
  | sed -E 's/([0-9])-([0-9])/\1.\2/g' \
  | sed 's/-/ /g' \
  | awk '{$1=toupper(substr($1,1,1)) substr($1,2); print}')
MODEL_PART="${TEAL}♪${RESET} ${WHITE}${BOLD}${MODEL_SHORT}${RESET}"

# ── コンテキスト ──────────────────────────────────────────────
CTX_PART=""
USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0 | floor')
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 0')

if [ "$CTX_SIZE" -gt 0 ] 2>/dev/null && [ "$USED_PCT" -gt 0 ] 2>/dev/null; then
  if [ "$USED_PCT" -ge 80 ]; then
    CTX_COLOR="${RED}"
    CTX_ICON="⚠"
  elif [ "$USED_PCT" -ge 50 ]; then
    CTX_COLOR="${YELLOW}"
    CTX_ICON="◈"
  else
    CTX_COLOR="${TEAL}"
    CTX_ICON="◈"
  fi

  # ミニプログレスバー (8マス)
  FILLED=$(( USED_PCT * 8 / 100 ))
  BAR=""
  for i in $(seq 1 8); do
    if [ "$i" -le "$FILLED" ]; then
      BAR="${BAR}█"
    else
      BAR="${BAR}░"
    fi
  done

  CTX_PART="${CTX_COLOR}${CTX_ICON} ${BAR} ${USED_PCT}%${RESET}"
fi

# ── Git ブランチ & コミット状態 ───────────────────────────────
GIT_PART=""
DIR=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')

if [ -n "$DIR" ] && git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
  if [ -n "$BRANCH" ]; then
    # コンフリクトチェック
    CONFLICTS=$(git -C "$DIR" ls-files --unmerged 2>/dev/null | wc -l | tr -d ' ')
    # 未ステージの変更
    UNSTAGED=$(git -C "$DIR" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    # ステージ済みの変更
    STAGED=$(git -C "$DIR" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    # 未追跡ファイル
    UNTRACKED=$(git -C "$DIR" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

    if [ "$CONFLICTS" -gt 0 ]; then
      # コンフリクト: 赤 + ✗
      GIT_COLOR="${RED}"
      SUFFIX="✗"
    elif [ "$UNSTAGED" -gt 0 ] || [ "$UNTRACKED" -gt 0 ]; then
      # 未コミット変更あり: オレンジ + *
      GIT_COLOR="${ORANGE}"
      SUFFIX="*"
    elif [ "$STAGED" -gt 0 ]; then
      # ステージ済み (コミット待ち): イエロー + +
      GIT_COLOR="${YELLOW}"
      SUFFIX="+"
    else
      # クリーン: ミクティール
      GIT_COLOR="${TEAL}"
      SUFFIX=""
    fi

    GIT_PART="${SEP}${GIT_COLOR}🎵 ${BRANCH}${SUFFIX}${RESET}"
  fi
fi

# ── OAuth レートリミット ──────────────────────────────────────
CACHE_FILE="/tmp/claude_oauth_usage_cache.json"
CACHE_TTL=300  # 5分

# キャッシュチェック・バックグラウンド更新
fetch_usage=false
if [ -f "$CACHE_FILE" ]; then
  cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
  [ "$cache_age" -ge "$CACHE_TTL" ] && fetch_usage=true
else
  fetch_usage=true
fi

if [ "$fetch_usage" = true ]; then
  (
    CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    if [ -n "$CREDS" ]; then
      TOKEN=$(echo "$CREDS" | jq -r '.claudeAiOauth.accessToken' 2>/dev/null)
      if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
        USAGE=$(curl -s --max-time 3 "https://api.anthropic.com/api/oauth/usage" \
          -H "Authorization: Bearer ${TOKEN}" \
          -H "anthropic-beta: oauth-2025-04-20" \
          -H "User-Agent: claude-code/2.0.31" \
          -H "Accept: application/json" 2>/dev/null)
        if [ -n "$USAGE" ] && ! echo "$USAGE" | jq -e '.error' >/dev/null 2>&1; then
          echo "$USAGE" > "$CACHE_FILE"
        fi
      fi
    fi
  ) &
fi

# ミニプログレスバー生成 (8マス)
make_miku_bar() {
  local pct=$1
  local filled=$(( pct * 8 / 100 ))
  local bar=""
  for i in $(seq 1 8); do
    if [ "$i" -le "$filled" ]; then
      bar="${bar}█"
    else
      bar="${bar}░"
    fi
  done
  echo "$bar"
}

FIVE_HOUR_PART=""
SEVEN_DAY_PART=""

if [ -f "$CACHE_FILE" ]; then
  five_hour=$(jq -r '.five_hour.utilization // empty' "$CACHE_FILE" 2>/dev/null)
  five_hour_reset=$(jq -r '.five_hour.resets_at // empty' "$CACHE_FILE" 2>/dev/null)
  seven_day=$(jq -r '.seven_day.utilization // empty' "$CACHE_FILE" 2>/dev/null)

  # 5時間リミット (メインカラー: ティール)
  if [ -n "$five_hour" ]; then
    five_pct=$(printf "%.0f" "$five_hour" 2>/dev/null)
    if [ "$five_pct" -ge 80 ]; then
      FIVE_COLOR="${RED}"; FIVE_ICON="⚠"
    elif [ "$five_pct" -ge 50 ]; then
      FIVE_COLOR="${YELLOW}"; FIVE_ICON="⏱"
    else
      FIVE_COLOR="${TEAL}"; FIVE_ICON="⏱"
    fi
    FIVE_BAR=$(make_miku_bar "$five_pct")

    # リセットまでの残り時間
    TIME_LEFT=""
    if [ -n "$five_hour_reset" ]; then
      reset_clean=$(echo "$five_hour_reset" | sed 's/\.[0-9]*//; s/+00:00$//; s/Z$//')
      reset_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$reset_clean" "+%s" 2>/dev/null)
      if [ -n "$reset_epoch" ]; then
        now_epoch=$(date -u "+%s")
        diff=$(( reset_epoch - now_epoch ))
        if [ "$diff" -gt 0 ]; then
          hours=$(( diff / 3600 ))
          mins=$(( (diff % 3600) / 60 ))
          TIME_LEFT=" ${TEAL_DIM}(${hours}h${mins}m)${RESET}"
        fi
      fi
    fi

    FIVE_HOUR_PART="${FIVE_COLOR}${FIVE_ICON} ${FIVE_BAR} ${five_pct}%${RESET}${TIME_LEFT}"
  fi

  # 7日リミット (サブカラー: ライトブルー)
  if [ -n "$seven_day" ]; then
    seven_pct=$(printf "%.0f" "$seven_day" 2>/dev/null)
    if [ "$seven_pct" -ge 80 ]; then
      SEVEN_COLOR="${RED}"; SEVEN_ICON="⚠"
    elif [ "$seven_pct" -ge 50 ]; then
      SEVEN_COLOR="${YELLOW}"; SEVEN_ICON="🎐"
    else
      SEVEN_COLOR="${LIGHT_BLUE}"; SEVEN_ICON="🎐"
    fi
    SEVEN_BAR=$(make_miku_bar "$seven_pct")
    SEVEN_DAY_PART="${SEVEN_COLOR}${SEVEN_ICON} 7d ${SEVEN_BAR} ${seven_pct}%${RESET}"
  fi
fi

# ── 出力 ─────────────────────────────────────────────────────
# 1行目: モデル & Git
printf '%s\n' "${MODEL_PART}${GIT_PART}"
# 2行目: コンテキスト
[ -n "$CTX_PART" ] && printf '%s\n' "$CTX_PART"
# 3行目: レートリミット (存在するものだけ & で繋ぐ)
RATE_LINE=""
[ -n "$FIVE_HOUR_PART" ] && RATE_LINE="$FIVE_HOUR_PART"
if [ -n "$SEVEN_DAY_PART" ]; then
  [ -n "$RATE_LINE" ] && RATE_LINE="${RATE_LINE}${SEP}${SEVEN_DAY_PART}" || RATE_LINE="$SEVEN_DAY_PART"
fi
[ -n "$RATE_LINE" ] && printf '%s\n' "$RATE_LINE"
exit 0

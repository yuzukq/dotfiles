function gitbranch --description 'Git branch switch: fuzzy search and checkout branch'
  if not git rev-parse --git-dir >/dev/null 2>&1
    echo "Not a git repository" >&2
    return 1
  end

  set -l selected (
    git branch -a \
    | grep -v HEAD \
    | fzf --preview 'set b (echo {} | sed "s/^[* ]*//; s|remotes/origin/||"); git log --oneline --graph --color=always --decorate -30 $b 2>/dev/null || echo "No commits found"' \
          --preview-window 'right:60%:wrap' \
          --header 'ENTER: switch branch'
  )

  test -z "$selected"; and return 0

  set -l branch (echo $selected | sed 's/^[* ]*//; s|remotes/origin/||' | string trim)
  git switch $branch 2>/dev/null
  or git switch --track origin/$branch
end

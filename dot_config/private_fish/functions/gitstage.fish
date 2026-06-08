function gitstage --description 'Git fuzzy add: select and stage files interactively'
  if not git rev-parse --git-dir >/dev/null 2>&1
    echo "Not a git repository" >&2
    return 1
  end

  git status --short \
  | fzf --multi \
        --preview 'git diff --color=always -- {2..} | grep -q "." && git diff --color=always -- {2..} || bat --color=always {2..} 2>/dev/null || cat {2..}' \
        --preview-window 'right:60%:wrap' \
        --bind 'tab:toggle+down' \
        --bind 'shift-tab:toggle+up' \
        --bind 'enter:execute-silent(for line in (printf "%s\n" {+}); set s (string sub -l 1 -- $line); set f (string sub -s 4 -- $line | string trim); if test "$s" = " " -o "$s" = "?"; git add -- $f; else; git restore --staged -- $f; end; end)+reload(git status --short)' \
        --header 'ENTER: stage/unstage  TAB: multi-select  ESC: done'
end

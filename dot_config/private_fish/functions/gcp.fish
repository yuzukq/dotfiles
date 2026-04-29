function gcp --description 'Grep & copy path: search files interactively and copy selected path to clipboard'
  rg --line-number --column --no-heading --color=always --smart-case "." \
    | fzf --ansi \
          --delimiter : \
          --preview 'bat --color=always --style=header,grid --highlight-line {2} {1}' \
          --preview-window 'right:60%:wrap' \
          --bind 'enter:become(echo -n {1} | pbcopy && echo "Copied: {1}")'
end

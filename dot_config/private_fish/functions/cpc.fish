function cpc --description 'Copy the full path of a file/dir (use tab completion) to the clipboard'
  if test (count $argv) -ne 1
    echo "Usage: cpc <file>" >&2
    return 1
  end

  set -l full_path (path resolve -- $argv[1])
  if test -z "$full_path"
    echo "cpc: no such file or directory: $argv[1]" >&2
    return 1
  end

  printf '%s' $full_path | pbcopy
  echo "Copied: $full_path"
end

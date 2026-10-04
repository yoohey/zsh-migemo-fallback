# Sets up the scene for demo.tape: a throwaway directory with Japanese names and a zsh that loads only
# compinit (with menu select) and this plugin, then replaces the current shell with it.
emulate -L zsh
local plugin=${${(%):-%x}:A:h:h}/zsh-migemo-fallback.plugin.zsh
local d=$(mktemp -d)
mkdir -p $d/home/資料/{ドキュメント,デスクトップ,議事録}
print -r -- '# 読書メモ' > $d/home/資料/読書メモ.md
print -r -- '# 定例会議' > $d/home/資料/議事録/定例会議.md
touch $d/home/資料/{設計ドキュメント.md,設計書.md}
print -r -- "PROMPT='%F{cyan}%~%f \$ '
autoload -Uz compinit && compinit -u -d ${(q)d}/zcompdump
zmodload zsh/complist; zstyle ':completion:*' menu select
alias ls='ls -F'
source ${(q)plugin}" > $d/home/.zshrc
cd $d/home/資料
exec env HOME=$d/home ZDOTDIR=$d/home LC_COLLATE=C zsh -d -i

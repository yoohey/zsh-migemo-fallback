#!/usr/bin/env zsh
# Tests for zsh-migemo-fallback: types keys into a real interactive zsh that loads only compinit and this plugin,
# and checks the command line. Needs cmigemo and its dictionary.
#
#   ./tests/run.zsh            (KEY_WAIT=0.5 ./tests/run.zsh to wait less between keys)
#
# run 'label' 'expected command line' key1 key2 ...
#   starts `zsh -d -i` (no global rc files) in $RUN_DIR with a .zshrc that runs $RUN_PRE, compinit, the plugin
#   and $RUN_POST, waits for the prompt, sends the keys one at a time (KEY_WAIT seconds apart: completion only
#   reacts when keys don't arrive all at once), then reads the command line ($BUFFER) through a widget bound to
#   Ctrl+X Ctrl+D. The expected value matches when it is the same text, or as a zsh pattern (* matches anything,
#   (a|b) either). Anything zsh printed that looks like an error makes the case NG too.
# check 'label' 'expected output' 'command'
#   runs the command in `zsh -d -c` after the same .zshrc, and compares everything it prints.
# Prints OK / NG per case; exits with the number of NG cases.

zmodload zsh/zpty || exit 1
emulate -L zsh
typeset -g KEY_WAIT=${KEY_WAIT:-1.0} RUN_PRE= RUN_POST= _ng=0
typeset -g PLUGIN=${0:A:h:h}/zsh-migemo-fallback.plugin.zsh
typeset -g TMP=$(mktemp -d) || exit 1
trap 'rm -rf -- $TMP' EXIT
# The same order of candidates everywhere (the collation of the locale decides it otherwise)
export LC_COLLATE=C

_write_zshrc() {
  mkdir -p $TMP/zdot
  print -r -- "PROMPT='P> '
$RUN_PRE
autoload -Uz compinit && compinit -u -d ${(q)TMP}/zdot/.zcompdump
source ${(q)PLUGIN}
$RUN_POST" > $TMP/zdot/.zshrc
}

run() {
  local label=$1 want=$2; shift 2
  local buf=$TMP/buf out= chunk k i
  : > $buf
  _write_zshrc
  zpty -b t "cd ${(q)RUN_DIR} && HOME=${(q)TMP}/home ZDOTDIR=${(q)TMP}/zdot TERM=xterm-256color zsh -d -i"
  zpty -w t "_t_dump() { print -r -- \"\$BUFFER\" > ${(q)buf} }; zle -N _t_dump; bindkey '^X^D' _t_dump"
  # Wait for the prompt after that line (up to 10 s), then for the line editor to settle
  for i in {1..100}; do
    zpty -r -t t chunk 2> /dev/null && out+=$chunk
    [[ $out == *'_t_dump'*'P> '* ]] && break
    sleep 0.1
  done
  sleep 0.3
  while zpty -r -t t chunk 2> /dev/null; do out+=$chunk; done
  # Read the screen output after each key: the macOS pty holds little, and a candidate list left unread there
  # stops zsh before it gets the next keys
  for k in "$@"; do
    zpty -w -n t "$k"; sleep $KEY_WAIT
    while zpty -r -t t chunk 2> /dev/null; do out+=$chunk; done
  done
  zpty -w -n t $'\C-x\C-d'; sleep 0.5
  while zpty -r -t t chunk 2> /dev/null; do out+=$chunk; done
  zpty -d t
  local got=$(<$buf)
  local err=$(print -r -- "$out" | tr -d '\r' | grep -a -o -E '(not found|no such|bad |error|failed|warning)[^`]{0,50}' | head -1)
  _result "$label" "$want" "$got" "$err"
}

check() {
  local label=$1 want=$2 cmd=$3
  _write_zshrc
  local got=$(cd $RUN_DIR && HOME=$TMP/home ZDOTDIR=$TMP/zdot zsh -d -c "source ${(q)TMP}/zdot/.zshrc; $cmd" 2>&1)
  _result "$label" "$want" "$got" ''
}

_result() {
  local label=$1 want=$2 got=$3 err=$4 mark
  if [[ ( $got == $want || $got == ${~want} ) && -z $err ]]; then mark='OK'; else mark='NG'; (( _ng++ )); fi
  print -r -- "$mark ${(r:48:)label} -> ${got}${err:+   !! $err}"
  [[ $mark == NG && $got != $want && $got != ${~want} ]] && print -r -- "   (expected: $want)"
  return 0
}

# Files and directories with Japanese names, in a throwaway directory (and a throwaway home)
typeset -g RUN_DIR=$TMP/files
mkdir -p $RUN_DIR/{ドキュメント,デスクトップ,議事録,'my dir'/ドキュメント,'br[1]'/ドキュメント,'~root'/ドキュメント}
touch $RUN_DIR/{設計ドキュメント.md,設計書.md,読書メモ.md,+α.txt,index.txt,readme.txt,議事録/定例会議.md}
touch $RUN_DIR/$'x\n読書メモの偽物.md'
mkdir -p $TMP/home/デスクトップ

# The normal completion is untouched
run 'cat rea<Tab>（普通の補完）'            'cat readme.txt '                'cat rea'$'\t'
run 'cat inde<Tab>（英字が見つかれば migemo は動かない）' 'cat index.txt '    'cat inde'$'\t'

# Romaji to Japanese names
run 'cd dokyu<Tab>'                          'cd ドキュメント/'                'cd dokyu'$'\t'
run 'cd document<Tab>（英語のつづり）'       'cd ドキュメント/'                'cd document'$'\t'
run 'cat doku<Tab>（漢字の読み）'            'cat 読書メモ.md '                'cat doku'$'\t'
run 'cat sekke<Tab>（候補が2つ: 1つ目）'     'cat 設計ドキュメント.md'         'cat sekke'$'\t'
run 'cat sekke<Tab><Tab>（Tab で次へ）'      'cat 設計書.md'                   'cat sekke'$'\t' $'\t'
run 'ls *dokyu<Tab>（途中にも合う）'         'ls (ドキュメント/|設計ドキュメント.md)*' 'ls *dokyu'$'\t'
run 'cat 議事録/teire<Tab>（フォルダーの中）' 'cat 議事録/定例会議.md '       'cat 議事録/teire'$'\t'
run 'ls ~/desu<Tab>（~ で始まるパス）'       'ls ~/デスクトップ/'              'ls ~/desu'$'\t'
run 'cd my\ dir/dokyu<Tab>（空白入り）'      'cd my\ dir/ドキュメント/'        'cd my\ dir/dokyu'$'\t'
run "cd 'my dir/dokyu<Tab>（引用符の中）"    "cd 'my dir/ドキュメント/"        "cd 'my dir/dokyu"$'\t'
run 'cd br\[1\]/dokyu<Tab>（[] 入り）'       'cd br\[1\]/ドキュメント/'        'cd br\[1\]/dokyu'$'\t'
run 'cd \~root/dokyu<Tab>（名前の ~ は展開しない）' 'cd \~root/ドキュメント/'  'cd \~root/dokyu'$'\t'
run 'cat ~nouser/dokyu<Tab>（エラーを出さない）' 'cat ~nouser/dokyu'          'cat ~nouser/dokyu'$'\t'
run 'cat --file=doku<Tab>（= の後ろ）'       'cat --file=読書メモ.md '         'cat --file=doku'$'\t'
run 'sudo rmdir giji<Tab>（sudo の後ろ）'    'sudo rmdir 議事録/'              'sudo rmdir giji'$'\t'
run 'pushd giji<Tab>'                        'pushd 議事録/'                   'pushd giji'$'\t'
run 'cd sekke<Tab>（cd ではファイルを出さない）' 'cd sekke'                    'cd sekke'$'\t'
run 'cat pl<Tab>（辞書の + でエラーにならない）' 'cat +α.txt '                'cat pl'$'\t'
run 'cat mu<Tab>（辞書の {} でエラーにならない）' 'cat mu'                     'cat mu'$'\t'
run 'cat dokush<Tab>（改行入りの名前は出さない）' 'cat 読書メモ.md '           'cat dokush'$'\t'
run 'dokyu<Tab>（コマンドの位置では動かない）' 'dokyu'                        'dokyu'$'\t'
run 'cat d<Tab>（1文字では動かない）'         'cat d'                          'cat d'$'\t'
RUN_PRE='zmodload zsh/complist; zstyle ":completion:*" menu select'
run 'cat sekke<Tab><Tab>（menu select）'      'cat 設計書.md*'                  'cat sekke'$'\t' $'\t'
RUN_PRE="zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'"
run 'cd dokyu<Tab>（matcher-list があるとき）' 'cd ドキュメント/'               'cd dokyu'$'\t'
RUN_PRE='export LC_ALL=C'
run 'cat doku<Tab>（UTF-8 でなければ動かない）' 'cat doku'                     'cat doku'$'\t'
RUN_PRE='setopt ksharrays shwordsplit'
run 'cd dokyu<Tab>（ksharrays などで読み込んでも）' 'cd ドキュメント/'          'cd dokyu'$'\t'
RUN_PRE='path=(); hash -r' RUN_POST="zstyle ':completion:*' completer _complete _migemo_fallback"
run 'cmigemo が無くて completer に書いてあるとき' 'cat dokyu'                  'cat dokyu'$'\t'
RUN_PRE= RUN_POST=

# The completers: added at the end, the user's own ones kept, only once
_completers='zstyle -L ":completion:*" completer | sed "s/.* completer //"'
check '補完の方法（既定）'                    '_complete _ignored _migemo_fallback' $_completers
RUN_PRE="zstyle ':completion:*' completer _expand _complete _approximate"
check '補完の方法（自分の設定の後ろに足す）'  '_expand _complete _approximate _migemo_fallback' $_completers
RUN_PRE="setopt ksharrays; zstyle ':completion:*' completer _expand _complete _ignored"
check '補完の方法（ksharrays でも壊さない）'  '_expand _complete _ignored _migemo_fallback' $_completers
RUN_PRE= RUN_POST="source ${(q)PLUGIN}"
check '補完の方法（2回読んでも1つ）'          '_complete _ignored _migemo_fallback' $_completers
RUN_POST=
RUN_PRE='path=(); hash -r'
check 'cmigemo が無いとき（何も足さない・出さない）' 'none' \
  'zstyle -L ":completion:*" completer || print none'

# The dictionary
cp -- "$(zsh -d -c "source ${(q)PLUGIN}; print -r -- \$_migemo_fallback_dict")" "$TMP/my dict"
RUN_PRE="ZSH_MIGEMO_FALLBACK_DICT=${(q)TMP}/my\\ dict; setopt shwordsplit"
check '辞書を指定（空白入りのパスでも）'      "$TMP/my dict" 'print -r -- $_migemo_fallback_dict'
RUN_PRE='ZSH_MIGEMO_FALLBACK_DICT=/nonexistent'
check '辞書を指定（無ければ既定の場所を探す）' '*/migemo-dict' 'print -r -- $_migemo_fallback_dict'
RUN_PRE=

print -r -- "--- NG: $_ng"
exit $_ng

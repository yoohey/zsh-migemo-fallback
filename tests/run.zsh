#!/usr/bin/env zsh
# Tests for zsh-migemo-fallback: types keys into a real interactive zsh that loads only compinit and this plugin,
# and checks the command line. Needs cmigemo and its dictionary.
#
#   ./tests/run.zsh            (KEY_WAIT=0.5 ./tests/run.zsh to wait less between keys)
#
# run 'label' 'expected command line' key1 key2 ...
#   starts `zsh -d -i` (no global rc files) in $RUN_DIR with a .zshrc that runs $RUN_PRE, compinit, the plugin
#   and $RUN_POST, sends the keys one at a time (KEY_WAIT seconds apart: completion only reacts when keys don't
#   arrive all at once), then reads the command line ($BUFFER) through a widget bound to Ctrl+X Ctrl+D.
#   The expected value matches when it is the same text, or as a zsh pattern (* matches anything, (a|b) either).
# check 'label' 'expected output' 'command'
#   runs the command in `zsh -d -c` after the same .zshrc, and compares what it prints.
# Prints OK / NG per case (and errors zsh printed, like "failed to compile regex"); exits with the number of NG.

zmodload zsh/zpty || exit 1
emulate -L zsh
typeset -g KEY_WAIT=${KEY_WAIT:-1.0} RUN_PRE= RUN_POST= _ng=0
typeset -g PLUGIN=${0:A:h:h}/zsh-migemo-fallback.plugin.zsh
typeset -g TMP=$(mktemp -d) || exit 1
trap 'rm -rf -- $TMP' EXIT

_write_zshrc() {
  mkdir -p $TMP/zdot
  print -r -- "PROMPT='P> '
$RUN_PRE
autoload -Uz compinit && compinit -u -d $TMP/zdot/.zcompdump
source ${(q)PLUGIN}
$RUN_POST" > $TMP/zdot/.zshrc
}

run() {
  local label=$1 want=$2; shift 2
  local buf=$TMP/buf out= chunk k
  : > $buf
  _write_zshrc
  zpty -b t "cd ${(q)RUN_DIR} && ZDOTDIR=$TMP/zdot TERM=xterm-256color zsh -d -i"
  zpty -w t "_t_dump() { print -r -- \"\$BUFFER\" > ${(q)buf} }; zle -N _t_dump; bindkey '^X^D' _t_dump"
  sleep 1
  while zpty -r -t t chunk 2> /dev/null; do :; done
  for k in "$@"; do zpty -w -n t "$k"; sleep $KEY_WAIT; done
  zpty -w -n t $'\C-x\C-d'; sleep 0.5
  while zpty -r -t t chunk 2> /dev/null; do out+=$chunk; done
  zpty -d t
  local got=$(<$buf)
  local err=$(print -r -- "$out" | tr -d '\r' | grep -a -o -E '(failed to compile|command not found|grep:|parse error|no such)[^`]{0,50}' | head -1)
  _result "$label" "$want" "$got" "$err"
}

check() {
  local label=$1 want=$2 cmd=$3
  _write_zshrc
  local got=$(cd $RUN_DIR && ZDOTDIR=$TMP/zdot zsh -d -c "source $TMP/zdot/.zshrc; $cmd" 2>&1)
  _result "$label" "$want" "$got" ''
}

_result() {
  local label=$1 want=$2 got=$3 err=$4 mark
  if [[ ( $got == $want || $got == ${~want} ) && -z $err ]]; then mark='OK'; else mark='NG'; (( _ng++ )); fi
  print -r -- "$mark ${(r:44:)label} -> ${got}${err:+   !! $err}"
  [[ $mark == NG && $got != $want && $got != ${~want} ]] && print -r -- "   (expected: $want)"
  return 0
}

# Files and directories with Japanese names, in a throwaway directory
typeset -g RUN_DIR=$TMP/files
mkdir -p $RUN_DIR/{山の写真,山川,都道府県,'my dir'/山田,'br[1]'/山本}
touch $RUN_DIR/{山形県.txt,岡山県.txt,村上.txt,実行.txt,やまびこ.md,readme.txt,都道府県/東京都.txt}

# The normal completion is untouched
run 'cat rea<Tab>（普通の補完）'          'cat readme.txt '            'cat rea'$'\t'

# Romaji to Japanese names
run 'cd yama<Tab>（フォルダーだけ）'       'cd 山(の写真|川)/'          'cd yama'$'\t'
run 'cat yama<Tab>（ファイルも）'          'cat (山*|やまびこ.md)*'     'cat yama'$'\t'
run 'cat todo<Tab>'                       'cat 都道府県/'              'cat todo'$'\t'
run 'cat 都道府県/touk<Tab>（フォルダーの中）' 'cat 都道府県/東京都.txt ' 'cat 都道府県/touk'$'\t'
run 'cat *yama<Tab>（途中にも合う）'       'cat (山形県|岡山県).txt*'  'cat *yama'$'\t'
run 'cd my\ dir/ya<Tab>（空白入りのフォルダー）' 'cd my\ dir/山田/'     'cd my\ dir/ya'$'\t'
run 'cd br\[1\]/ya<Tab>（[] 入りのフォルダー）'  'cd br\[1\]/山本/'     'cd br\[1\]/ya'$'\t'
run 'cat mu<Tab>（{} のエラーが出ない）'   'cat 村上.txt '              'cat mu'$'\t'
run 'cat ji<Tab>'                         'cat 実行.txt '              'cat ji'$'\t'
run 'sudo rmdir yama<Tab>'                'sudo rmdir 山(の写真|川)/'  'sudo rmdir yama'$'\t'
run 'cat --file=yama<Tab>（= の後ろ）'     'cat --file=(山*|やまびこ.md)*' 'cat --file=yama'$'\t'
mkdir -p $TMP/home/資料
RUN_PRE="HOME=$TMP/home"
run 'ls ~/shi<Tab>（~ で始まるパス）'      'ls ~/資料/'                 'ls ~/shi'$'\t'
RUN_PRE=
run 'yama<Tab>（コマンドの位置では動かない）' 'yama'                    'yama'$'\t'
run 'cat y<Tab>（1文字では動かない）'      'cat y'                      'cat y'$'\t'

# The completers: added at the end, the user's own ones kept, only once
check '補完の方法（既定）'               '_complete _ignored _migemo_fallback' \
  'zstyle -L ":completion:*" completer | sed "s/.* completer //"'
RUN_PRE="zstyle ':completion:*' completer _expand _complete _approximate"
check '補完の方法（自分の設定の後ろに足す）' '_expand _complete _approximate _migemo_fallback' \
  'zstyle -L ":completion:*" completer | sed "s/.* completer //"'
RUN_PRE= RUN_POST="source ${(q)PLUGIN}"
check '補完の方法（2回読んでも1つ）'      '_complete _ignored _migemo_fallback' \
  'zstyle -L ":completion:*" completer | sed "s/.* completer //"'
RUN_POST=

# Without cmigemo: nothing happens, nothing is printed
RUN_PRE='path=(${path:#*brew*}); hash -r; (( $+commands[cmigemo] )) && print still-found'
check 'cmigemo が無いとき（何も出さない）' 'none' \
  'zstyle -L ":completion:*" completer || print none'
RUN_PRE='ZSH_MIGEMO_FALLBACK_DICT=/nonexistent'
check '辞書を指定（無ければ既定の場所を探す）' '_complete _ignored _migemo_fallback' \
  'zstyle -L ":completion:*" completer | sed "s/.* completer //"'
RUN_PRE=

print -r -- "--- NG: $_ng"
exit $_ng

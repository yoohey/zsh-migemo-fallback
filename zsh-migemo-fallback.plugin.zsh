# zsh-migemo-fallback - complete Japanese file and directory names from romaji with migemo (cmigemo).
#
# `cd dokyu<Tab>` offers ドキュメント/, `cat doku<Tab>` 読書メモ.md, ...; `ls *dokyu<Tab>` matches anywhere in the
# name (設計ドキュメント.md). Added as the last completer, so it only runs (one cmigemo call, about 0.1 s) when the
# normal completion found nothing; its candidates then go into the usual completion menu.
#
# Needs cmigemo and its dictionary (Homebrew: brew install cmigemo / Debian, Ubuntu: apt install cmigemo).
# Set ZSH_MIGEMO_FALLBACK_DICT before loading this file to use a dictionary somewhere else.
# Without cmigemo or the dictionary, it adds nothing and prints nothing (the function is still defined, so a
# completer list that names _migemo_fallback works on such machines too).
#
# https://github.com/yoohey/zsh-migemo-fallback - MIT License

_migemo_fallback() {
  [[ -n ${_migemo_fallback_cmd:-} ]] || return 1
  setopt localoptions extendedglob
  local MATCH MBEGIN MEND

  # Only for arguments (not the command name itself), and only on the first pass: _main_complete calls the
  # completers once per matcher-list entry, and with -U below the matcher makes no difference.
  (( CURRENT > 1 && ${_matcher_num:-1} == 1 )) || return 1

  # Japanese character classes in the regex only work when grep reads the names as UTF-8
  zmodload -F zsh/langinfo p:langinfo 2> /dev/null
  [[ ${langinfo[CODESET]:-} == (UTF-8|utf8) ]] || return 1

  # After --option= or VAR=, complete the value
  compset -P '*='

  # PREFIX is the word as typed (with its quoting, e.g. my\ dir/). The directory part stays in the command
  # line as typed (compset moves it to IPREFIX); unquoted, it is the directory to look in.
  # ~ and ~name at the start count only when typed as such (not \~ from a directory name, not inside quotes),
  # and are looked up as a home or named directory, never expanded as a pattern or a dynamic name (~[...]).
  local dir= base anywhere=0 tilde=0 tname=
  if [[ -z ${compstate[quote]} && $PREFIX == \~[[:alnum:]_.-]#/* ]]; then
    tilde=1 tname=${${PREFIX%%/*}#\~}
  fi
  if [[ $PREFIX == */* ]]; then
    dir=${(Q)PREFIX%/*}/
    compset -P '*/'
  fi
  if (( tilde )); then
    zmodload -F zsh/parameter p:nameddirs p:userdirs
    if [[ -z $tname ]]; then dir=$HOME/${dir#*/}
    elif [[ -n ${nameddirs[$tname]:-} ]]; then dir=${nameddirs[$tname]}/${dir#*/}
    elif [[ -n ${userdirs[$tname]:-} ]]; then dir=${userdirs[$tname]}/${dir#*/}
    else return 1
    fi
  fi
  base=${(Q)PREFIX}
  [[ $base == \** ]] && { anywhere=1; base=${base#\*} }
  # Only plain romaji (at least 2 letters, so a single letter doesn't list half the directory)
  [[ $base == [a-zA-Z][a-zA-Z0-9-]## ]] || return 1

  local re
  re=$($_migemo_fallback_cmd -q -d $_migemo_fallback_dict -w $base 2> /dev/null) || return 1
  [[ -n $re ]] || return 1
  # cmigemo only uses ( | ) [ ] as operators and escapes . $ \ itself, but leaves { } + * ? from the dictionary
  # as they are (words like k$_{inf}$, +α, C++): GNU grep shrugs at some of them, BSD grep (macOS) rejects them.
  re=${re//(#m)[{}+*?]/\\$MATCH}
  (( anywhere )) || re="^($re)"

  # Directories only for cd-like commands (looking past sudo, builtin, VAR=value, ...), otherwise files and
  # directories. Hidden ones are not offered (romaji can't start with a dot).
  local -a cmd names matched
  cmd=( ${words[1,CURRENT-1]} )
  while [[ ${cmd[1]} == *=* || ${cmd[1]} == (sudo|builtin|command|noglob|nocorrect|exec|env) ]]; do
    cmd=( ${cmd[2,-1]} )
  done
  local qual='N'
  [[ ${cmd[1]} == (cd|pushd|rmdir) ]] && qual='N/'
  names=( "${dir:-./}"*(${qual}:t) )
  # One name per line for grep: names with a newline in them are left out
  names=( ${names:#*$'\n'*} )
  (( $#names )) || return 1

  # One grep over all the names: [[ =~ ]] compiles the long regex again for every name (1.4 s for 5000 names,
  # against 5 ms here).
  matched=( ${(f)"$(print -rl -- $names | command grep -E -- "$re" 2> /dev/null)"} )
  (( $#matched )) || return 1

  # -U: the candidates don't start with what was typed (romaji), so don't filter them by it. -U would also replace
  # the directory part typed before (IPREFIX), so give it back with -i. -f: file names (quoted as needed, / after
  # directories, checked in the directory given with -W).
  local expl
  _wanted files expl 'migemo' compadd -U -i "$IPREFIX" -f -W "${dir:-./}" -a matched || return 1
  # With -U, zsh would insert only what all candidates share at the start: nothing, so the romaji typed would
  # just disappear. Go straight into the menu instead (the first candidate, Tab for the next).
  (( $#matched > 1 )) && compstate[insert]=menu
  return 0
}

# Find cmigemo and its dictionary; only then add the completer after the ones already set (zsh's default is
# _complete _ignored), keeping the user's own ones. A completer line in .zshrc after this file is loaded
# replaces the list: add _migemo_fallback at its end there.
() {
  emulate -L zsh
  typeset -g _migemo_fallback_cmd= _migemo_fallback_dict=
  (( $+commands[cmigemo] )) || return 0
  local d
  # Next to cmigemo first (Homebrew, MacPorts, /usr/local), then where the Debian/Ubuntu package puts it
  for d in ${ZSH_MIGEMO_FALLBACK_DICT:-} \
           ${commands[cmigemo]:A:h:h}/share/migemo/utf-8/migemo-dict \
           /usr/share/cmigemo/utf-8/migemo-dict /usr/share/migemo/utf-8/migemo-dict; do
    [[ -r $d ]] && { _migemo_fallback_dict=$d; break }
  done
  [[ -n $_migemo_fallback_dict ]] || return 0
  _migemo_fallback_cmd=${commands[cmigemo]}

  local -a completers
  zstyle -a ':completion:*' completer completers || completers=(_complete _ignored)
  (( ${completers[(I)_migemo_fallback]} )) || zstyle ':completion:*' completer $completers _migemo_fallback
}

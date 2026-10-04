# zsh-migemo-fallback

Complete Japanese file and directory names from romaji in zsh, with [migemo](https://github.com/koron/cmigemo) — only when the normal completion finds nothing.

zsh で、日本語のファイル名・フォルダー名を、ローマ字のまま `Tab` で補完するプラグインです。

```
$ ls
ドキュメント/  デスクトップ/  議事録/  設計ドキュメント.md  設計書.md  読書メモ.md
$ cd dokyu<Tab>       → cd ドキュメント/
$ cd document<Tab>    → cd ドキュメント/（英語のつづりでも合う語がある）
$ ls *dokyu<Tab>      → ドキュメント/ と 設計ドキュメント.md が候補に（名前の途中にあるものも）
$ cat doku<Tab>       → cat 読書メモ.md（漢字も読みで合う）
$ cat 議事録/teire<Tab> → cat 議事録/定例会議.md
```

![デモ: cd dokyu、cat doku、ls *dokyu、cat 議事録/teire を Tab で補完する様子](demo/demo.gif)

日本語入力に切り替えずに、ローマ字のまま日本語の名前を補完できます。たとえば WSL から Windows 側の日本語の名前のフォルダーに入るときや、日本語の名前の資料がたくさんあるフォルダーで使えます。

## 特徴

- **普通の補完を邪魔しない**: zsh の補完の方法（completer）の最後に1つ足すだけです。普通の補完で何も見つからなかったときだけ動きます。英字の名前の補完は、今までとまったく同じです。
- **いつもの補完の一覧で選べる**: 候補は、zsh の普通の補完の一覧に出ます。一覧の中の操作（`Tab` で次へ、`menu select` など）も、そのまま使えます。
- **漢字の読みが複数あっても合う**: migemo の辞書で、ローマ字を「日本語にも合う正規表現」に変えて比べます。「読」なら `doku`（読書）でも `yomi`（読み）でも合います。
- **名前の途中にも合う**: `*dokyu` のように先頭に `*` を付けると、名前の途中に合うものも出ます（`設計ドキュメント.md` など）。
- **zsh のスクリプトだけ**: ほかに要るのは `cmigemo` だけです。`brew` や `apt` で入ります。

### 似たもの

同じ「ローマ字で日本語の名前を補完する」ものに、次のものがあります。作りが違うので、合うほうを選んでください。

- [aoyama-val/zsh-romaji-complete](https://github.com/aoyama-val/zsh-romaji-complete): kakasi でファイル名をローマ字に変えて比べる zsh プラグインです。
- [hata48915b/sazae](https://github.com/hata48915b/sazae): migemo を使った補完です（Python）。
- [nekowasabi/zsh-migemo-completion](https://github.com/nekowasabi/zsh-migemo-completion): sazae を参考にした Go の実装です（辞書を中に入れた1つのプログラム。`fzf` などにつなぐ使い方もできます）。

## 必要なもの

- zsh と、補完のしくみ（`compinit`）
- `cmigemo` と、その辞書
  - Mac（Homebrew）: `brew install cmigemo`
  - Debian・Ubuntu: `sudo apt install cmigemo`
- 文字コードが UTF-8 の環境（`LANG=ja_JP.UTF-8` など）

辞書は、`cmigemo` の隣（`<cmigemo の場所>/../share/migemo/utf-8/migemo-dict`）、`/usr/share/cmigemo/utf-8/migemo-dict`、`/usr/share/migemo/utf-8/migemo-dict` の順に探します。ほかの場所にあるときは、読み込む前に `ZSH_MIGEMO_FALLBACK_DICT` で指定してください。

```zsh
ZSH_MIGEMO_FALLBACK_DICT=/path/to/migemo-dict
```

`cmigemo` か辞書が見つからないときは、何もしません（エラーも出しません）。`.zshrc` を、cmigemo の無いマシンと共有していても大丈夫です。

確かめた環境: Ubuntu 24.04（WSL2）、zsh 5.9、Homebrew の cmigemo。Mac ではまだ試していません。

## 入れ方

### 手で入れる

```zsh
git clone https://github.com/yoohey/zsh-migemo-fallback ~/.zsh/zsh-migemo-fallback
```

`.zshrc` に1行足します（`compinit` の前でも後でもかまいません）。

```zsh
source ~/.zsh/zsh-migemo-fallback/zsh-migemo-fallback.plugin.zsh
```

### プラグインの管理ツール

ふつうのプラグインと同じように読み込めるはずです（作者はまだ試していません）。

```zsh
# zinit
zinit light yoohey/zsh-migemo-fallback

# sheldon（plugins.toml）
# [plugins.zsh-migemo-fallback]
# github = "yoohey/zsh-migemo-fallback"
```

Oh My Zsh なら、`$ZSH_CUSTOM/plugins/zsh-migemo-fallback` に clone して、`plugins=(... zsh-migemo-fallback)` に足します。

### 補完の方法（completer）を自分で設定しているとき

このプラグインは、読み込んだ時点の `zstyle ':completion:*' completer` の最後に `_migemo_fallback` を足します（設定が無ければ、zsh の既定の `_complete _ignored` の後ろに）。

次のときは、このプラグインが足した設定が使われないので、自分の completer の行の最後に `_migemo_fallback` を足してください。

- `.zshrc` で、このプラグインを読み込んだ**あとに** completer の行を書いている
- `':completion:*'` 以外の書き方（`':completion:::::'` など）で completer を設定している

```zsh
zstyle ':completion:*' completer _expand _complete _ignored _migemo_fallback
```

## 使い方

| 打つもの | 候補 |
|---|---|
| `cd dokyu<Tab>` | 「ドキュメント」などで始まるフォルダー（`cd`・`pushd`・`rmdir` ではフォルダーだけ） |
| `cat sekke<Tab>` | 「設計」などで始まるファイルとフォルダー。候補が複数なら1つ目が入り、`Tab` で次へ |
| `ls *dokyu<Tab>` | 名前の途中に「ドキュメント」などがあるもの（`設計ドキュメント.md` も） |
| `cat 議事録/teire<Tab>` | フォルダーの中も（フォルダーは1段ずつ補完します） |
| `ls ~/desu<Tab>` | `~`・`~ユーザー名` で始まるパスも（`~/デスクトップ/`） |
| `sudo rmdir giji<Tab>`、`--file=doku<Tab>` | `sudo` などの後ろや、`=` の後ろも |

## 制限

- **英字の候補が見つかると、日本語の候補は出ません**: 普通の補完で何か見つかったときは動かないためです（`index` と `インデックス` があると、`inde<Tab>` は `index`、`indek<Tab>` で `インデックス`）。`_approximate`・`_correct` など、似た名前を探す completer が前にあって何か見つけたときも同じです。
- **ファイルを補完しないコマンドでも動きます**: 普通の補完が何も見つけなければ、どのコマンドでも動くので、`ssh doku<Tab>` でも `読書メモ.md` が出ることがあります。
- ローマ字は2文字以上です（1文字だと、フォルダーの半分くらいが候補になるため）。英字・数字・`-` だけのときに動きます。
- 行の先頭（コマンドの名前の位置）では動きません。
- 隠しファイル（`.` で始まるもの）と、名前に改行が入っているものは、候補に出しません。
- `$HOME/...` のように `$変数` で始まるパスでは動きません（`~/...` は動きます）。`cd` で `CDPATH` の中は探しません。
- 読み飛ばすのは `sudo`・`env`・`command` などの名前と `VAR=値` だけで、`sudo -u user` のようなオプションの付いた形は読み飛ばしません。
- 文字コードが UTF-8 でないとき（`LANG=C` など）は動きません（日本語の文字を正しく比べられないため）。
- `Tab` のたびに `cmigemo` を1回動かします（約0.1秒。ほとんどは辞書を読み込む時間）。普通の補完で見つかったときは動かないので、ふだんの補完は遅くなりません。

## しくみ

1. 普通の補完（`_complete`）で何も見つからないと、zsh が最後の補完の方法として `_migemo_fallback` を呼びます。
2. 打ったローマ字を `cmigemo -w` で正規表現に変えます（`dokyu` → `(ドキュ|どきゅ|...)` のようなもの）。
3. そのフォルダーの名前の一覧を、`grep -E` で1回で比べます。
4. 合った名前を、`compadd -U` で候補にします（打ったローマ字で候補を絞らないように）。候補が複数のときは、打ったローマ字が消えないように、すぐ一覧に入ります。

cmigemo の出力には、辞書の語から来る `{`・`}`・`+`・`*`・`?` がそのまま入ることがあり（`mu`・`pl` など）、そのままでは正規表現として読めなかったり、意味が変わったりします。そのため、`\` を付けて文字として扱ってから使っています。

## 試験

本物の zsh（`compinit` とこのプラグインだけを読み込んだもの）にキーを送って、行の中身を確かめます。`cmigemo` が要ります（約1分半）。

```zsh
./tests/run.zsh
```

## デモの GIF の作り直し

[VHS](https://github.com/charmbracelet/vhs) で、台本（`demo/demo.tape`）から作っています。リポジトリの一番上で次を実行すると、`demo/demo.gif` を作り直せます（VHS、cmigemo、フォント UDEV Gothic NF が要ります）。録画には、一時フォルダーに作った日本語の名前のファイルと、このプラグインだけを読み込んだ zsh を使います（`demo/setup.zsh`）。

```zsh
vhs demo/demo.tape
```

## ライセンス

MIT License（[LICENSE](LICENSE)）

# zsh-migemo-fallback

Complete Japanese file and directory names from romaji in zsh, with [migemo](https://github.com/koron/cmigemo) — only when the normal completion finds nothing.

zsh で、日本語のファイル名・フォルダー名を、ローマ字のまま `Tab` で補完するプラグインです。

```
$ ls
やまびこ.md  山の写真/  山形県.txt  岡山県.txt  都道府県/
$ cd yama<Tab>        → cd 山の写真/
$ cat *yama<Tab>      → cat 山形県.txt（名前の途中に「山」があるものも。Tab で次の候補へ）
$ cat todo<Tab>       → cat 都道府県/
```

日本語入力に切り替えずに、ローマ字のまま日本語の名前を補完できます。

## 特徴

- **普通の補完を邪魔しない**: zsh の補完の方法（completer）の最後に1つ足すだけです。普通の補完で何も見つからなかったときだけ動きます。英字の名前の補完は、今までとまったく同じです。
- **いつもの補完の一覧で選べる**: 候補は、zsh の普通の補完の一覧に出ます。一覧の中の操作（`Tab` で次へ、`menu select` など）も、そのまま使えます。
- **漢字の読みが複数あっても合う**: migemo の辞書で、ローマ字を「日本語にも合う正規表現」に変えて比べます。「山」なら `yama` でも `san` でも合います。
- **名前の途中にも合う**: `*yama` のように先頭に `*` を付けると、名前の途中に合うものも出ます（`岡山県.txt` など）。
- **zsh のスクリプトだけ**: ほかに要るのは `cmigemo` だけです。`brew` や `apt` で入ります。

### 似たもの

同じ「ローマ字で日本語の名前を補完する」ものに、次のものがあります。作りが違うので、合うほうを選んでください。

- [aoyama-val/zsh-romaji-complete](https://github.com/aoyama-val/zsh-romaji-complete): kakasi でファイル名をローマ字に変えて比べる zsh プラグインです。
- [hata48915b/sazae](https://github.com/hata48915b/sazae): migemo を使った補完です（Python）。
- [nekowasabi/zsh-migemo-completion](https://github.com/nekowasabi/zsh-migemo-completion): sazae を参考にした Go の実装です（辞書を中に入れた1つのプログラム。`fzf` などにつなぐ使い方もできます）。

## 必要なもの

- zsh（5.9 で確かめています）と、補完のしくみ（`compinit`）
- `cmigemo` と、その辞書
  - Mac（Homebrew）: `brew install cmigemo`
  - Debian・Ubuntu: `sudo apt install cmigemo`

辞書は、`cmigemo` の隣（`<cmigemo の場所>/../share/migemo/utf-8/migemo-dict`）と、Debian・Ubuntu の場所（`/usr/share/cmigemo/utf-8/migemo-dict`）から探します。ほかの場所にあるときは、読み込む前に `ZSH_MIGEMO_FALLBACK_DICT` で指定してください。

```zsh
ZSH_MIGEMO_FALLBACK_DICT=/path/to/migemo-dict
```

`cmigemo` か辞書が見つからないときは、何もしません（エラーも出しません）。

## 入れ方

### 手で入れる

```zsh
git clone https://github.com/yoohey/zsh-migemo-fallback ~/.zsh/zsh-migemo-fallback
```

`.zshrc` に1行足します。

```zsh
source ~/.zsh/zsh-migemo-fallback/zsh-migemo-fallback.plugin.zsh
```

### プラグインの管理ツール

```zsh
# zinit
zinit light yoohey/zsh-migemo-fallback

# sheldon（plugins.toml）
# [plugins.zsh-migemo-fallback]
# github = "yoohey/zsh-migemo-fallback"
```

Oh My Zsh なら、`$ZSH_CUSTOM/plugins/zsh-migemo-fallback` に clone して、`plugins=(... zsh-migemo-fallback)` に足します。

### 補完の方法（completer）を自分で設定しているとき

このプラグインは、読み込んだ時点の補完の方法の最後に `_migemo_fallback` を足します（設定が無ければ、zsh の既定の `_complete _ignored` の後ろに）。

`.zshrc` で、このプラグインを読み込んだ**あとに** `zstyle ':completion:*' completer ...` を書いていると、その行で置き換わって、このプラグインは動きません。その場合は、その行の最後に `_migemo_fallback` を足してください。

```zsh
zstyle ':completion:*' completer _expand _complete _ignored _migemo_fallback
```

## 使い方

| 打つもの | 候補 |
|---|---|
| `cd yama<Tab>` | 「山」「やま」「ヤマ」などで始まるフォルダー（`cd`・`pushd`・`rmdir` ではフォルダーだけ） |
| `cat yama<Tab>` | 同じく、ファイルとフォルダー。候補が複数なら1つ目が入り、`Tab` で次へ |
| `cat *yama<Tab>` | 名前の途中に「山」などがあるもの（`岡山県.txt` も） |
| `cat 都道府県/touk<Tab>` | フォルダーの中も（フォルダーは1段ずつ補完します） |
| `ls ~/doc/shiryo<Tab>` | `~` で始まるパスも |
| `sudo rmdir yama<Tab>`、`--file=yama<Tab>` | `sudo` などの後ろや、`=` の後ろも |

## 制限

- **英字の候補が見つかると、日本語の候補は出ません**: 普通の補完で何か見つかったときは動かないためです（`index` と `インデックス` があると、`inde<Tab>` は `index`、`indek<Tab>` で `インデックス`）。
- ローマ字は2文字以上です（1文字だと、フォルダーの半分くらいが候補になるため）。英字・数字・`-` だけのときに動きます。
- 行の先頭（コマンドの名前の位置）では動きません。
- 隠しファイル（`.` で始まるもの）は候補に出しません。
- `Tab` のたびに `cmigemo` を1回動かします（約0.1秒。ほとんどは辞書を読み込む時間）。普通の補完で見つかったときは動かないので、ふだんの補完は遅くなりません。

## しくみ

1. 普通の補完（`_complete`）で何も見つからないと、zsh が最後の補完の方法として `_migemo_fallback` を呼びます。
2. 打ったローマ字を `cmigemo -w` で正規表現に変えます（`yama` → `(山|やま|ヤマ|...)` のようなもの）。
3. そのフォルダーの名前の一覧を、`grep -E` で1回で比べます。
4. 合った名前を、`compadd -U` で候補にします（打ったローマ字で候補を絞らないように）。候補が複数のときは、打ったローマ字が消えないように、すぐ一覧に入ります。

cmigemo の出力には、辞書の語から来る `{`・`}` がそのまま入ることがあり（`mu`・`ji` など）、そのままでは正規表現として読めないので、`\{`・`\}` に直してから使っています。

## 試験

本物の zsh（`compinit` とこのプラグインだけを読み込んだもの）にキーを送って、行の中身を確かめます。`cmigemo` が要ります。

```zsh
./tests/run.zsh
```

## ライセンス

MIT License（[LICENSE](LICENSE)）

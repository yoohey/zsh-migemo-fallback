# The README's demo GIF. Run from the repository's top: vhs demo/demo.tape (needs vhs, cmigemo and the font)
Output demo/demo.gif

Set Shell "zsh"
Set FontFamily "UDEV Gothic NF"
Set FontSize 22
Set Width 1000
Set Height 480
Set Padding 20
Set Theme "nord"
Set TypingSpeed 90ms

Hide
Type "source demo/setup.zsh" Enter
Sleep 2s
Ctrl+L
Show

Type "ls" Sleep 400ms Enter
Sleep 1.5s

# cd dokyu<Tab>: ドキュメント
Type "cd dokyu" Sleep 800ms Tab Sleep 1.2s Enter
Sleep 1s
Type "cd .." Enter
Sleep 800ms

# cat doku<Tab>: 読書メモ.md (the kanji by its reading)
Type "cat doku" Sleep 800ms Tab Sleep 1.2s Enter
Sleep 1.5s

# ls *dokyu<Tab>: anywhere in the name; Tab for the next one
Type "ls *dokyu" Sleep 800ms Tab Sleep 1.2s Tab Sleep 1.2s Enter Sleep 300ms Enter
Sleep 1.5s

# Inside a directory
Type "cat 議事録/teire" Sleep 800ms Tab Sleep 1.2s Enter
Sleep 2.5s

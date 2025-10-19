# Textedit

> [!CAUTION]
> This is *very* WIP, it may be unstable, and you may lose your modifications. Your mileage may vary.

This is a very basic terminal text editor written in D.
Currently it does very, *very* basic syntax highlighting for `.d` files.

Currently tested on Linux and Windows.

The code is not the best quality, nor is it the most readable, but
I will be working on improving that.

# Usage
Use the arrow keys to move the cursor, Ctrl+Q to quit.
Use Ctrl+arrow keys to switch between open buffers
Ctrl+P brings up the command palette, in which you can type commands staring with ':'.
To close the command palette without executing any command, leave it on ':', and press enter.

These are the currently supported global commands:
- `:q` same as Ctrl+Q
- `:c` closes the current buffer without saving
- `:o <file>` opens the specified file in a new filebuffer, but if it does not exist, it pulls up an empty filebuffer, and when you save, it creates that file with the contents of the buffer
- `:t` opens a filetree buffer at the cwd

These are the supported commands in a filebuffer:
- `:f <word>` finds all occurences of the given word and puts you in search mode, in it you can press the arrow keys to cycle through the results and press enter to exit search mode
- `:s` saves the buffer

Using the filetree buffer:
- move with the arrow keys
- press enter to move into directories
- press `CTRL+O` to open the currently selected file in a new filebuffer
- directories have a `/` at the end of their names to distinguish them from regular files
- currently only global commands are supported in a filetree buffer

# Compiling
You will need a D compiler and DUB installed.
There are no dependencies *for now*.

To compile and run use:
```
dub -b=release
```
If you don't want a release build, just use `dub`.
This will compile, link, and create an executable, then starts it.

If you want to compile, but not run it, use:
```
dub build -b=release
```
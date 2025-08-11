# Textedit

> [!CAUTION]
> This is *very* WIP, it may be unstable, and you may lose your modifications. Your mileage may vary.

This is a very basic terminal text editor written in D.
Currently it does very, *very* basic syntax highlighting for `.d` files.

Currently tested on Linux and Windows.

The code is not the best quality, nor is it the most readable, but
I will be working on improving that.

# Usage
TODO

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
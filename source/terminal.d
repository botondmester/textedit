module terminal;

private:

import core.stdc.stdlib : atexit;

version (Windows) {
    import core.sys.windows.windows;

    HANDLE hStdin;
    HANDLE hStdout;
    DWORD origMode;
} else version(Posix) {
    import core.sys.posix.termios;
    import core.sys.posix.unistd;

    termios origTermios;

    bool posix_beenResized = false;

    extern(C) @nogc nothrow
    void handleSigWinch(int signo)
    {
        import core.sys.posix.signal;
        import core.stdc.stdlib : exit;
        if (signo == 28) // SIGWINCH
            posix_beenResized = true;
    }
}

bool rawModeEnabled = false;

public:

struct Extent {
    long width = 0;
    long height = 0;
    alias cols = width;
    alias rows = height;
    alias x = width;
    alias y = height;
}

struct Position {
    long x = 0;
    long y = 0;
    alias col = x;
    alias row = y;
}

static class Terminal {
public:
    static void enableRawMode() {
        if(rawModeEnabled) return;
        version(Windows) {
            hStdin = GetStdHandle(STD_INPUT_HANDLE);
            hStdout = GetStdHandle(STD_OUTPUT_HANDLE);
            GetConsoleMode(hStdin, &origMode);

            DWORD rawMode = origMode;
            rawMode &= ~(
                ENABLE_ECHO_INPUT |
                ENABLE_LINE_INPUT |
                ENABLE_PROCESSED_INPUT |
                ENABLE_QUICK_EDIT_MODE
            );
            rawMode |= ENABLE_VIRTUAL_TERMINAL_INPUT | ENABLE_WINDOW_INPUT;
            SetConsoleMode(hStdin, rawMode);
        } else version(Posix) {
            import core.sys.posix.signal;
            signal(26, &handleSigWinch); // SIGWINCH

            tcgetattr(STDIN_FILENO, &origTermios);

            termios raw = origTermios;

            raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
            raw.c_iflag &= ~(IXON | ICRNL | BRKINT | INPCK | ISTRIP);
            raw.c_cflag |= CS8;
            raw.c_cc[VMIN] = 0;
            raw.c_cc[VTIME] = 1;

            tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
        }
        atexit(&disableRawMode);
        rawModeEnabled = true;



        write("\x1b[9999C\x1b[9999B");
        flushBuffer();
        write("\x1b[6n");
        flushBuffer();
        char[] buf;
        do {
            buf ~= getChar();
        } while(buf[$-1] != 'R');

        import std.format.read;
        buf.formattedRead!"\x1b[%d;%dR"(screenrows, screencols);
        write("\x1b[?1049h\x1b[?1000l");
        flushBuffer();
    }

    extern(C) static void disableRawMode() {
        if(!rawModeEnabled) return;
        write("\x1b[?1049l");
        flushBuffer();
        version(Windows) {
            SetConsoleMode(hStdin, origMode);
        } else version(Posix) {
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &origTermios);
        }
        rawModeEnabled = false;
        write("\n");
        flushBuffer();
    }

    static char getChar() {
        version(Windows) {
            while(true) {
                INPUT_RECORD[1] recordBuf;
                DWORD eventsRead;

                // temp solution to get it working on windows
                hStdin = GetStdHandle(STD_INPUT_HANDLE);

                DWORD result = WaitForSingleObject(hStdin, 100);

                if(result == WAIT_TIMEOUT) return '\0';

                if(!ReadConsoleInputW(hStdin, recordBuf.ptr, 1, &eventsRead)){
                    return '\0';
                }

                auto record = recordBuf[0];
                if (record.EventType == WINDOW_BUFFER_SIZE_EVENT) {
                    import std.stdio;
                    screencols = record.Event.WindowBufferSizeEvent.dwSize.X;
                    screenrows = record.Event.WindowBufferSizeEvent.dwSize.Y;
                    return '\0';
                }
                if (record.EventType != KEY_EVENT) continue;
                auto key = record.Event.KeyEvent;

                if (!key.bKeyDown) continue;

                return cast(char)key.uChar.UnicodeChar;
            }
        } else version(Posix) {
            import core.sys.posix.sys.ioctl;
            char c = '\0';
            read(STDIN_FILENO, &c, 1);
            if(true) {
                winsize ws;
                ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws);
                screencols = ws.ws_col;
                screenrows = ws.ws_row;
                posix_beenResized = false;
            }
            return c;
        }
    }

    static Extent getWindowSize() {
        return Extent(screencols, screenrows);
    }

    static void write(Char)(in Char[] str) {
        import std.stdio;
        synchronized {
            if(bufUsed + str.length > buffer.length) {
                flushBuffer();
            }
            if(str.length > buffer.length) {
                _write(str);
                return;
            }
            buffer[bufUsed..bufUsed+str.length] = str[];
            bufUsed = bufUsed + str.length;
        }
    }

    static void writeln(Char)(in Char[] str) {
        write(str ~ '\n');
    }

    static void writef(Char, A...)(in Char[] fmt, A args) {
        import std.format;
        write(format(fmt, args));
    }

    static void writefln(Char, A...)(in Char[] fmt, A args) {
        import std.format;
        writeln(format(fmt, args));
    }

    static void flushBuffer() {
        import std.stdio;
        synchronized {
            if (bufUsed > 0) {
                _write(buffer[0 .. bufUsed]);
                bufUsed = 0;
            }
        }
    }

    static void _write(Char)(in Char[] str) {
        synchronized {
            version(Windows) {
                DWORD written;
                WriteFile(hStdout, cast(LPVOID)str.ptr, cast(DWORD)str.length, &written, null);

            } else version(Posix) {
                ssize_t written =
                    core.sys.posix.unistd.write(STDOUT_FILENO, cast(const(char)*)str.ptr, cast(size_t)str.length);
            }
            assert(written == str.length, "did not write whole string");
        }
    }
private:
    static shared int screenrows = 24;
    static shared screencols = 80;
    static shared char[32*1024] buffer;
    static shared size_t bufUsed = 0;
}
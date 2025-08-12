module main;

import std.ascii;
import std.stdio;
import std.concurrency;
import terminal;
import buffer;
import filebuffer;
import buffermanager;
import cmdpalette;
import events;

void editorQuit() {
    import core.stdc.stdlib : exit;
    Terminal.write("\x1b[2J");
    Terminal.write("\x1b[H");
    Terminal.flushBuffer();
    exit(0);
    assert(false, "unreachable");
}

void editorSave() {
    if(!BufferManager.currBuffer.isDirty) {
        return;
    }
}

void editorMoveCursor(int key) {
    if(!CmdPalette.isActive) {
        final switch (key) {
            case 'a':
            case EditorKey.ARROW_LEFT:
                BufferManager.currBuffer.updateCursorPos(-1, 0);
                break;
            case 'd':
            case EditorKey.ARROW_RIGHT:
                BufferManager.currBuffer.updateCursorPos(1, 0);
                break;
            case 'w':
            case EditorKey.ARROW_UP:
                BufferManager.currBuffer.updateCursorPos(0, -1);
                break;
            case 's':
            case EditorKey.ARROW_DOWN:
                BufferManager.currBuffer.updateCursorPos(0, 1);
                break;
        }
    } else {
        // TODO: make it so you can move the cursor in the cmd palette
    }
}

void editorRefreshScreen() {
    Terminal.write("\x1b[?25l");
    Terminal.write("\x1b[2J");
    Terminal.write("\x1b[H");

    BufferManager.render();

    Terminal.write(CmdPalette.draw());
    if(CmdPalette.isActive) {
        Terminal.writef("\x1b[%d;%dH", Terminal.getWindowSize()[0] + 1, CmdPalette.cursorPos + 1);
    } else {
        Terminal.writef("\x1b[%d;%dH",
            BufferManager.getCursorPos()[0] + 1,
            BufferManager.getCursorPos()[1] + 1);
    }
    Terminal.write("\x1b[?25h");
    Terminal.flushBuffer();
}

EditorKey editorReadKeypress() {
    char c = Terminal.getChar();

    if(c == '\x1b') {
        char[] seq;
        seq ~= Terminal.getChar();
        seq ~= Terminal.getChar();

        if (seq[0] == '[' && seq[1] == '1') {
            seq ~= Terminal.getChar();
            seq ~= Terminal.getChar();
            seq ~= Terminal.getChar();
            switch(seq[4]) {
                case 'A': return EditorKey.CTRL_ARROW_UP;
                case 'B': return EditorKey.CTRL_ARROW_DOWN;
                case 'C': return EditorKey.CTRL_ARROW_RIGHT;
                case 'D': return EditorKey.CTRL_ARROW_LEFT;
                default: break;
            }
        }
        else if(seq[0] == '[') {
            switch (seq[1]) {
                case 'A': return EditorKey.ARROW_UP;
                case 'B': return EditorKey.ARROW_DOWN;
                case 'C': return EditorKey.ARROW_RIGHT;
                case 'D': return EditorKey.ARROW_LEFT;
                default: break;
            }
        }

        return cast(EditorKey)'\x1b';
    } else {
        return cast(EditorKey)c;
    }
}

void pollKeys() {
    int width = 0;
    int height = 0;
    while(true) {
        EditorKey c = editorReadKeypress();
        int[2] size = Terminal.getWindowSize();
        if(size[0] != height || size[1] != width) {
            height = size[0];
            width = size[1];
            send(ownerTid, ResizeEvent(width, height));
        }
        send(ownerTid, KeyEvent(c));
    }

}

void editorProcessKeypress(EditorKey c) {
    if(!CmdPalette.isActive && c == CTRL_KEY!'p') {
        CmdPalette.activate();
        return;
    }

    switch(c){
        case CTRL_KEY!'q':
            editorQuit();
            assert(false, "unreachable");
        case CTRL_KEY!'s':
            editorSave();
            break;
        case EditorKey.ARROW_LEFT:
        case EditorKey.ARROW_RIGHT:
        case EditorKey.ARROW_UP:
        case EditorKey.ARROW_DOWN:
            editorMoveCursor(c);
            return;
        case EditorKey.CTRL_ARROW_LEFT:
        case EditorKey.CTRL_ARROW_UP:
            BufferManager.moveFocusBackward();
            break;
        case EditorKey.CTRL_ARROW_RIGHT:
        case EditorKey.CTRL_ARROW_DOWN:
            BufferManager.moveFocusForward();
            break;
        default: break;
    }



    if(CmdPalette.isActive) {
        CmdPalette.handleKeypress(c);
    } else {
        BufferManager.currBuffer.handleKeypress(c);
    }
}

int main(string[] args)
{
    bool doOpenFile = true;
    if(args.length < 2) doOpenFile = false;
    import std.path;
    import std.file;
    if(doOpenFile && !isValidPath(args[1])) doOpenFile = false;
    if(doOpenFile && !exists(args[1])) doOpenFile = false;
    if(doOpenFile && !isFile(args[1])) doOpenFile = false;
    if(doOpenFile) {
        BufferManager.openBuffer(new FileBuffer(args[1]));
    } else {
        BufferManager.openBuffer(new WelcomeBuffer());
    }

    Terminal.enableRawMode();
    scope(exit) Terminal.disableRawMode();
    auto poller = spawnLinked(&pollKeys);

    try {
        while(true){
            receive(
                (KeyEvent e) {
                    editorProcessKeypress(e.key);
                    editorRefreshScreen();
                },
                (ResizeEvent e) {
                    editorRefreshScreen();
                }
            );
        }
    } catch(Exception e) {
        Terminal.disableRawMode();
        writeln("An exception occured: ", e.msg);
        debug writeln(e.info);
        import core.stdc.stdlib : exit;
        exit(1);
    }
    return 0;
}
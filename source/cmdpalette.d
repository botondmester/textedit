module cmdpalette;

private:

import buffermanager;
import main;
import events;

public:

static class CmdPalette {
public:
    static bool isActive() {
        return _isActive;
    }
    static void activate() {
        _isActive = true;
        paletteBuffer = [':'];
    }
    static void activate(string start) {
        _isActive = true;
        paletteBuffer = start.dup; // copy to avoid modifying original string
    }
    static void deactivate() {
        _isActive = false;
        paletteBuffer.length = 0;
    }
    static void deactivate(string msg) {
        _isActive = false;
        paletteBuffer = cast(char[])(msg.dup); // copy to avoid modifying original string
    }
    static int cursorPos() {
        return cast(int)paletteBuffer.length;
    }
    static void handleKeypress(int c) {
        import std.ascii;

        if(c == EditorKey.BACKSPACE && paletteBuffer.length > 0) {
            paletteBuffer = paletteBuffer[0..$-1];
        }

        if(c <= char.max && isPrintable(cast(char)c))
            paletteBuffer ~= cast(char)(c & 0xFF);
        

        if(c == '\r') {
            import std.string;
            auto command = split(paletteBuffer);
            if(paletteBuffer.length == 0 || paletteBuffer[0] != ':') return;
            if(command[0] == ":") {
                deactivate();
                return;
            }
            else if(command[0] == ":q"){
                editorQuit();
            }
            else if(command[0] == ":c"){
                import buffer;
                BufferManager.closeCurrentBuffer();
                deactivate();
                return;
            }
            else if(command[0] == ":o") {
                bool doOpenFile = true;
                bool fileExists = false;
                if(command.length != 2) doOpenFile = false;
                import std.path;
                import std.file;
                if(doOpenFile && !isValidPath(command[1])) doOpenFile = false;
                if(doOpenFile && exists(command[1])) fileExists = true;
                if(doOpenFile && fileExists && !isFile(command[1])) doOpenFile = false;
                if(doOpenFile) {
                    import filebuffer;
                    BufferManager.openBuffer(new FileBuffer(cast(string)command[1]));
                }
                deactivate();
                return;
            }
            else {
                bool success = BufferManager.currBuffer.handleCommand(cast(string[])command);
                if(!success) {
                    deactivate("Unknown/invalid command");
                    // TODO tell user that the command is unknown/invalid
                    return;
                }
                
            }
        }
    }

    static string draw() {
        return cast(string)paletteBuffer;
    }
private:
    static bool _isActive = false;
    static char[] paletteBuffer;
}
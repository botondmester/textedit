module filetreebuffer;

private:

import std.stdio;
import std.array;

public:

import buffer;

final class FileTreeBuffer : IBuffer {
public:
    this(string path) {
        import std.path;
        import std.file : exists, isDir;
        assert(isValidPath(path));

        if(exists(path) && isDir(path)) {
            openPath = path;
        } else {
            import std.file : getcwd;
            openPath = getcwd();
        }

        updateContent();
    }

    void updateCursorPos(int x, int y) {
        cursorPos.y += y;
        if(cursorPos.y < 0) {
            cursorPos.y = 0;
        }
        if(cursorPos.y >= bufferContent.length) {
            cursorPos.y = cast(long)bufferContent.length - 1;
        }
        
        bufferPos.y = cursorPos.y - (fullExtent.height / 5) * 4;
        if(bufferPos.y < 0) {
            bufferPos.y = 0;
        }

    }

    Position getCursorPos() {
        return Position(0, cursorPos.y - bufferPos.y);
    }

    void updateBufferSize(Extent extent) {
        this.fullExtent = extent;
        updateCursorPos(0,0); // make sure cursor is in a valid position
    }

    char[][] draw() {
        import std.conv : to;
        char[][] frame;
        for(int y = 0; y < fullExtent.rows - 1; y++) {
            if(y + bufferPos.y >= bufferContent.length) {
                char[] row;
                row.length  = fullExtent.width;
                row[] = ' ';
                frame ~= row;
                continue;
            }
            frame ~= bufferContent[y+bufferPos.y].render(0, fullExtent.cols);
        }
        frame.length = fullExtent.rows - 1;

        import std.format;
        import std.path : asAbsolutePath;
        import std.conv : to;
        string mode = "";
        if(false) mode = "<Search mode>";
        // draw status bar
        frame ~= cast(char[])format!"\x1b[1;7m%s"(openPath.asAbsolutePath);
        // draw mode indicator
        if(frame[$-1].length + mode.length + 1 < fullExtent.width + 6) {
            frame[$-1] ~= ' ' ~ mode; // only draw mode if it fits
        }
        while(frame[$-1].length < fullExtent.width + 6) frame[$-1] ~= ' ';
        frame[$-1].length = fullExtent.width + 6; // make sure it won't draw any character that doesn't fit
        frame[$-1] ~= "\x1b[m"; // reset graphics rendition
        return frame;
    }

    bool isDirty() {
        return false;
    }

    bool handleCommand(string[] command) {
        import cmdpalette;
        return false;
        if(command[0] == ":f") {
            // TODO: implement later
            if(command.length != 2) return false;
            return true;
        }
        return false;
    }

    void handleKeypress(int c){
        import events : EditorKey;
        if(c == '\r') {
            import std.path;
            import std.file : isDir, exists;
            auto newpath = buildNormalizedPath(openPath, bufferContent[cursorPos.y]._data);
            if(!isValidPath(newpath) || !exists(newpath) || !isDir(newpath)) return;
            openPath = newpath;
            updateContent();
        } else if(c == 'o') {
            import std.path;
            import std.file : isFile, exists;
            auto path = buildNormalizedPath(openPath, bufferContent[cursorPos.y]._data);
            if(!isValidPath(path) || !exists(path) || !isFile(path)) return;
            import buffermanager, filebuffer;
            BufferManager.openBuffer(new FileBuffer(path));
        }
    }

    void updateContent() {
        bufferContent.length = 0;
        dirContent.length = 0;
        bufferContent ~= Row("../");
        bufferContent[0].highlight(0, 3, EditorHighlight.NUMBER);
        import std.file : dirEntries, SpanMode, DirEntry;
        import std.path : baseName;
        foreach(DirEntry e; dirEntries(openPath, SpanMode.shallow)) {
            if(e.isFile)
                dirContent ~= e.name.baseName;
            else if(e.isDir)
                dirContent ~= e.name.baseName ~ "/";
        }
        import std.algorithm.sorting : sort;
        sort(dirContent);
        foreach (name; dirContent) {
            Row row = Row(name);
            if(name[$-1] == '/') {
                row.highlight(0, row.length, EditorHighlight.NUMBER);
            }
            bufferContent ~= row;
        }
    }
private:
    Position cursorPos;
    Position bufferPos;
    Extent fullExtent;
    string openPath;
    Row[] bufferContent;
    string[] dirContent;
}
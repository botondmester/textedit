module filebuffer;

private:

import std.stdio;
import std.array;

import syntaxhighlighting : EditorHighlight;

string syntaxToColor(char hl) {
    final switch (hl) {
        case EditorHighlight.NORMAL: return "\x1b[m";
        case EditorHighlight.NUMBER: return "\x1b[0;36m";
        case EditorHighlight.STRING: return "\x1b[0;32m";
        case EditorHighlight.KEYWORD: return "\x1b[1;34m";
        case EditorHighlight.IDENTIFIER: return "\x1b[0;37m";
        case EditorHighlight.COMMENT: return "\x1b[2;37m";
        case EditorHighlight.OPERATOR: return "\x1b[1;33m";
        case EditorHighlight.PUNCTUATION: return "\x1b[0;33m";
    }
}

public:
import buffer;

struct Row {
public:
    this(inout char[] line) {
        this.data = line.dup;
        this.highlighting.length = data.length;
        this.highlighting[] = EditorHighlight.NORMAL;
    }
    void insert(char c, size_t pos) {
        assert(pos <= data.length && pos >= 0, "out of bounds");
        data = data[0..pos] ~ c ~ data[pos..$];
        highlighting = highlighting[0..pos] ~ EditorHighlight.NORMAL ~ highlighting[pos..$];
    }
    void append(Row other) {
        this.data ~= other.data;
        this.highlighting ~= other.highlighting;
    }
    void remove(size_t pos) {
        assert(pos < data.length && pos >= 0, "out of bounds");
        data = data[0..pos] ~ data[pos+1..$];
        highlighting = highlighting[0..pos] ~ highlighting[pos+1..$];
    }
    char[] render(size_t offset, size_t len) {
        import std.algorithm;
        char[] ret;
        string currColor = "\x1b[37m";
        size_t end = min(data.length, offset + len);
        for(size_t i = offset; i < offset + len; i++) {
            if(i >= end) { // pad out with spaces
                ret ~= ' ';
                continue;
            }
            string color = syntaxToColor(highlighting[i]);
            if(currColor != color) {
                ret ~= color;
                currColor = color;
            }
            ret ~= data[i];
        }
        // reset color if needed
        if(currColor != "\x1b[m") {
            ret ~= "\x1b[m";
        }
        return ret;
    }
    void highlight(size_t start, size_t len, EditorHighlight hl) {
        highlighting[start..start+len] = hl;
    }
    void clearHighlighting() {
        highlighting[] = EditorHighlight.NORMAL;
    }
    size_t length() {
        return data.length;
    }
    const(char)[] _data() {
        return cast(const(char)[])this.data;
    }
private:
    char[] data;
    EditorHighlight[] highlighting;
}

class FileBuffer : IBuffer {
public:
    this(string path) {
        import std.path;
        import std.file : exists, isFile;
        assert(isValidPath(path));
        openFilePath = path;

        if(exists(path) && isFile(path)) {
            auto file = File(path, "r+");
            // I don't plan on supporting huge files
            assert(file.size() < 256*1024*1024, "files larger than 256 MiB are currently not supported");
            char[] line;
            while((line = file.readln!(char[])()) !is null) {
                import std.string;
                openFileBuffer ~= Row(stripRight(line));
            }
            file.close();
            import syntaxhighlighting;
            doHighlighting(openFileBuffer, openFilePath.baseName);
        } else {
            openFileBuffer.length = 1;
            openFileBuffer ~= Row("");
        }
    }

    void updateCursorPos(int x, int y) {
        if(inFindMode) {
            if((x < 0 || y < 0) && foundidx > 0) {
                foundidx--;
                seekFilePos(foundPositions[foundidx][0], foundPositions[foundidx][1]);
            }
            else if((x > 0 || y > 0) && foundidx + 1 < foundPositions.length) {
                foundidx++;
                seekFilePos(foundPositions[foundidx][0], foundPositions[foundidx][1]);
            }
            return;
        }

        cursorPosX += x;
        if(cursorPosX >= cast(int)cols) {
            cursorPosX = cast(int)cols - 1;
            updateFilePos(1, 0);
        }
        if(cursorPosX < 0) {
            cursorPosX = 0;
            updateFilePos(-1, 0);
        }
        cursorPosY += y;
        if(currLine + 1 > openFileBuffer.length) {
            // TODO: fix
            cursorPosY--;
        }
        if(cursorPosY >= cast(int)rows - 1) {
            cursorPosY = cast(int)rows - 2;
            updateFilePos(0, 1);
        }
        if(cursorPosY < 0) {
            cursorPosY = 0;
            updateFilePos(0, -1);
        }

        if(currLine < openFileBuffer.length &&
            currCol > cast(long)openFileBuffer[currLine].length
        ) {
            long diff = currCol - cast(long)openFileBuffer[currLine].length;
            if(diff > cursorPosX) {
                diff -= cursorPosX;
                cursorPosX = 0;
                filePosX -= diff;
            } else {
                cursorPosX -= diff;
            }
        }
    }

    void updateFilePos(int x, int y) {
        filePosX += x;
        if(currLine < openFileBuffer.length &&
            filePosX >= cast(long)openFileBuffer[currLine].length)
            filePosX = cast(long)openFileBuffer[currLine].length - 1;
        if(filePosX < 0) filePosX = 0;
        filePosY += y;
        if(filePosY >= cast(long)openFileBuffer.length) filePosY = cast(long)openFileBuffer.length - 1;
        if(filePosY < 0) filePosY = 0;
    }

    void seekFilePos(long line, long col) {
        if(line > rows/3) {
            cursorPosY = cast(int)(rows/3);
            filePosY = cast(int)(line-rows/3);
        } else {
            cursorPosY = cast(int)line;
            filePosY = 0;
        }
        if(col > cols/3) {
            cursorPosX = cast(int)(cols/3);
            filePosX = cast(int)(col-cols/3);
        } else {
            cursorPosX = cast(int)col;
            filePosX = 0;
        }
    }

    Position getCursorPos() {
        return Position(cursorPosX, cursorPosY);
    }

    void updateBufferSize(Extent extent) {
        this.rows = extent.rows;
        this.cols = extent.cols;
        updateCursorPos(0,0);
    }

    char[][] draw() {
        char[][] frame;
        for(int y = 0; y < rows - 1 && filePosY+y < openFileBuffer.length; y++) {
            Row line = openFileBuffer[filePosY+y];

            frame ~= line.render(filePosX, this.cols);
        }
        frame.length = rows - 1; // pad out with empty lines as needed
        import std.format;
        import std.path : baseName;
        frame ~= cast(char[])format!"\x1b[1;7m%s:%d:%d"(openFilePath.baseName, currLine, currCol);
        while(frame[$-1].length < this.cols + 6) frame[$-1] ~= ' ';
        frame[$-1] ~= "\x1b[m";
        return frame;
    }

    bool isDirty() {
        return dirtyFlag;
    }

    bool handleCommand(string[] command) {
        import cmdpalette;
        if(command[0] == ":f") {
            if(command.length != 2) return false;
            inFindMode = true;
            foundidx = 0;
            for(auto i = 0; i < openFileBuffer.length; i++) {
                for(auto j = 0; j + command[1].length - 1 < openFileBuffer[i].length; j++) {
                    if(openFileBuffer[i]._data[j..j+command[1].length] == command[1]) {
                        foundPositions ~= [i, j];
                    }
                }
            }
            if(foundPositions.length == 0) {
                CmdPalette.deactivate("Found 0 matches");
                inFindMode = false;
            } else {
                import std.format;
                CmdPalette.deactivate(format!"found %d matches"(foundPositions.length));
                seekFilePos(foundPositions[0][0], foundPositions[0][1]);
            }
            return true;
        } else if(command[0] == ":s") {
            File file = File(openFilePath, "w");
            char[] buf;
            for(size_t i = 0; i < openFileBuffer.length; i++) {
                buf ~= openFileBuffer[i]._data;
                if(i + 1 != openFileBuffer.length) {
                    buf ~= '\n';
                }
            }
            file.write(buf);
            file.flush();
            file.close();
            import std.format;
            CmdPalette.deactivate(format!"Saved %d bytes."(buf.length));
            dirtyFlag = false;
            return true;
        }
        return false;
    }

    void handleKeypress(int c){
        if(c == '\r' && inFindMode) {
            import cmdpalette;
            CmdPalette.deactivate();
            inFindMode = false;
            return;
        }

        // helper functions
        void insert(T)(ref T[] arr, T el, size_t pos) {
            assert(pos <= arr.length && pos >= 0, "out of bounds");
            arr = arr[0..pos] ~ el ~ arr[pos..$];
        }

        void remove(T)(ref T[] arr, size_t pos) {
            assert(pos < arr.length && pos >= 0, "out of bounds");
            arr = arr[0..pos] ~ arr[pos+1..$];
        }

        import std.ascii : isPrintable;
        import events : EditorKey;
        import syntaxhighlighting;
        import std.path : baseName;
        if(isPrintable(c)) {
            dirtyFlag = true;
            openFileBuffer[currLine].insert(cast(char)c, currCol);
            updateCursorPos(1, 0);
            doHighlighting(openFileBuffer, openFilePath.baseName);
        } else if(c == EditorKey.BACKSPACE) {
            dirtyFlag = true;
            if(currCol>0) {
                openFileBuffer[currLine].remove(currCol-1);
                updateCursorPos(-1, 0);
            } else if(currLine > 0) {
                auto oldlen = openFileBuffer[currLine-1].length;
                openFileBuffer[currLine-1].append(openFileBuffer[currLine]);
                remove(openFileBuffer, currLine);
                seekFilePos(currLine-1, oldlen);
            }
            doHighlighting(openFileBuffer, openFilePath.baseName);
        } else if(c == '\r') {
            dirtyFlag = true;
            insert(openFileBuffer, Row(openFileBuffer[currLine]._data[currCol..$]), currLine+1);
            openFileBuffer[currLine] = Row(openFileBuffer[currLine]._data[0..currCol]);
            seekFilePos(currLine+1, 0);
            doHighlighting(openFileBuffer, openFilePath.baseName);
        }
    }
private:
    long currLine() {
        return filePosY+cursorPosY;
    }
    long currCol() {
        return filePosX+cursorPosX;
    }
    bool inFindMode = false;
    long[2][] foundPositions;
    long foundidx = 0;

    long filePosY = 0;
    long filePosX = 0;
    int cursorPosX = 0;
    int cursorPosY = 0;
    size_t rows = 24;
    size_t cols = 80;
    string openFilePath;
    Row[] openFileBuffer;
    bool dirtyFlag = false;
}
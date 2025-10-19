module buffer;
private:
import terminal;
public:

import terminal : Extent, Position;

interface IBuffer {
    void updateCursorPos(int x, int y);
    Position getCursorPos();
    void updateBufferSize(Extent extent);
    char[][] draw();
    bool isDirty();
    bool handleCommand(string[] command);
    void handleKeypress(int c);
}

class WelcomeBuffer : IBuffer {
public:
    void updateCursorPos(int x, int y) {

    }

    Position getCursorPos() {
        return Position(0, 0);
    }

    void updateBufferSize(Extent extent) {
        this.rows = extent.rows;
        this.cols = extent.cols;
    }
    
    char[][] draw() {
        auto frame = new char[][this.rows];
        for(int y = 0; y < rows; y++) {
            frame[y] = new char[this.cols];
            frame[y][] = ' ';

            if(y == rows / 3) {
                string str = "text editor -- version 0.0.1";
                size_t padding = (cols - str.length) / 2;
                if(padding) frame[y][0] = '~';
                for(int i = 0; i + padding < cols; ++i) {
                    if(i < str.length) {
                        frame[y][i + padding] = str[i];
                    }
                }
            } else if(y - 1 == rows / 3) {
                string str = "For usage, refer to README.md";
                size_t padding = (cols - str.length) / 2;
                if(padding) frame[y][0] = '~';
                for(int i = 0; i + padding < cols; ++i) {
                    if(i < str.length) {
                        frame[y][i + padding] = str[i];
                    }
                }
            } else {
                frame[y][0] = '~';
            }
        }
        return frame;
    }

    bool isDirty() {
        return false;
    }

    bool handleCommand(string[] command) {
        return false;
    }

    void handleKeypress(int c){

    }
private:
    size_t rows = 24;
    size_t cols = 80;
}

class EmptyBuffer : IBuffer {
public:
    void updateCursorPos(int x, int y) {

    }

    Position getCursorPos() {
        return Position(0, 0);
    }

    void updateBufferSize(Extent extent) {
        this.rows = extent.rows;
        this.cols = extent.cols;
    }
    
    char[][] draw() {
        auto frame = new char[][this.rows];
        for(int y = 0; y < rows; ++y) {
            frame[y] = new char[this.cols];
            frame[y][] = ' ';
            
            frame[y][0] = '~';
        }
        return frame;
    }

    bool isDirty() {
        return false;
    }

    bool handleCommand(string[] command) {
        return false;
    }

    void handleKeypress(int c){
        
    }
private:
    size_t rows = 24;
    size_t cols = 80;
}

import syntaxhighlighting : EditorHighlight; // TODO: move to general colors

private string syntaxToColor(char hl) {
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
            if(data[i] == '\t') {
                for(int j = 0; j < 4-(i%4); j++) {
                    ret ~= ' ';
                    len--;
                }
                len++;
            } else {
                ret ~= data[i];
            }
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
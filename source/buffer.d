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
            } else {
                import std.conv;
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
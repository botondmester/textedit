module buffermanager;

private:

import terminal;

public:
import buffer;
import terminal : Position;


static class BufferManager {
public:
    static IBuffer currBuffer() {
        return buffers[focusedBufferIdx];
    }
    static Position getCursorPos() {
        auto width = Terminal.getWindowSize().width;

        auto bufNum = buffers.length;
        auto bufWidth = width / bufNum;

        Position pos;
        pos.row = currBuffer.getCursorPos().row;
        pos.col = focusedBufferIdx * bufWidth + currBuffer.getCursorPos().col;
        return pos;
    }
    static void render() {
        auto height = Terminal.getWindowSize().height;
        auto width = Terminal.getWindowSize().width;
        height--; // leave space for the command palette

        auto bufNum = buffers.length;
        auto bufWidth = width / bufNum;

        char[][] frame;
        frame.length = height;
        char[][][] bufFrames;
        bufFrames.length = bufNum;
        // render each buffer into it's own framebuffer
        for(size_t i = 0; i < bufNum; i++) {
            buffers[i].updateBufferSize(Extent(bufWidth, height));
            bufFrames[i] = buffers[i].draw();
            assert(bufFrames[i].length == height);
        }
        // combine them
        for(auto y = 0; y < height; y++) {
            for(size_t i = 0; i < bufNum; i++) {

                frame[y] ~= bufFrames[i][y];
            }
        }
        // draw
        for (auto i = 0; i < frame.length; i++) {
            Terminal.writeln(frame[i]);
        }
    }
    static void openBuffer(IBuffer buf) {
        focusedBufferIdx = buffers.length;
        buffers ~= buf;
    }
    static void closeCurrentBuffer() {
        assert(focusedBufferIdx >= 0 && focusedBufferIdx < buffers.length);
        buffers = buffers[0..focusedBufferIdx] ~ buffers[focusedBufferIdx+1..$];
        if(focusedBufferIdx >= buffers.length && buffers.length > 0) {
            focusedBufferIdx = cast(long)buffers.length - 1;
        } else if(focusedBufferIdx > 0) {
            focusedBufferIdx--;
        }
        if(buffers.length == 0) {
            openBuffer(new EmptyBuffer);
        }
    }
    static void moveFocusForward() {
        if(focusedBufferIdx + 1 < buffers.length) {
            focusedBufferIdx++;
        }
    }
    static void moveFocusBackward() {
        if(focusedBufferIdx > 0) {
            focusedBufferIdx--;
        }
    }
private:
    static size_t focusedBufferIdx = 0;
    static IBuffer[] buffers;
}
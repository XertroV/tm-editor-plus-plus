// hack to make it easier to pass stuff around
class ThinLazyFile {
    MemoryBuffer buf;
    string path;
    IO::FileMode mode;
    ThinLazyFile(const string &in path, IO::FileMode mode) {
        this.path = path;
        this.mode = mode;
    }

    ~ThinLazyFile() {
        Close();
    }

    bool closed = false;
    void Close() {
        if (!closed) {
            IO::File f(path, mode);
            buf.Seek(0);
            f.Write(buf);
            f.Close();
        }
        closed = true;
    }

    void WriteLine(const string &in line) {
        if (closed) throw("already closed");
        buf.Write(line);
        buf.Write("\n");
    }
}

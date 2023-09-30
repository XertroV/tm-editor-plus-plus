namespace Log {
    void Trace(const string &in msg) {
        trace(msg);
    }
}

void dev_trace(const string &in msg) {
#if DEV
    trace(msg);
#endif
}

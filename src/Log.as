enum LogLevel {
    TRACE,
    DEBUG,
    INFO,
    WARN,
    ERROR,
    FATAL
}

[Setting hidden]
LogLevel S_LogLevel = LogLevel::INFO;

namespace Log {
    void Trace(const string &in msg) {
        if (S_LogLevel <= LogLevel::TRACE) {
            trace(msg);
        }
    }
}

void dev_trace(const string &in msg) {
#if DEV
    trace(msg);
#endif
}

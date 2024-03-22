enum LogLevel {
    TRACE,
    DEBUG,
    INFO,
    WARN,
    ERROR,
    FATAL
}

[Setting hidden]
#if DEV
LogLevel S_LogLevel = LogLevel::TRACE;
#else
LogLevel S_LogLevel = LogLevel::INFO;
#endif

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

void dev_warn(const string &in msg) {
#if DEV
    warn(msg);
#endif
}

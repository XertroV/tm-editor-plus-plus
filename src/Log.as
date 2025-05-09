enum LogLevel {
    DEBUG,
    TRACE,
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

namespace _Log {
    void Trace(const string &in msg) {
        if (S_LogLevel <= LogLevel::TRACE) {
            trace('[' + Time::Now + '] ' + msg);
        }
    }
    void Trace(const string &in scope, const string &in msg) {
        if (S_LogLevel <= LogLevel::TRACE) {
            trace('[' + Time::Now + ']['+scope+'] ' + msg);
        }
    }
    void Debug(const string &in msg) {
        if (S_LogLevel <= LogLevel::DEBUG) {
            trace('[' + Time::Now + '] ' + msg);
        }
    }
    void Info(const string &in msg) {
        if (S_LogLevel <= LogLevel::INFO) {
            print('[' + Time::Now + '] ' + msg);
        }
    }
    void Warn(const string &in msg) {
        if (S_LogLevel <= LogLevel::WARN) {
            warn('[' + Time::Now + '] ' + msg);
        }
    }
    void Warn_NID(const string &in msg) {
#if DEV
        NotifyWarning(msg);
#else
        if (S_LogLevel <= LogLevel::WARN) {
            warn('[' + Time::Now + '] ' + msg);
        }
#endif
    }
    void Error(const string &in msg) {
        if (S_LogLevel <= LogLevel::ERROR) {
            error('[' + Time::Now + '] ' + msg);
        }
    }
}

void dev_trace(const string &in msg) {
#if DEV
    trace('[' + Time::Now + '] ' + msg);
#endif
}

void dev_warn(const string &in msg) {
#if DEV
    warn(msg);
#endif
}

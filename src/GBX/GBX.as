shared enum GBX_CHUNK_IDS {
    CGameItemModel_Icon = 0x2E001004,
}

shared class Gbx : BufUtils {
    Gbx(const string &in path, uint maxReadSize = 65536 * 2, bool quiet = true) {
        SetLogger(quiet);
        log.parse_pop_all();
        log.parse(path, "GbxFile", "Loading .gbx file.");
        uint fileLen = 0;

        try {
            IO::File f(path, IO::FileMode::Read);
            fileLen = f.Size();
            trace('Loading GBX file of length: ' + fileLen);
            @buf = f.Read(Math::Min(maxReadSize, fileLen));
        } catch {
            NotifyError("Failed to open the file: " + getExceptionInfo());
            warn(">> File path: " + path);
        }

        try {
            ReadHeader();
            // can be optimized to just read header
        } catch {
            auto ex = getExceptionInfo();
            warn("Exception parsing GBX file: " + ex);
            if (quiet) {
                warn(">> ------------ PARSE LOGS ------------");
                log.PrintAllAfterCrash();
                warn(">> ------------ END PARSE LOGS ------------");
            }
            throw(ex);
        }
        if (fileLen <= maxReadSize) {
            ReadCompressedBody();
        }
    }

    Gbx(MemoryBuffer@ buf, bool quiet = true) {
        SetLogger(quiet);
        @this.buf = buf;
        ReadHeader();
    }

    void ReadCompressedBody() {
        log.trace('Reading compressed data of length: ' + compressedDataSize);
        @compressedData = buf.ReadBuffer(compressedDataSize);
        // @data = LZO_Decompress(compressedData, compressedDataSize);
        // log.trace('Got data of size: ' + data.GetSize());
        // log.trace('Expected data size: ' + dataSize);
    }

    uint hVersion;
    uint hClassId;
    int nbNodes;
    int nbExternalNodes;
    ExternalNode@[] extNodes;
    ExternalFolder@ rootSubFolder;
    UserData@ userData;
    uint dataSize;
    uint compressedDataSize;
    MemoryBuffer@ compressedData;
    MemoryBuffer@ data;

    void ReadHeader() {
        if (buf.ReadString(3) != "GBX") {
            throw("Not a gbx file!");
        }
        hVersion = ReadUInt16('encoding version');
        if (hVersion < 6) throw('verison < 6 unsupported');
        // BU, C for compressed, U for uncompressed, then u01_R_or_E
        SkipBytes(4);
        hClassId = ReadUInt32('main class id');
        log.parse_push(Text::Format("%08x", hClassId));
        @userData = UserData(buf, log);
        // return;
        nbNodes = ReadInt32('nb nodes');
        nbExternalNodes = ReadInt32('nb external nodes');
        // todo, read external nodes if they exist
        if (nbExternalNodes > 0) {
            auto ancestorLevel = ReadUInt32('ancestor level');
            @rootSubFolder = ExternalFolder(buf, log);
            // read external nodes
            log.parse_push("ExtNode");
            for (int i = 0; i < nbExternalNodes; i++) {
                extNodes.InsertLast(ExternalNode(buf, hVersion, i, log));
            }
            log.parse_pop();
        }
        if (buf.AtEnd()) {
            dataSize = 0;
            compressedDataSize = 0;
        } else {
            try {
                dataSize = ReadUInt32('data size');
            } catch {}
            if (dataSize > 0) {
                compressedDataSize = ReadUInt32('compressed size');
            }
        }
    }

    UDEntry@ GetHeaderChunk(uint chunkId) {
        return userData.GetHeaderChunk(chunkId);
    }
}



shared class ExternalFolder : BufUtils {
    int nb;
    string[] strings;
    ExternalFolder@[] subFolders;

    ExternalFolder(MemoryBuffer@ buf, ParseLogger@ log) {
        @this.log = log;
        log.parse_push('SubFolder');
        @this.buf = buf;
        nb = ReadInt32("nb folders");
        for (int i = 0; i < nb; i++) {
            strings.InsertLast(ReadString('name'));
            subFolders.InsertLast(ExternalFolder(buf, log));
        }
        log.parse_pop();
    }
}

shared class ExternalNode : BufUtils {
    string filename;
    uint32 resourceIx;
    uint32 nodeIx;
    uint32 useFile;
    uint32 folderIx;

    ExternalNode(MemoryBuffer@ buf, uint hVersion, uint i, ParseLogger@ log) {
        @this.log = log;
        @this.buf = buf;
        log.parse_push('ExtNode ' + i);

        // flags & 4 => !isRefResourceIndex
        auto flags = ReadUInt32('flags');
        // ref
        if (flags & 4 == 0) {
            ReadString('ref: filename');
        } else {
            ReadUInt32('ref: resource ix');
        }

        nodeIx = ReadUInt32('node Ix');
        useFile = ReadUInt32('use file (bool)');

        if (flags & 4 == 0)
            folderIx = ReadUInt32('folder ix');

        log.parse_pop();
    }
}


shared class UserData : BufUtils {
    UDEntry@[] entries;
    uint size;
    uint nbChunks = 0;

    UserData(MemoryBuffer@ buf, ParseLogger@ log) {
        @this.log = log;
        @this.buf = buf;
        log.parse_push('UserData');

        size = ReadUInt32('total user data size');
        if (size == 0) return;
        nbChunks = ReadUInt32('nb chunks');

        for (uint i = 0; i < nbChunks; i++) {
            entries.InsertLast(UDEntry(buf, log));
        }
        for (uint i = 0; i < entries.Length; i++) {
            entries[i].ReadData();
        }

        log.parse_pop();
    }

    UDEntry@ GetHeaderChunk(uint chunkId) {
        for (uint i = 0; i < entries.Length; i++) {
            auto item = entries[i];
            if (item.clsId == chunkId) return item;
        }
        return null;
    }
}

shared class UDEntry : BufUtils {
    uint clsId;
    uint size;
    bool isHeavy;
    MemoryBuffer@ data = MemoryBuffer();

    UDEntry(MemoryBuffer@ buf, ParseLogger@ log) {
        @this.log = log;
        @this.buf = buf;
        log.parse_push('UDEntry');

        clsId = ReadUInt32('cls ID');
        size = ReadUInt32('ud entry size');
        isHeavy = size != (size | 0x80000000);
        size = size & 0x7FFFFFFF;

        log.parse_pop();
    }

    void ReadData() {
        log.trace("Reading header chunk of size: " + size);
        @data = buf.ReadBuffer(size);
        data.Seek(0);
        buf.Seek(data.GetSize(), 1);
        // log.parse("data["+size+"] (" + BufReadHex(data, 32) + ")", "bytes", "UD for " + Text::Format("%08x", clsId));
    }

    UDIcon@ AsIcon() {
        if (clsId != GBX_CHUNK_IDS::CGameItemModel_Icon) return null;
        return UDIcon(data, log);
    }
}

shared class UDIcon : BufUtils {
    uint16 width, height, webp_v;
    bool webp;
    MemoryBuffer@ imgBytes;

    UDIcon(MemoryBuffer@ data, ParseLogger@ log) {
        @this.log = log;
        @buf = data;
        buf.Seek(0);
        uint16 width_webp = ReadUInt16("width_webp");
        width = width_webp & 0x7FFF;
        uint16 height_webp = ReadUInt16("height_webp");
        height = height_webp & 0x7FFF;
        webp = 0x8000 == (width_webp & 0x8000) && (width_webp & 0x8000) == (height_webp & 0x8000);
        if (webp) {
            webp_v = ReadUInt16("webp_v");
            auto len = ReadUInt32("img bytes");
            @imgBytes = buf.ReadBuffer(len);
        } else {
            // struct, 1 byte each for rgba
            @imgBytes = buf.ReadBuffer(width * height * 4);

        }
        imgBytes.Seek(0);
        buf.Seek(0);
    }
}

shared class BufUtils {
    ParseLogger@ log = ParseLogger();
    MemoryBuffer@ buf;

    void SetLogger(bool quiet) {
        @log = ParseLogger(quiet);
    }
    string ReadString(const string &in annotation = "") {
        uint len = buf.ReadUInt32();
        string s = buf.ReadString(len);
        log.parse(s, "string", annotation);
        return s;
    }
    uint32 ReadUInt32(const string &in annotation = "") {
        auto u = buf.ReadUInt32();
        log.parse(u, annotation);
        return u;
    }
    int32 ReadInt32(const string &in annotation = "") {
        auto u = buf.ReadInt32();
        log.parse(u, annotation);
        return u;
    }
    uint16 ReadUInt16(const string &in annotation = "") {
        auto u = buf.ReadUInt16();
        log.parse(u, annotation);
        return u;
    }
    void SkipBytes(uint n, const string &in annotation = "") {
        buf.Seek(n, 1);
        log.parse("[+"+n+"]", "skipped bytes", annotation);
    }

    // string BufReadHex(MemoryBuffer@ data, uint len) {
    //     if (tempWrite_128b == 0) {
    //         tempWrite_128b = RequestMemory(200);
    //         print(tempWrite_128b);
    //         // tempWrite_128b = Dev::Allocate(128);
    //     }
    //     if (tempWrite_128b == 0) {
    //         throw('cannot write to 0 poitner');
    //     }
    //     len = Math::Min(len, data.GetSize());
    //     Dev::WriteCString(tempWrite_128b, data.ReadString(len));
    //     return Dev::Read(tempWrite_128b, len);
    // }
}


shared class ParseLogger {
    bool PrintParseLogs = false;
    string parseStack = "";
    string[] _parseStack;
    string[] logs;
    ParseLogger() {}
    ParseLogger(bool quiet) {
        PrintParseLogs = !quiet;
    }
    ~ParseLogger() {
    }

    void PrintAllAfterCrash(const string &in prefix = ">> ") {
        for (uint i = 0; i < logs.Length; i++) {
            print(prefix + logs[i]);
        }
    }

    void trace(const string &in msg) {
        logs.InsertLast(msg);
        if (PrintParseLogs)
            ::trace(msg);
    }
    void parse(const string &in str, const string &in type = "string", const string &in annotation = "") {
        auto msg = '[Parse | '+parseStack+'] '+type+': ' + str + (annotation.Length > 0 ? "  ("+annotation+")" : "");
        this.trace(msg);
    }

    void parse(uint32 u, const string &in annotation = "") {
        parse(Text::Format("%x = " + u, u), "uint32", annotation);
    }
    void parse(int32 u, const string &in annotation = "") {
        parse(Text::Format("%x = " + u, u), "int32", annotation);
    }
    void parse(uint16 u, const string &in annotation = "") {
        parse(Text::Format("%x = " + u, u), "uint16", annotation);
    }

    void parse_push(const string &in type) {
        _parseStack.InsertLast(type);
        parseStack = string::Join(_parseStack, " > ");
    }
    void parse_pop() {
        _parseStack.RemoveLast();
        parseStack = string::Join(_parseStack, " > ");
    }
    void parse_pop_all() {
        _parseStack.RemoveRange(0, _parseStack.Length);
        parseStack = "";
    }
}


#if DEV
void runGbxTest() {
    // Gbx@ test = Gbx(IO::FromUserGameFolder("x.LightMapCache.Gbx"), 128000, false);
    // Gbx@ test1 = Gbx(IO::FromUserGameFolder("Items/zzzy_DOWN_FIREWORK_10.Item.Gbx"));
    // Gbx@ test2 = Gbx("C:\\Users\\xertrov\\OpenplanetNext\\Extract\\GameData\\Stadium\\GameCtnBlockInfo\\GameCtnBlockInfoClassic\\RoadBumpBranchCross.EDClassic.Gbx");
    // Gbx@ test3 = Gbx("C:\\Users\\xertrov\\OpenplanetNext\\Extract\\GameData\\Stadium\\GameCtnBlockInfo\\GameCtnBlockInfoClassic\\DecoHillSlope2Curve2In.EDClassic.Gbx");
    // auto iconChunk = test.GetHeaderChunk(GBX_CHUNK_IDS::CGameItemModel_Icon);
    // auto icon = iconChunk.AsIcon();
    // @testTexture = UI::LoadTexture(icon.imgBytes);
    // auto iconBase64 = icon.imgBytes.ReadToBase64(icon.imgBytes.GetSize());
    // auto iconHash = Crypto::MD5(iconBase64);
    // trace('LOADED TEXTURE');
    // auto req = Net::HttpPost("http://localhost:8000/e++/icons/convert/webp", iconBase64);
    // while (!req.Finished()) yield();
    // auto iconBuf = req.Buffer();
    // trace('req status: ' + req.ResponseCode());
    // trace('got png size: ' + iconBuf.GetSize());
    // @testTexture = UI::LoadTexture(iconBuf);
}

UI::Texture@ testTexture;
#endif

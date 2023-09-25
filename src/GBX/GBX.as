// ptr to write to for getting hex
uint64 tempWrite_128b = 0;

const uint GBX_ITEM_MODEL_ICON_CLASS = 0x2E001004;

class Gbx : BufUtils {
    MemoryBuffer@ buf;

    Gbx(const string &in path, uint maxReadSize = 65536 / 2) {
        log_parse_pop_all();
        log_parse(path, "GbxFile", "Loading .gbx file.");
        try {
            IO::File f(path, IO::FileMode::Read);
            trace('Loading GBX file of length: ' + f.Size());
            @buf = f.Read(Math::Min(maxReadSize, f.Size()));
        } catch {
            error("Failed to open the file: " + getExceptionInfo());
            warn("File path: " + path);
        }
        // can be optimized to just read header
        ReadHeader();
    }

    Gbx(MemoryBuffer@ buf) {
        @this.buf = buf;
        ReadHeader();
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

    void ReadHeader() {
        if (buf.ReadString(3) != "GBX") {
            throw("Not a gbx file!");
        }
        hVersion = ReadUInt16('encoding version');
        if (hVersion < 6) throw('verison < 6 unsupported');
        // BU, C for compressed, U for uncompressed, then u01_R_or_E
        SkipBytes(4);
        hClassId = ReadUInt32('main class id');
        log_parse_push(Text::Format("%08x", hClassId));
        @userData = UserData(buf);
        nbNodes = ReadInt32('nb nodes');
        nbExternalNodes = ReadInt32('nb external nodes');
        // todo, read external nodes if they exist
        if (nbExternalNodes > 0) {
            auto ancestorLevel = ReadUInt32('ancestor level');
            @rootSubFolder = ExternalFolder(buf);
            // read external nodes
            log_parse_push("ExtNode");
            for (uint i = 0; i < nbExternalNodes; i++) {
                extNodes.InsertLast(ExternalNode(buf, hVersion, i));
            }
            log_parse_pop();
        }
        dataSize = ReadUInt32('data size');
        compressedDataSize = ReadUInt32('compressed size');
        // buf.Read(compressedDataSize)
    }

    UDEntry@ GetHeaderChunk(uint chunkId) {
        return userData.GetHeaderChunk(chunkId);
    }
}



class ExternalFolder : BufUtils {
    int nb;
    string[] strings;
    ExternalFolder@[] subFolders;
    MemoryBuffer@ buf;

    ExternalFolder(MemoryBuffer@ buf) {
        log_parse_push('SubFolder');
        @this.buf = buf;
        nb = ReadInt32("nb folders");
        for (int i = 0; i < nb; i++) {
            strings.InsertLast(ReadString('name'));
            subFolders.InsertLast(ExternalFolder(buf));
        }
        log_parse_pop();
    }
}

class ExternalNode : BufUtils {
    MemoryBuffer@ buf;
    ExternalNode(MemoryBuffer@ buf, uint hVersion, uint i) {
        @this.buf = buf;
        log_parse_push('ExtNode ' + i);

        auto flags = ReadUInt32();
        if (flags & 4 == 0) {
            ReadString('?');
        } else {
            ReadUInt32('?');
        }
        SkipBytes(4);
        if (hVersion >= 5)
            SkipBytes(4);
        if (flags & 4 == 0)
            SkipBytes(4);

        log_parse_pop();
    }
}


class UserData : BufUtils {
    MemoryBuffer@ buf;
    UDEntry@[] entries;
    uint size;
    uint nbChunks;

    UserData(MemoryBuffer@ buf) {
        @this.buf = buf;
        log_parse_push('UserData');

        size = ReadUInt32('total user data size');
        nbChunks = ReadUInt32('nb chunks');

        for (uint i = 0; i < nbChunks; i++) {
            entries.InsertLast(UDEntry(buf));
        }
        for (uint i = 0; i < entries.Length; i++) {
            entries[i].ReadData();
        }

        log_parse_pop();
    }

    UDEntry@ GetHeaderChunk(uint chunkId) {
        for (uint i = 0; i < entries.Length; i++) {
            auto item = entries[i];
            if (item.clsId == chunkId) return item;
        }
        return null;
    }
}

class UDEntry : BufUtils {
    MemoryBuffer@ buf;
    uint clsId;
    uint size;
    bool isHeavy;
    MemoryBuffer@ data = MemoryBuffer();

    UDEntry(MemoryBuffer@ buf) {
        @this.buf = buf;
        log_parse_push('UDEntry');

        clsId = ReadUInt32('cls ID');
        size = ReadUInt32('ud entry size');
        isHeavy = size != (size | 0x80000000);
        size = size & 0x7FFFFFFF;

        log_parse_pop();
    }

    void ReadData() {
        trace("Reading header chunk of size: " + size);
        @data = buf.ReadBuffer(size);
        data.Seek(0);
        buf.Seek(data.GetSize(), 1);
        log_parse("data["+size+"] (" + BufReadHex(data, 32) + ")", "bytes", "UD for " + Text::Format("%08x", clsId));
    }

    UDIcon@ AsIcon() {
        if (clsId != 0x2E001004) return null;
        return UDIcon(data);
    }
}

class UDIcon : BufUtils {
    MemoryBuffer@ buf;
    uint16 width, height, webp_v;
    bool webp;
    MemoryBuffer@ imgBytes;

    UDIcon(MemoryBuffer@ data) {
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

mixin class BufUtils {

    MemoryBuffer@ buf;

    string ReadString(const string &in annotation = "") {
        uint len = buf.ReadUInt32();
        string s = buf.ReadString(len);
        log_parse(s, "string", annotation);
        return s;
    }
    uint32 ReadUInt32(const string &in annotation = "") {
        auto u = buf.ReadUInt32();
        log_parse(u, annotation);
        return u;
    }
    int32 ReadInt32(const string &in annotation = "") {
        auto u = buf.ReadInt32();
        log_parse(u, annotation);
        return u;
    }
    uint16 ReadUInt16(const string &in annotation = "") {
        auto u = buf.ReadUInt16();
        log_parse(u, annotation);
        return u;
    }
    void SkipBytes(uint n, const string &in annotation = "") {
        buf.Seek(n, 1);
        log_parse("[+"+n+"]", "skipped bytes", annotation);
    }

    string BufReadHex(MemoryBuffer@ data, uint len) {
        if (tempWrite_128b == 0) {
            tempWrite_128b = RequestMemory(200);
            print(tempWrite_128b);
            // tempWrite_128b = Dev::Allocate(128);
        }
        if (tempWrite_128b == 0) {
            throw('cannot write to 0 poitner');
        }
        len = Math::Min(len, data.GetSize());
        Dev::WriteCString(tempWrite_128b, data.ReadString(len));
        return Dev::Read(tempWrite_128b, len);
    }
}


bool PrintParseLogs = true;
string parseStack = "";
string[] _parseStack;


void log_parse(const string &in str, const string &in type = "string", const string &in annotation = "") {
    if (PrintParseLogs)
        trace('[Parse | '+parseStack+'] '+type+': ' + str + (annotation.Length > 0 ? "  ("+annotation+")" : ""));
}

void log_parse(uint32 u, const string &in annotation = "") {
    log_parse(Text::Format("%x = " + u, u), "uint32", annotation);
}
void log_parse(int32 u, const string &in annotation = "") {
    log_parse(Text::Format("%x = " + u, u), "int32", annotation);
}
void log_parse(uint16 u, const string &in annotation = "") {
    log_parse(Text::Format("%x = " + u, u), "uint16", annotation);
}

void log_parse_push(const string &in type) {
    _parseStack.InsertLast(type);
    parseStack = string::Join(_parseStack, " > ");
}
void log_parse_pop() {
    _parseStack.RemoveLast();
    parseStack = string::Join(_parseStack, " > ");
}
void log_parse_pop_all() {
    _parseStack.RemoveRange(0, _parseStack.Length);
    parseStack = "";
}

#if DEV
void runGbxTest() {
    Gbx@ test1 = Gbx(IO::FromUserGameFolder("Items/zzzy_DOWN_FIREWORK_10.Item.Gbx"));
    Gbx@ test2 = Gbx("C:\\Users\\xertrov\\OpenplanetNext\\Extract\\GameData\\Stadium\\GameCtnBlockInfo\\GameCtnBlockInfoClassic\\RoadBumpBranchCross.EDClassic.Gbx");
    Gbx@ test = Gbx("C:\\Users\\xertrov\\OpenplanetNext\\Extract\\GameData\\Stadium\\GameCtnBlockInfo\\GameCtnBlockInfoClassic\\DecoHillSlope2Curve2In.EDClassic.Gbx");
    auto iconChunk = test.GetHeaderChunk(0x2E001004);
    auto icon = iconChunk.AsIcon();
    // @testTexture = UI::LoadTexture(icon.imgBytes);
    auto iconBase64 = icon.imgBytes.ReadToBase64(icon.imgBytes.GetSize());
    auto iconHash = Crypto::MD5(iconBase64);
    trace('LOADED TEXTURE');
    auto req = Net::HttpPost("http://localhost:8000/e++/icons/convert/webp", iconBase64);
    while (!req.Finished()) yield();
    auto iconBuf = req.Buffer();
    trace('req status: ' + req.ResponseCode());
    trace('got png size: ' + iconBuf.GetSize());
    @testTexture = UI::LoadTexture(iconBuf);
}

UI::Texture@ testTexture;
#endif

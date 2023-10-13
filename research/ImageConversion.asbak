

// for some house keeping
// Import::Library@ ole = Import::GetLibrary("ole32.dll");
// Import::Library@ combase = Import::GetLibrary("combase.dll");

// // for reading from zip
// Import::Library@ PROPSYS = Import::GetLibrary("PROPSYS.dll");
// Import::Library@ OLEAUT32 = Import::GetLibrary("OLEAUT32.dll");
// Import::Library@ SHELL32 = Import::GetLibrary("SHELL32.dll");
// Import::Library@ KERNEL32 = Import::GetLibrary("KERNEL32.dll");

// // need to set some things up before talking to win codecs
// Import::Function@ CoCreateInstance = ole.GetFunction("CoCreateInstance");
// Import::Function@ CoInitialize = ole.GetFunction("CoInitialize");
// Import::Function@ CoUninitialize = ole.GetFunction("CoUninitialize");

// // for interfacing with the shell to get files out of zip
// Import::Function@ SysAllocString = OLEAUT32.GetFunction("SysAllocString");
// Import::Function@ VariantClear = OLEAUT32.GetFunction("VariantClear");

// // Import::Function@ GetProcAddress = KERNEL32.GetFunction("GetProcAddress");

// // For extracting zip files
// Import::Function@ SHCreateItemFromParsingName = SHELL32.GetFunction("SHCreateItemFromParsingName");
// Import::Function@ SHGetIDListFromObject = SHELL32.GetFunction("SHGetIDListFromObject");
// Import::Function@ SHBindToHandler = SHELL32.GetFunction("SHBindToHandler");
// Import::Function@ SHRelease = SHELL32.GetFunction("SHRelease");
// Import::Function@ InvokeVerbEx = SHELL32.GetFunction("InvokeVerbEx");

// // win codecs required functions
// Import::Function@ IWICImagingFactory_CreateEncoder_Proxy = winCodec.GetFunction("IWICImagingFactory_CreateEncoder_Proxy");
// Import::Function@ IWICBitmapEncoder_Initialize_Proxy = winCodec.GetFunction("IWICBitmapEncoder_Initialize_Proxy");
// Import::Function@ IWICBitmapEncoder_CreateNewFrame_Proxy = winCodec.GetFunction("IWICBitmapEncoder_CreateNewFrame_Proxy");
// Import::Function@ IWICBitmapFrameEncode_Initialize_Proxy = winCodec.GetFunction("IWICBitmapFrameEncode_Initialize_Proxy");
// Import::Function@ IWICBitmapFrameEncode_SetSize_Proxy = winCodec.GetFunction("IWICBitmapFrameEncode_SetSize_Proxy");
// Import::Function@ IWICBitmapFrameEncode_SetPixelFormat_Proxy = winCodec.GetFunction("IWICBitmapFrameEncode_SetPixelFormat_Proxy");
// Import::Function@ IWICBitmapFrameEncode_WritePixels_Proxy = winCodec.GetFunction("IWICBitmapFrameEncode_WritePixels_Proxy");
// Import::Function@ IWICBitmapFrameEncode_Commit_Proxy = winCodec.GetFunction("IWICBitmapFrameEncode_Commit_Proxy");
// Import::Function@ IWICBitmapEncoder_Commit_Proxy = winCodec.GetFunction("IWICBitmapEncoder_Commit_Proxy");



const GUID@ CLSID_WICPngEncoder = GUID("27949969-876a-41d7-9447568f6a35a4dc");
const GUID@ CLSID_Shell = GUID("13709620-C279-11CE-A49E444553540000");



/* decode webp to png
- https://chromium.googlesource.com/webm/libwebp/+/0.2.0/examples/dwebp.c
*/
void ConvertWebPToPNG() {

}

void SaveOutput(MemoryBuffer@ decBuffer) {
    uint width, height;
    uint8[] bytes;
    uint stride;
    bool hasAlpha;
}

bool FAILED(int32 hr) {
    return hr < 0;
}
bool SUCCEEDED(int32 hr) {
    return hr < 0;
}


void ExtractZipTo(const string &in zipPath, const string &in destPath) {
    print(IO::FromAppFolder("libwebp.dll"));
    // Folder@ folder = Folder();
    WString@ zPath = WString(zipPath);
    Ptr@ shellItem = Ptr();
    GUID@ shellId = GUID("43826d1e-e718-42ee-bc55-a1e261c37bfe");
    print("shellId memory vs expected. \nexp: 43826d1e-e718-42ee-bc55-a1e261c37bfe\nmem: " + shellId.ToHex());
    trace('testing create item from parsing name');
    if (FAILED(DLL::SHCreateItemFromParsingName.CallInt32(zPath.ptr, uint64(0), shellId.ptr, shellItem.ptr))) {
        throw('failed to create item from parsing name');
    }
    // print('got shell item: ' + shellItem.Read());
}

class Ptr : Sized {
    Ptr() {
        super(8);
        Dev::Write(ptr, uint64(0));
    }

    uint64 Read() {
        return Dev::ReadUInt64(ptr);
    }
}

class WString : Sized {
    WString(const string &in str) {
        trace('creating WString');
        auto len = str.Length;
        super(len * 2 + 2);
        for (uint i = 0; i < len; i++) {
            Dev::Write(ptr + i * 2, uint8(0));
            Dev::Write(ptr + i * 2 + 1, uint8(str[i]));
        }
        Dev::Write(ptr + 2 * len, uint16(0));
        trace('done WString');
    }
}

class Sized {
    uint64 ptr;
    uint size;
    Sized(uint size) {
        this.size = size;
        ptr = Dev::Allocate(size + 16);
        if (ptr == 0) throw('null pointer');
    }
    ~Sized() {
        // op frees first
        // Dev::Free(ptr);
    }
    string ToHex() {
        return Dev::Read(ptr, size);
    }
}

class FolderItems : Sized {
    FolderItems() {
        super(8);
        Dev::Write(ptr, uint64(0));
    }
}



class GUID : Sized {
    uint d1;
    uint16 d2, d3;
    uint64 d4;

    GUID(const string &in str) {
        super(16);
        auto parts = str.Split("-");
        if (parts.Length == 5) {
            parts[3] += parts[4];
            parts.RemoveLast();
        }
        if (parts.Length != 4) {
            throw('bad GUID format');
        }
        d1 = uint(ParseHex(parts[0]));
        d2 = uint16(ParseHex(parts[1]));
        d3 = uint16(ParseHex(parts[2]));
        d4 = uint64(ParseHexBytes(parts[3]));
        Dev::Write(ptr + 0x0, d1);
        Dev::Write(ptr + 0x4, d2);
        Dev::Write(ptr + 0x6, d3);
        Dev::Write(ptr + 0x8, d4);
    }
}


uint64 ParseHex(const string &in hex) {
    string _hex = hex.Trim().ToLower();
    if (_hex.StartsWith("0x")) {
        _hex = _hex.SubStr(2);
    }
    uint64 r = 0;
    for (uint i = 0; i < _hex.Length; i++) {
        auto c = _hex[i];
        if (0x30 <= c && c <= 0x39) {
            r = (r << 4) + (c - 0x30);
        } else if (0x61 <= c && c <= 0x66) {
            r = (r << 4) + (c - 0x61 + 10);
        } else {
            warn('hex parse error for: ' + _hex);
            throw('char at (' + i + ') out of range: ' + c);
        }
    }
    return r;
}
uint64 ParseHexBytes(const string &in hex) {
    string _hex = hex.Trim().ToLower();
    if (_hex.StartsWith("0x")) {
        _hex = _hex.SubStr(2);
    }
    uint64 r = 0;
    if (_hex.Length % 2 != 0) throw('bad hex length');
    for (int i = _hex.Length - 2; i >= 0; i -= 2) {
        r = (r << 8) + uint8(ParseHex(_hex.SubStr(i, 2)));
    }
    return r;
}






#if DEV
void runZipTest() {
    // ExtractZipTo("C:\\ProgramData\\Trackmania\\Cache\\48C8022C413C310F14AA23D58AF6E18D1F5B21B889176FE177DF9628281CED30_076CB7309DBD48BB_Stadium_199A.Bump.LightMap.zip", IO::FromStorageFolder("lm\\").Replace("/", "\\"));
}
#endif

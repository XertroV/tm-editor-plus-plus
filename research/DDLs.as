namespace DLL {
    // for decoding webp
    Import::Library@ libwebp = Import::GetLibrary(IO::FromAppFolder("libwebp64.dll"));
    Import::Function@ WebPDecode = libwebp.GetFunction("WebPDecode");
    Import::Function@ WebPFreeDecBuffer = libwebp.GetFunction("WebPFreeDecBuffer");

    // for converting to png
    Import::Library@ winCodec = Import::GetLibrary("WindowsCodecs.dll");
    Import::Function@ IWICImagingFactory_CreateEncoder_Proxy = winCodec.GetFunction("IWICImagingFactory_CreateEncoder_Proxy");
    Import::Function@ IWICBitmapEncoder_Initialize_Proxy = winCodec.GetFunction("IWICBitmapEncoder_Initialize_Proxy");
    Import::Function@ IWICBitmapEncoder_CreateNewFrame_Proxy = winCodec.GetFunction("IWICBitmapEncoder_CreateNewFrame_Proxy");
    Import::Function@ IWICBitmapFrameEncode_Initialize_Proxy = winCodec.GetFunction("IWICBitmapFrameEncode_Initialize_Proxy");
    Import::Function@ IWICBitmapFrameEncode_SetSize_Proxy = winCodec.GetFunction("IWICBitmapFrameEncode_SetSize_Proxy");
    // Import::Function@ IWICBitmapFrameEncode_SetPixelFormat_Proxy = winCodec.GetFunction("IWICBitmapFrameEncode_SetPixelFormat_Proxy");
    // Import::Function@ IWICBitmapFrameEncode_WritePixels_Proxy = winCodec.GetFunction("IWICBitmapFrameEncode_WritePixels_Proxy");
    Import::Function@ IWICBitmapFrameEncode_Commit_Proxy = winCodec.GetFunction("IWICBitmapFrameEncode_Commit_Proxy");
    Import::Function@ IWICBitmapEncoder_Commit_Proxy = winCodec.GetFunction("IWICBitmapEncoder_Commit_Proxy");

    // for unzipping
    Import::Library@ SHELL32 = Import::GetLibrary("SHELL32.dll");
    Import::Function@ SHCreateItemFromParsingName = SHELL32.GetFunction("SHCreateItemFromParsingName");
    Import::Function@ SHGetIDListFromObject = SHELL32.GetFunction("SHGetIDListFromObject");
    uint16 SHBindToHandler_VTable = 4;
    // Import::Function@ SHRelease = SHELL32.GetFunction("SHRelease");
    // Import::Function@ InvokeVerbEx = SHELL32.GetFunction("FolderItem2_InvokeVerbEx");
    // 3, 4, 5

    // for unzipping
    Import::Library@ ole = Import::GetLibrary("ole32.dll");
    Import::Function@ CoCreateInstance = ole.GetFunction("CoCreateInstance");
    Import::Function@ CoInitialize = ole.GetFunction("CoInitialize");
    Import::Function@ CoUninitialize = ole.GetFunction("CoUninitialize");
}

// Import::Library@ ole = Import::GetLibrary("ole32.dll");
// Import::Function@ SysAllocString = OLEAUT32.GetFunction("SysAllocString");
// Import::Function@ VariantClear = OLEAUT32.GetFunction("VariantClear");

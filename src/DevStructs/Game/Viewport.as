/// ! This file is generated from ../../../codegen/Game/Viewport.xtoml !
/// ! Do not edit this file manually !

class DDx11Viewport : RawBufferElem {
	DDx11Viewport(RawBufferElem@ el) {
		if (el.ElSize != 29248) throw("invalid size for DDx11Viewport");
		super(el.Ptr, el.ElSize);
	}
	DDx11Viewport(uint64 ptr) {
		super(ptr, 29248);
	}
	DDx11Viewport(CDx11Viewport@ nod) {
		if (nod is null) throw("not a CDx11Viewport");
		super(Dev_GetPointerForNod(nod), 29248);
	}
	CDx11Viewport@ get_Nod() {
		return cast<CDx11Viewport>(Dev_GetNodFromPointer(ptr));
	}

	// DisplayNames + 0x10
	DxRenderStuff@ get_mDxRenderStuff() { auto _ptr = this.GetUint64(0x6E0); if (_ptr == 0) return null; return DxRenderStuff(_ptr); }
	// depth buffer: HyperZ.Texture
	CVisionResourceFile@ get_VisionResourceFile() { return cast<CVisionResourceFile>(this.GetNod(0x1170)); }
	// reshade identifies this as the depth buffer -- ptr matches
	uint64 get_DepthBufferSomething() { return (this.GetUint64(0x15c8)); }
	// from bitmap: +a8, +258
	CPlugBitmap@ get_HyperZBitmap() { return cast<CPlugBitmap>(this.GetNod(0x1620)); }
	CPlugBitmap@ get_DepthBufferBitmap() { return cast<CPlugBitmap>(this.GetNod(0x16c0)); }
	// ----------- 0x1b60 - 0x1b80
	// Some Dx11 related struct
	Dx11Stuff@ get_mDx11Stuff() { auto _ptr = this.GetUint64(0x1b60); if (_ptr == 0) return null; return Dx11Stuff(_ptr); }
	CHmsCamera@ get_camera() { return cast<CHmsCamera>(this.GetNod(0x1b68)); }
	CHmsZone@ get_zone() { return cast<CHmsZone>(this.GetNod(0x1b70)); }
	DepthBufferStructs@ get_mDepthBufferStructs() { return DepthBufferStructs(this.GetBuffer(0x840, 0x20, false)); }
}

class DepthBufferStructs : RawBuffer {
	DepthBufferStructs(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	DepthBufferStruct@ GetDepthBufferStruct(uint i) {
		return DepthBufferStruct(this[i]);
	}
}

// UNCHECKED, but it's an exposed offset
// Buffer: Display_Win32DeviceNames = wstring, 0x1b78, 0x10, false
// at least 0xAC0 big
class Dx11Stuff : RawBufferElem {
	Dx11Stuff(RawBufferElem@ el) {
		if (el.ElSize != 0xAC0) throw("invalid size for Dx11Stuff");
		super(el.Ptr, el.ElSize);
	}
	Dx11Stuff(uint64 ptr) {
		super(ptr, 0xAC0);
	}

	D3D11DepthStencilView@ get_depthStencilView() { return cast<D3D11DepthStencilView>(this.GetNod(0xAB8)); }
}


class DxRenderStuff : RawBufferElem {
	DxRenderStuff(RawBufferElem@ el) {
		if (el.ElSize != 0x158) throw("invalid size for DxRenderStuff");
		super(el.Ptr, el.ElSize);
	}
	DxRenderStuff(uint64 ptr) {
		super(ptr, 0x158);
	}

	D3D11Device@ get_mDevice() { auto _ptr = this.GetUint64(0xF0); if (_ptr == 0) return null; return D3D11Device(_ptr); }
	D3D11DeviceContext@ get_mDeviceCtx() { auto _ptr = this.GetUint64(0xF8); if (_ptr == 0) return null; return D3D11DeviceContext(_ptr); }
	D3D11DeviceContext@ get_mDeviceCtx2() { auto _ptr = this.GetUint64(0x100); if (_ptr == 0) return null; return D3D11DeviceContext(_ptr); }
	D3D11SwapChain@ get_mSwapChain() { auto _ptr = this.GetUint64(0x110); if (_ptr == 0) return null; return D3D11SwapChain(_ptr); }
}


class DepthBufferStruct : RawBufferElem {
	DepthBufferStruct(RawBufferElem@ el) {
		if (el.ElSize != 0x20) throw("invalid size for DepthBufferStruct");
		super(el.Ptr, el.ElSize);
	}
	DepthBufferStruct(uint64 ptr) {
		super(ptr, 0x20);
	}

	// todo: check offsets
	DPlugBitmap@ get_Bitmap() { return cast<DPlugBitmap>(this.GetNod(0x0)); }
	DRenderInfo@ get_RenderInfo() { auto _ptr = this.GetUint64(0x08); if (_ptr == 0) return null; return DRenderInfo(_ptr); }
	uint get_u1() { return (this.GetUint32(0x10)); }
	uint get_width() { return (this.GetUint32(0x14)); }
	uint get_height() { return (this.GetUint32(0x18)); }
	uint get_u2() { return (this.GetUint32(0x1C)); }
}


class D3D11DepthStencilView : RawBufferElem {
	D3D11DepthStencilView(RawBufferElem@ el) {
		if (el.ElSize != 0x8) throw("invalid size for D3D11DepthStencilView");
		super(el.Ptr, el.ElSize);
	}
	D3D11DepthStencilView(uint64 ptr) {
		super(ptr, 0x8);
	}

	uint64 get_vtable() { return (this.GetUint64(0x0)); }
}


class D3D11SwapChain : RawBufferElem {
	D3D11SwapChain(RawBufferElem@ el) {
		if (el.ElSize != 0x8) throw("invalid size for D3D11SwapChain");
		super(el.Ptr, el.ElSize);
	}
	D3D11SwapChain(uint64 ptr) {
		super(ptr, 0x8);
	}

	uint64 get_vtable() { return (this.GetUint64(0x0)); }
}


class D3D11Device : RawBufferElem {
	D3D11Device(RawBufferElem@ el) {
		if (el.ElSize != 0x8) throw("invalid size for D3D11Device");
		super(el.Ptr, el.ElSize);
	}
	D3D11Device(uint64 ptr) {
		super(ptr, 0x8);
	}

	uint64 get_vtable() { return (this.GetUint64(0x0)); }
}


class D3D11DeviceContext : RawBufferElem {
	D3D11DeviceContext(RawBufferElem@ el) {
		if (el.ElSize != 0x8) throw("invalid size for D3D11DeviceContext");
		super(el.Ptr, el.ElSize);
	}
	D3D11DeviceContext(uint64 ptr) {
		super(ptr, 0x8);
	}

	uint64 get_vtable() { return (this.GetUint64(0x0)); }
}


class D3D11Texture : RawBufferElem {
	D3D11Texture(RawBufferElem@ el) {
		if (el.ElSize != 0x8) throw("invalid size for D3D11Texture");
		super(el.Ptr, el.ElSize);
	}
	D3D11Texture(uint64 ptr) {
		super(ptr, 0x8);
	}

	uint64 get_vtable() { return (this.GetUint64(0x0)); }
}


// stored next to bitmap and also in the bitmap at 0xA8
// unsure of size, seems like 0x280
class DRenderInfo : RawBufferElem {
	DRenderInfo(RawBufferElem@ el) {
		if (el.ElSize != 0x280) throw("invalid size for DRenderInfo");
		super(el.Ptr, el.ElSize);
	}
	DRenderInfo(uint64 ptr) {
		super(ptr, 0x280);
	}

	// 0x130? -> 0xD0 to texture also
	DPlugBitmap@ get_Bitmap() { auto _ptr = this.GetUint64(0x200); if (_ptr == 0) return null; return DPlugBitmap(_ptr); }
	uint64 get_PtrTo_0x248() { return (this.GetUint64(0x250)); }
	D3D11Texture@ get_Texture() { auto _ptr = this.GetUint64(0x258); if (_ptr == 0) return null; return D3D11Texture(_ptr); }
}



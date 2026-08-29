#!/usr/bin/env python3
"""Minimal Gbx parser to dump chunk layout of .Macroblock.Gbx files."""
import struct, sys, lzma

def parse(path, dump_chunks=True):
    data = open(path, 'rb').read()
    assert data[:3] == b'GBX'
    ver = struct.unpack('<H', data[3:5])[0]
    fmt = chr(data[5]); ref_comp = chr(data[6]); body_comp = chr(data[7])
    class_id = struct.unpack('<I', data[9:13])[0]
    print(f"version={ver} fmt={fmt} refComp={ref_comp} bodyComp={body_comp} classId=0x{class_id:08X}")
    off = 13
    total_nodes_hint = struct.unpack('<I', data[off:off+4])[0]; off += 4
    num_header_chunks = struct.unpack('<I', data[off:off+4])[0]; off += 4
    print(f"totalNodesHint={total_nodes_hint} numHeaderChunks={num_header_chunks}")
    for i in range(num_header_chunks):
        cid, size = struct.unpack('<II', data[off:off+8]); off += 8
        heavy = bool(size & 0x80000000); size &= 0x7fffffff
        print(f"  header chunk 0x{cid:08X} size={size} heavy={heavy} data={data[off:off+min(size,32)].hex(' ')}")
        off += size
    num_nodes = struct.unpack('<I', data[off:off+4])[0]; off += 4
    print(f"refTable numNodes={num_nodes}")
    # ref table: for each node: u32 flags/class?, name string...
    # TM2020 ref table entries: u32 class? Actually: external node entries with index flags
    # Simpler: scan to find body by trying LZMA decompress at each offset
    body_off = None
    if body_comp == 'C':
        for o in range(off, min(len(data)-16, off+0x400)):
            try:
                d = lzma.LZMADecompressor()
                out = d.decompress(data[o:], lzma.format.FORMAT_ALONE)
                body_off = o
                body = out
                break
            except Exception:
                continue
    else:
        body_off = off
        body = data[off:]
    print(f"body offset=0x{body_off:x} decompressed size={len(body)}")
    if dump_chunks:
        o = 0
        while o + 8 <= len(body):
            cid, size = struct.unpack('<II', body[o:o+8])
            heavy = bool(size & 0x80000000); size &= 0x7fffffff
            if cid == 0 and size == 0:
                o += 8
                continue
            if cid > 0x10000000 or o+8+size > len(body):
                print(f"  ... stop at body+0x{o:x}: suspicious chunk 0x{cid:08X} size={size}")
                break
            print(f"  body chunk 0x{cid:08X} size={size} heavy={heavy}")
            o += 8 + size
            if cid & 0xFFF == 0xFACADE01:
                pass
    return body

if __name__ == '__main__':
    parse(sys.argv[1])

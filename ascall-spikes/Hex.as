#if DEV
// From spike-live-add-kinematic-ao StubLayout.as. AsCall writes the RWX stub with this.
namespace Hex {
    array<uint8> Parse(const string &in hex) {
        array<uint8> bytes;
        string digits = "";
        const string hexChars = "0123456789ABCDEFabcdef";
        for (uint i = 0; i < uint(hex.Length); i++) {
            string ch = hex.SubStr(i, 1);
            if (hexChars.IndexOf(ch) >= 0) {
                digits += ch;
                if (digits.Length == 2) {
                    bytes.InsertLast(uint8(Text::ParseInt(digits, 16)));
                    digits = "";
                }
            }
        }
        if (digits.Length != 0) throw("Hex::Parse: trailing nibble");
        return bytes;
    }

    string Dump(array<uint8> &in b) {
        string s = "";
        for (uint i = 0; i < b.Length; i++) {
            if (i > 0) s += " ";
            s += Text::Format("%02x", b[i]);
        }
        return s;
    }

    void Write(uint64 ptr, const string &in hex) {
        auto b = Parse(hex);
        for (uint i = 0; i < b.Length; i++) {
            Dev::Write(ptr + i, b[i]);
        }
    }

    string DumpLive(uint64 ptr, uint n) {
        if (ptr == 0 || n == 0) return "";
        array<uint8> b;
        for (uint i = 0; i < n; i++) {
            b.InsertLast(Dev::SafeReadUInt8(ptr + i));
        }
        return Dump(b);
    }

    bool BytesMatch(uint64 addr, const string &in hex) {
        if (addr == 0) return false;
        auto want = Parse(hex);
        for (uint i = 0; i < want.Length; i++) {
            if (Dev::SafeReadUInt8(addr + i) != want[i]) return false;
        }
        return true;
    }
}
#endif

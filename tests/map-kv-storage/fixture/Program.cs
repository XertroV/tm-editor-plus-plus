using System.Text;
using System.Security.Cryptography;
using GBX.NET;
using GBX.NET.Engines.Script;
using GBX.NET.LZO;
Gbx.LZO = new Lzo();
var output = args[0];
Directory.CreateDirectory(output);
const string sample = "quotes \" slash \\ LF\nCR\rTAB\t Unicode café 😀 <!-- --> /*EVENTS*/ /*TIMENOW*/\n";
var raw = new StringBuilder();
while (Encoding.UTF8.GetByteCount(raw.ToString()) + Encoding.UTF8.GetByteCount(sample) <= 10240) raw.Append(sample);
raw.Append('x', 10240 - Encoding.UTF8.GetByteCount(raw.ToString()));
var value = raw.ToString();
File.WriteAllText(Path.Combine(output, "expected.txt"), value, new UTF8Encoding(false));
var md = new CScriptTraitsMetadata();
md.CreateChunk<CScriptTraitsMetadata.Chunk11002000>();
md.Declare("_EKV_", new Dictionary<string, string> {
    ["_EKV_Storage.payload"] = value,
    ["_EKV_Storage.empty"] = "",
    ["_EKV_Storage.other"] = "second key remains intact"
});
md.Save(Path.Combine(output, "input.Gbx"));
Console.WriteLine($"payloadBytes={Encoding.UTF8.GetByteCount(value)} sha256={Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant()}");

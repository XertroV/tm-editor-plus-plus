void Main() {
    IO::File input(IO::FromUserGameFolder(FixtureDir + "expected.txt"), IO::FileMode::Read);
    string raw = input.ReadToEnd(); input.Close();
    string literal = ToML::MapKVStringLiteral(raw);
    IO::File output(IO::FromUserGameFolder(FixtureDir + "literal.txt"), IO::FileMode::Write);
    output.Write(literal); output.Close();
    print("KV-TRANSPORT literal generated from production function, rawBytes=" + raw.Length);
}

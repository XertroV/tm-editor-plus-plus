
// const int LZO_MIN_MATCH = 3; // Minimum match length
// const int LZO_MAX_OFFSET = 32768; // Maximum backward offset
// const int LZO_BLOCK_SIZE = 256; // LZO block size

// shared MemoryBuffer@ LZO_Decompress(MemoryBuffer@ compressedData, int compressedSize) {
//     compressedData.Seek(0);
//     int outputIndex = 0;
//     int inputIndex = 0;
//     uint8[] outArr;

//     while (inputIndex < compressedSize && !compressedData.AtEnd()) {
//         print(inputIndex);
//         uint8 token = compressedData.ReadUInt8();
//         inputIndex += 1;

//         // Check if it's a literal token
//         if (token < LZO_MIN_MATCH) {
//             // Copy literal byte to the output
//             outArr.InsertLast(token);
//             outputIndex += 1;
//         } else {
//             // It's a back-reference token
//             int length = token - LZO_MIN_MATCH + 1;
//             int distance = (uint32(compressedData.ReadUInt8()) << 8) | compressedData.ReadUInt8();
//             inputIndex += 2;

//             // Calculate the backward offset
//             int offset = outArr.Length - (distance + 1);
//             print('offset: ' + offset);

//             // Copy the corresponding bytes from the output buffer
//             for (int i = 0; i < length; i++) {
//                 outArr.InsertLast(outArr[offset + i]);
//                 outputIndex++;
//             }
//         }
//     }

//     auto outBuf = MemoryBuffer(outArr.Length);
//     for (uint i = 0; i < outArr.Length; i++) {
//         outBuf.Write(outArr[i]);
//     }
//     return outBuf;
// }

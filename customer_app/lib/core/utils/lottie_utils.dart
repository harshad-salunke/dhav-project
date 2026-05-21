import 'dart:io';
import 'dart:typed_data';
import 'package:lottie/lottie.dart';

/// Reads a .lottie (dotLottie) file by walking raw ZIP local-file headers
/// and decompressing via dart:io's ZLibDecoder(raw:true).
///
/// This bypasses the archive 4.x bug where ZipFile._rawContent shadows
/// ArchiveFile._rawContent, causing ArchiveFile.content to always return
/// empty bytes and triggering the startFrame == endFrame assertion.
Future<LottieComposition?> decodeDotLottie(List<int> bytes) async {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

  // Not a ZIP / dotLottie
  if (data.length < 4 || data[0] != 0x50 || data[1] != 0x4B) return null;

  int offset = 0;
  while (offset + 30 <= data.length) {
    // Local-file-header signature: PK\x03\x04
    if (data[offset] != 0x50 ||
        data[offset + 1] != 0x4B ||
        data[offset + 2] != 0x03 ||
        data[offset + 3] != 0x04) break;

    final compression  = _u16(data, offset + 8);
    final compressedSz = _u32(data, offset + 18);
    final fileNameLen  = _u16(data, offset + 26);
    final extraLen     = _u16(data, offset + 28);
    final dataStart    = offset + 30 + fileNameLen + extraLen;

    final fileName = String.fromCharCodes(
      data.sublist(offset + 30, offset + 30 + fileNameLen),
    );

    if (fileName.endsWith('.json')) {
      final compressed = data.sublist(dataStart, dataStart + compressedSz);
      // ZIP uses raw DEFLATE (method 8); method 0 = stored.
      final jsonBytes = compression == 8
          ? Uint8List.fromList(ZLibDecoder(raw: true).convert(compressed))
          : compressed;
      return LottieComposition.parseJsonBytes(jsonBytes);
    }

    offset = dataStart + compressedSz;
  }

  return null;
}

int _u16(Uint8List d, int i) => d[i] | (d[i + 1] << 8);
int _u32(Uint8List d, int i) =>
    d[i] | (d[i + 1] << 8) | (d[i + 2] << 16) | (d[i + 3] << 24);

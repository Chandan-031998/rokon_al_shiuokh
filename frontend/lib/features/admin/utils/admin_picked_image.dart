import 'dart:typed_data';

class AdminPickedImage {
  final Uint8List bytes;
  final String filename;
  final String contentType;

  const AdminPickedImage({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });
}

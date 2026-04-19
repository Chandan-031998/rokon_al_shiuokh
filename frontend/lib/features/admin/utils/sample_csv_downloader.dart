import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<bool> downloadSampleCsv({
  required String fileName,
  required String content,
}) async {
  final outputPath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save sample CSV',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: const ['csv'],
    bytes: Uint8List.fromList(utf8.encode(content)),
  );
  if (outputPath == null || outputPath.trim().isEmpty) {
    return false;
  }
  return true;
}

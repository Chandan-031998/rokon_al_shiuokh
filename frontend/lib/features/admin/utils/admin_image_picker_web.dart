// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'admin_picked_image.dart';

Future<AdminPickedImage?> pickAdminImage() {
  final completer = Completer<AdminPickedImage?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/png,image/jpeg,image/webp';

  void completeOnce(AdminPickedImage? image) {
    if (!completer.isCompleted) {
      completer.complete(image);
    }
  }

  void failOnce(String message) {
    if (!completer.isCompleted) {
      completer.completeError(Exception(message));
    }
  }

  input.onChange.first.then((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      completeOnce(null);
      return;
    }

    final reader = html.FileReader();
    reader.onLoad.first.then((_) {
      final result = reader.result;
      final bytes = result is ByteBuffer
          ? Uint8List.view(result)
          : result is Uint8List
              ? result
              : null;
      if (bytes == null || bytes.isEmpty) {
        failOnce('Unable to read the selected image.');
        return;
      }
      completeOnce(
        AdminPickedImage(
          bytes: bytes,
          filename: file.name,
          contentType: _normalizeContentType(file.type, file.name),
        ),
      );
    });
    reader.onError.first.then((_) {
      failOnce('Unable to read the selected image.');
    });
    reader.readAsArrayBuffer(file);
  });

  input.click();
  return completer.future;
}

String _normalizeContentType(String rawType, String filename) {
  final type = rawType.trim().toLowerCase();
  if (type == 'image/jpeg' || type == 'image/png' || type == 'image/webp') {
    return type;
  }

  final lower = filename.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/png';
}

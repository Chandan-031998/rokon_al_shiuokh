import 'package:file_picker/file_picker.dart';

import 'admin_picked_image.dart';

Future<AdminPickedImage?> pickAdminImage() async {
  final file = await FilePicker.platform.pickFiles(
    withData: true,
    type: FileType.image,
  );
  final selected = file?.files.single;
  final bytes = selected?.bytes;
  if (selected == null || bytes == null || bytes.isEmpty) {
    return null;
  }
  return AdminPickedImage(
    bytes: bytes,
    filename: selected.name,
    contentType: _contentTypeForName(selected.name),
  );
}

String _contentTypeForName(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/png';
}

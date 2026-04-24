import 'admin_image_picker_stub.dart'
    if (dart.library.html) 'admin_image_picker_web.dart'
    if (dart.library.io) 'admin_image_picker_io.dart' as impl;
import 'admin_picked_image.dart';

Future<AdminPickedImage?> pickAdminImage() => impl.pickAdminImage();

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class ImageStore {
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  Future<String?> pickFromGalleryAndStore({required String folderName}) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return null;
    return _copyToAppDir(file.path, folderName);
  }

  Future<String?> takePhotoAndStore({required String folderName}) async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null) return null;
    return _copyToAppDir(file.path, folderName);
  }

  Future<String> _copyToAppDir(String srcPath, String folderName) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(join(dir.path, 'images', folderName));
    if (!await folder.exists()) await folder.create(recursive: true);

    final ext = extension(srcPath).isEmpty ? '.jpg' : extension(srcPath);
    final name = '${_uuid.v4()}$ext';
    final dest = join(folder.path, name);

    await File(srcPath).copy(dest);
    return dest;
  }
}

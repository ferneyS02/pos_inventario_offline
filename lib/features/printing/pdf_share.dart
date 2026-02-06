import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart';

class PdfShare {
  static Future<void> shareBytes(
    Uint8List bytes, {
    required String filename,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(join(dir.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: filename);
  }
}

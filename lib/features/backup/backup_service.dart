import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/db/app_db.dart';

class BackupService {
  Future<File> exportBackup() async {
    // Cerrar DB para copiarla segura
    await AppDb.close();

    final dbPath = await AppDb.dbFilePath();
    final dbFile = File(dbPath);

    final docs = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(join(docs.path, 'images'));

    final outDir = Directory(join(docs.path, 'backups'));
    if (!await outDir.exists()) await outDir.create(recursive: true);

    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final zipPath = join(outDir.path, 'backup_$ts.zip');

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    if (await dbFile.exists()) {
      encoder.addFile(dbFile);
    }

    if (await imagesDir.exists()) {
      encoder.addDirectory(imagesDir);
    }

    encoder.close();

    // Reabrir DB
    await AppDb.get();

    return File(zipPath);
  }

  Future<bool> importBackupFromZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return false;

    final zipFile = File(result.files.single.path!);

    // cerrar DB antes de reemplazar
    await AppDb.close();

    final tmp = await getTemporaryDirectory();
    final extractDir = Directory(join(tmp.path, 'restore_extract'));
    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
    await extractDir.create(recursive: true);

    // extraer zip
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final f in archive) {
      final outPath = join(extractDir.path, f.name);
      if (f.isFile) {
        final out = File(outPath);
        await out.create(recursive: true);
        await out.writeAsBytes(f.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }

    // localizar DB extraída
    File? extractedDb;
    for (final f in extractDir.listSync(recursive: true)) {
      if (f is File && basename(f.path) == 'pos_local.db') {
        extractedDb = f;
        break;
      }
    }
    if (extractedDb == null) {
      // reabrir DB aunque falle
      await AppDb.get();
      return false;
    }

    // reemplazar DB
    final targetDbPath = await AppDb.dbFilePath();
    final targetDbFile = File(targetDbPath);
    if (await targetDbFile.exists()) {
      await targetDbFile.delete();
    }
    await extractedDb.copy(targetDbPath);

    // reemplazar carpeta images si existe en backup
    final docs = await getApplicationDocumentsDirectory();
    final targetImages = Directory(join(docs.path, 'images'));

    final extractedImages = Directory(join(extractDir.path, 'images'));
    if (await extractedImages.exists()) {
      if (await targetImages.exists()) {
        await targetImages.delete(recursive: true);
      }
      await _copyDir(extractedImages, targetImages);
    }

    // limpiar temp
    try {
      await extractDir.delete(recursive: true);
    } catch (_) {}

    // reabrir DB
    await AppDb.get();
    return true;
  }

  Future<void> _copyDir(Directory src, Directory dst) async {
    if (!await dst.exists()) await dst.create(recursive: true);
    await for (final entity in src.list(recursive: false)) {
      final name = basename(entity.path);
      final newPath = join(dst.path, name);
      if (entity is Directory) {
        await _copyDir(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }
}

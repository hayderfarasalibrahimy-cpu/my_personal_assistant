import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FileService {
  static const String _mediaDirName = 'media';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(path.join(directory.path, _mediaDirName));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir.path;
  }

  Future<String> saveFile(String sourcePath, String type) async {
    final mediaPath = await _localPath;
    final sourceFile = File(sourcePath);
    final ext = path.extension(sourcePath);
    final fileName = '${type}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destinationPath = path.join(mediaPath, fileName);

    await sourceFile.copy(destinationPath);
    return destinationPath;
  }

  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String> getMediaPath() async {
    return await _localPath;
  }
}

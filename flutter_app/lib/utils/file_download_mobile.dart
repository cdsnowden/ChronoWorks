// Mobile-specific file download implementation
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void downloadFile(String content, String filename) {
  _saveFile(content, filename);
}

Future<void> _saveFile(String content, String filename) async {
  try {
    // Get the downloads directory or app documents directory
    Directory? directory;

    if (Platform.isAndroid) {
      // On Android, try to get the downloads directory
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      // On iOS, use the documents directory
      directory = await getApplicationDocumentsDirectory();
    }

    if (directory == null) {
      directory = await getApplicationDocumentsDirectory();
    }

    // Create the file path
    final filePath = '${directory.path}/$filename';
    final file = File(filePath);

    // Write the content to the file
    await file.writeAsString(content);

    // File saved successfully - the path is:
    // Android: /storage/emulated/0/Download/filename or app storage
    // iOS: App Documents directory
    print('File saved to: $filePath');
  } catch (e) {
    print('Failed to save file: $e');
    rethrow;
  }
}

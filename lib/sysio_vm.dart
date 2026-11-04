import 'dart:io';

/// Native file write for backups picked via the save dialog.
Future<bool> writeFile(String path, String data) async {
  try {
    await File(path).writeAsString(data);
    return true;
  } catch (_) {
    return false;
  }
}

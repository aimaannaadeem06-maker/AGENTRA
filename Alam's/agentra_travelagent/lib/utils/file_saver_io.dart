import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> downloadOrSaveFile(List<int> bytes, String fileName) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (e) {
    return null;
  }
}

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String?> downloadOrSaveFile(List<int> bytes, String fileName) async {
  try {
    final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return 'Downloaded ($fileName)';
  } catch (e) {
    return null;
  }
}

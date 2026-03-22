import 'dart:convert';

import 'package:file_selector/file_selector.dart';

class ExportFileService {
  const ExportFileService();

  Future<String?> saveCsvBase64({
    required String filename,
    required String contentBase64,
  }) async {
    final bytes = base64Decode(contentBase64);
    final location = await getSaveLocation(
      suggestedName: filename,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (location == null) {
      return null;
    }
    await XFile.fromData(
      bytes,
      mimeType: 'text/csv',
      name: filename,
    ).saveTo(location.path);
    return location.path;
  }
}

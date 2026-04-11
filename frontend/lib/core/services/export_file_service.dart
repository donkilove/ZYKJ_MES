import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

class ExportFileService {
  const ExportFileService();

  Future<String?> saveBytes({
    required String filename,
    required List<int> bytes,
    required String mimeType,
    required String format,
  }) async {
    final acceptedTypeGroups = switch (format) {
      'excel' => const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
      _ => const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    };
    final location = await getSaveLocation(
      suggestedName: filename,
      acceptedTypeGroups: acceptedTypeGroups,
    );
    if (location == null) {
      return null;
    }
    await XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: mimeType,
      name: filename,
    ).saveTo(location.path);
    return location.path;
  }

  Future<String?> saveCsvBase64({
    required String filename,
    required String contentBase64,
  }) async {
    return saveBytes(
      filename: filename,
      bytes: base64Decode(contentBase64),
      mimeType: 'text/csv',
      format: 'csv',
    );
  }
}

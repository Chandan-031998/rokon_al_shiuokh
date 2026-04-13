class ImportFailureRow {
  final int row;
  final String error;

  const ImportFailureRow({
    required this.row,
    required this.error,
  });

  factory ImportFailureRow.fromJson(Map<String, dynamic> json) {
    return ImportFailureRow(
      row: (json['row'] as num?)?.toInt() ?? 0,
      error: (json['error'] as String? ?? '').trim(),
    );
  }
}

class AdminImportResult {
  final int imported;
  final int updated;
  final List<ImportFailureRow> failedRows;

  const AdminImportResult({
    required this.imported,
    required this.updated,
    required this.failedRows,
  });

  factory AdminImportResult.fromJson(Map<String, dynamic> json) {
    final rawFailures = json['failed_rows'];
    return AdminImportResult(
      imported: (json['imported'] as num?)?.toInt() ?? 0,
      updated: (json['updated'] as num?)?.toInt() ?? 0,
      failedRows: rawFailures is List
          ? rawFailures
              .whereType<Map<String, dynamic>>()
              .map(ImportFailureRow.fromJson)
              .toList()
          : const <ImportFailureRow>[],
    );
  }
}

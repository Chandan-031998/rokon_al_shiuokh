import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../localization/app_localizations.dart';
import '../models/admin_import_result.dart';
import '../services/admin_api_service.dart';
import '../utils/sample_csv_downloader.dart';
import '../widgets/admin_page_frame.dart';

class AdminImportPage extends StatefulWidget {
  final AdminApiService apiService;

  const AdminImportPage({
    super.key,
    required this.apiService,
  });

  @override
  State<AdminImportPage> createState() => _AdminImportPageState();
}

class _AdminImportPageState extends State<AdminImportPage> {
  static const _sampleCsv = 'name,name_ar,short_description,full_description,price,sale_price,stock,pack_size,category,branch,tags,image_url,featured,active,sku\n'
      'Premium Arabic Coffee,قهوة عربية فاخرة,Signature coffee blend,Full tasting notes for majlis service,28.00,24.00,120,500g,Coffee,Mahayil Aseer (Main Branch),"coffee,arabic,premium",https://example.com/coffee.png,true,true,COF-500\n'
      'Luxury Saffron Mix,خلطة زعفران فاخرة,Rich saffron spice blend,Imported saffron with aromatic notes,39.00,,80,250g,Spices,Abha Branch,"saffron,spice,luxury",https://example.com/saffron.png,true,true,SPI-250';

  static const _requiredHeaders = <String>{
    'name',
    'price',
    'category',
  };

  bool _importing = false;
  String? _selectedFileName;
  AdminImportResult? _result;
  _ImportPreflightResult? _preflight;

  Future<void> _pickAndImport() async {
    final file = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    final selected = file?.files.single;
    final bytes = selected?.bytes;
    if (selected == null || bytes == null || bytes.isEmpty) {
      return;
    }

    final decoded = _decodeCsv(bytes);
    if (decoded == null) {
      _showMessage('CSV must be UTF-8 encoded.');
      return;
    }

    final preflight = _validateCsv(decoded);
    setState(() {
      _selectedFileName = selected.name;
      _preflight = preflight;
    });
    if (!preflight.isValid) {
      _showMessage('Fix CSV validation errors before importing.');
      return;
    }

    setState(() {
      _importing = true;
      _selectedFileName = selected.name;
    });
    try {
      final result = await widget.apiService.importProducts(
        bytes: bytes,
        filename: selected.name,
      );
      if (!mounted) {
        return;
      }
      setState(() => _result = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('admin_import_success'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _downloadSampleCsv() async {
    final downloaded = await downloadSampleCsv(
      fileName: 'rokon_products_import_sample.csv',
      content: _sampleCsv,
    );
    if (!mounted) {
      return;
    }
    if (downloaded) {
      _showMessage('Sample CSV downloaded.');
      return;
    }
    await Clipboard.setData(const ClipboardData(text: _sampleCsv));
    _showMessage('Sample CSV copied to clipboard.');
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _decodeCsv(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return null;
    }
  }

  _ImportPreflightResult _validateCsv(String content) {
    final normalized = content.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return const _ImportPreflightResult(
        isValid: false,
        rowCount: 0,
        headers: <String>[],
        errors: <String>['The CSV file is empty.'],
      );
    }

    final lines = normalized
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return const _ImportPreflightResult(
        isValid: false,
        rowCount: 0,
        headers: <String>[],
        errors: <String>['The CSV file is empty.'],
      );
    }

    final headers = _parseCsvLine(lines.first)
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final missingHeaders = _requiredHeaders
        .where((header) => !headers.contains(header))
        .toList();
    final errors = <String>[
      if (missingHeaders.isNotEmpty)
        'Missing required headers: ${missingHeaders.join(', ')}',
    ];

    final rowCount = lines.length > 1 ? lines.length - 1 : 0;
    for (var index = 1; index < lines.length; index += 1) {
      final columns = _parseCsvLine(lines[index]);
      if (columns.every((column) => column.trim().isEmpty)) {
        continue;
      }
      if (columns.length < headers.length) {
        errors.add('Row ${index + 1} has fewer columns than the header.');
      }
    }

    return _ImportPreflightResult(
      isValid: errors.isEmpty && rowCount > 0,
      rowCount: rowCount,
      headers: headers,
      errors: errors.isEmpty && rowCount == 0
          ? const <String>['The CSV does not contain any product rows.']
          : errors,
    );
  }

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var index = 0; index < line.length; index += 1) {
      final char = line[index];
      if (char == '"') {
        if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index += 1;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (char == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    values.add(buffer.toString());
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AdminPageFrame(
      title: l10n.t('admin_import_title'),
      subtitle: l10n.t('admin_import_subtitle'),
      actions: [
        OutlinedButton.icon(
          onPressed: _downloadSampleCsv,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Sample CSV'),
        ),
        ElevatedButton.icon(
          onPressed: _importing ? null : _pickAndImport,
          icon: const Icon(Icons.upload_file),
          label: Text(
            _importing
                ? l10n.t('common_importing')
                : l10n.t('admin_import_upload'),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('admin_import_sample_columns'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                const SelectableText(
                  _sampleCsv,
                ),
                if ((_selectedFileName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(l10n.t('admin_import_selected_file',
                      {'name': _selectedFileName!})),
                ],
                if (_preflight != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Preflight validation',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Headers detected: ${_preflight!.headers.join(', ')}'),
                  Text('Rows detected: ${_preflight!.rowCount}'),
                  Text(
                    _preflight!.isValid
                        ? 'Validation passed.'
                        : 'Validation failed.',
                    style: TextStyle(
                      color: _preflight!.isValid
                          ? const Color(0xFF4C8A5A)
                          : const Color(0xFF9A4D45),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_preflight!.errors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ..._preflight!.errors.map(Text.new),
                  ],
                ],
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.t('admin_import_summary'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(l10n.t('admin_import_imported',
                      {'count': '${_result!.imported}'})),
                  Text(l10n.t('admin_import_updated',
                      {'count': '${_result!.updated}'})),
                  Text(l10n.t('admin_import_failed_rows',
                      {'count': '${_result!.failedRows.length}'})),
                  if (_result!.failedRows.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(l10n.t('admin_import_row_errors'),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._result!.failedRows.map(
                      (failure) => Text(l10n.t('admin_import_row_error', {
                        'row': '${failure.row}',
                        'error': failure.error,
                      })),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImportPreflightResult {
  final bool isValid;
  final int rowCount;
  final List<String> headers;
  final List<String> errors;

  const _ImportPreflightResult({
    required this.isValid,
    required this.rowCount,
    required this.headers,
    required this.errors,
  });
}

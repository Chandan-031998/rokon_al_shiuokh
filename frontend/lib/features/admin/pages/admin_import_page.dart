import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/admin_import_result.dart';
import '../services/admin_api_service.dart';
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
  bool _importing = false;
  String? _selectedFileName;
  AdminImportResult? _result;

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
        const SnackBar(content: Text('Bulk import completed.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: 'Bulk Import',
      subtitle: 'Upload a CSV to create or update products in bulk with row-level validation feedback.',
      actions: [
        ElevatedButton.icon(
          onPressed: _importing ? null : _pickAndImport,
          icon: const Icon(Icons.upload_file),
          label: Text(_importing ? 'Importing...' : 'Upload CSV'),
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
                Text('Sample CSV Columns', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                const SelectableText(
                  'name,name_ar,description,price,category,branch,stock,pack_size,image_url,featured,sku\n'
                  'Premium Arabic Coffee,قهوة عربية فاخرة,Signature coffee blend,28.00,Coffee,Mahayil Aseer (Main Branch),120,500g,https://example.com/coffee.png,true,COF-500',
                ),
                if ((_selectedFileName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Selected file: $_selectedFileName'),
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
                  Text('Import Summary', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text('Imported: ${_result!.imported}'),
                  Text('Updated: ${_result!.updated}'),
                  Text('Failed Rows: ${_result!.failedRows.length}'),
                  if (_result!.failedRows.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('Row-Level Errors', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._result!.failedRows.map(
                      (failure) => Text('Row ${failure.row}: ${failure.error}'),
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

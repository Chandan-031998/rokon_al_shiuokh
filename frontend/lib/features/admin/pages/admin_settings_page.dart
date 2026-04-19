import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../models/category_model.dart';
import '../../../../models/discovery_filter_models.dart';
import '../../../../models/product_model.dart';
import '../../../../models/search_term_model.dart';
import '../admin_session_controller.dart';
import '../services/admin_api_service.dart';
import '../widgets/admin_page_frame.dart';

class AdminSettingsPage extends StatefulWidget {
  final AdminSessionController sessionController;
  final AdminApiService apiService;

  const AdminSettingsPage({
    super.key,
    required this.sessionController,
    required this.apiService,
  });

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _productSearchController = TextEditingController();
  bool? _hiddenFilter;
  bool _loading = true;
  String? _error;
  List<ProductModel> _discoveryProducts = const [];
  List<SearchTermModel> _searchTerms = const [];
  List<DiscoveryFilterGroupModel> _filterGroups = const [];
  List<DiscoveryFilterValueModel> _filterValues = const [];
  List<CategoryModel> _categories = const [];
  List<ProductModel> _allProducts = const [];
  int? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.apiService.fetchDiscoveryProducts(
          search: _productSearchController.text,
          hidden: _hiddenFilter,
        ),
        widget.apiService.fetchSearchTerms(),
        widget.apiService.fetchFilterGroups(),
        widget.apiService.fetchCategories(),
        widget.apiService.fetchProducts(),
      ]);
      final groups = results[2] as List<DiscoveryFilterGroupModel>;
      final selectedGroupId = _selectedGroupId != null &&
              groups.any((group) => group.id == _selectedGroupId)
          ? _selectedGroupId
          : (groups.isNotEmpty ? groups.first.id : null);
      final filterValues = selectedGroupId == null
          ? const <DiscoveryFilterValueModel>[]
          : await widget.apiService.fetchFilterValues(groupId: selectedGroupId);

      if (!mounted) {
        return;
      }
      setState(() {
        _discoveryProducts = results[0] as List<ProductModel>;
        _searchTerms = results[1] as List<SearchTermModel>;
        _filterGroups = groups;
        _categories = results[3] as List<CategoryModel>;
        _allProducts = results[4] as List<ProductModel>;
        _selectedGroupId = selectedGroupId;
        _filterValues = filterValues;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _reloadDiscoveryProducts() async {
    try {
      final products = await widget.apiService.fetchDiscoveryProducts(
        search: _productSearchController.text,
        hidden: _hiddenFilter,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _discoveryProducts = products;
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reloadSearchTerms() async {
    try {
      final items = await widget.apiService.fetchSearchTerms();
      if (!mounted) {
        return;
      }
      setState(() {
        _searchTerms = items;
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reloadFilterGroups() async {
    try {
      final groups = await widget.apiService.fetchFilterGroups();
      final selectedGroupId = _selectedGroupId != null &&
              groups.any((group) => group.id == _selectedGroupId)
          ? _selectedGroupId
          : (groups.isNotEmpty ? groups.first.id : null);
      final values = selectedGroupId == null
          ? const <DiscoveryFilterValueModel>[]
          : await widget.apiService.fetchFilterValues(groupId: selectedGroupId);
      if (!mounted) {
        return;
      }
      setState(() {
        _filterGroups = groups;
        _selectedGroupId = selectedGroupId;
        _filterValues = values;
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reloadFilterValues() async {
    if (_selectedGroupId == null) {
      setState(() {
        _filterValues = const [];
      });
      return;
    }
    try {
      final values =
          await widget.apiService.fetchFilterValues(groupId: _selectedGroupId);
      if (!mounted) {
        return;
      }
      setState(() {
        _filterValues = values;
      });
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
      ),
    );
  }

  Future<void> _editDiscoveryProduct(ProductModel product) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DiscoveryProductDialog(
        apiService: widget.apiService,
        product: product,
      ),
    );
    if (changed == true) {
      await _reloadDiscoveryProducts();
    }
  }

  Future<void> _editSearchTerm([SearchTermModel? term]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SearchTermDialog(
        apiService: widget.apiService,
        term: term,
        categories: _categories,
        products: _allProducts,
      ),
    );
    if (changed == true) {
      await _reloadSearchTerms();
    }
  }

  Future<void> _deleteSearchTerm(SearchTermModel term) async {
    final confirmed = await _confirm(
      title: 'Delete Search Term',
      message: 'Delete "${term.term}" from the discovery catalog?',
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.apiService.deleteSearchTerm(term.id);
      await _reloadSearchTerms();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _editFilterGroup([DiscoveryFilterGroupModel? group]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FilterGroupDialog(
        apiService: widget.apiService,
        group: group,
        categories: _categories,
      ),
    );
    if (changed == true) {
      await _reloadFilterGroups();
    }
  }

  Future<void> _deleteFilterGroup(DiscoveryFilterGroupModel group) async {
    final confirmed = await _confirm(
      title: 'Delete Filter Group',
      message:
          'Delete "${group.name}" and its assigned values from discovery settings?',
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.apiService.deleteFilterGroup(group.id);
      await _reloadFilterGroups();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _editFilterValue([DiscoveryFilterValueModel? value]) async {
    if (_filterGroups.isEmpty) {
      return;
    }
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FilterValueDialog(
        apiService: widget.apiService,
        value: value,
        groups: _filterGroups,
        products: _allProducts,
        defaultGroupId: _selectedGroupId,
      ),
    );
    if (changed == true) {
      await _reloadFilterGroups();
    }
  }

  Future<void> _deleteFilterValue(DiscoveryFilterValueModel value) async {
    final confirmed = await _confirm(
      title: 'Delete Filter Value',
      message: 'Delete "${value.value}" from the selected filter group?',
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.apiService.deleteFilterValue(value.id);
      await _reloadFilterValues();
      await _reloadFilterGroups();
    } catch (error) {
      _showError(error);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.sessionController.user;

    return DefaultTabController(
      length: 3,
      child: AdminPageFrame(
        title: 'Settings',
        subtitle:
            'Control searchability, filter definitions, and operational admin access from one workspace.',
        actions: [
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const TabBar(
                          tabs: [
                            Tab(text: 'Search Config'),
                            Tab(text: 'Filters'),
                            Tab(text: 'Admin Session'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 880,
                        child: TabBarView(
                          children: [
                            _buildSearchConfigTab(),
                            _buildFiltersTab(),
                            _buildSessionTab(user),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSearchConfigTab() {
    final searchableCount = _discoveryProducts
        .where((product) => !product.isHiddenFromSearch)
        .length;

    return ListView(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(
              label: 'Searchable Products',
              value: '$searchableCount',
              helper: 'Visible to search endpoints',
            ),
            _MetricCard(
              label: 'Hidden Products',
              value:
                  '${_discoveryProducts.where((product) => product.isHiddenFromSearch).length}',
              helper: 'Excluded from query results',
            ),
            _MetricCard(
              label: 'Search Terms',
              value: '${_searchTerms.length}',
              helper: 'Popular and featured prompts',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Product Searchability',
          subtitle:
              'Manage product tags, explicit keywords, synonyms, and hidden-from-search state.',
          action: null,
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 900;
                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _searchConfigFilters(compact: true),
                        )
                      : Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          children: _searchConfigFilters(compact: false),
                        );
                },
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  dataRowMinHeight: 72,
                  dataRowMaxHeight: 86,
                  columns: const [
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Tags')),
                    DataColumn(label: Text('Keywords')),
                    DataColumn(label: Text('Synonyms')),
                    DataColumn(label: Text('Hidden')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _discoveryProducts
                      .map(
                        (product) => DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 220,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      product.sku ?? '-',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(_TrimmedCell(product.tags)),
                            DataCell(_TrimmedCell(product.searchKeywords)),
                            DataCell(_TrimmedCell(product.searchSynonyms)),
                            DataCell(
                              Icon(
                                product.isHiddenFromSearch
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: product.isHiddenFromSearch
                                    ? const Color(0xFF9A4D45)
                                    : const Color(0xFF4C8A5A),
                              ),
                            ),
                            DataCell(
                              TextButton(
                                onPressed: () => _editDiscoveryProduct(product),
                                child: const Text('Edit'),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Popular and Featured Search Terms',
          subtitle:
              'Shape suggestion rails and merchandised discovery prompts for the customer app.',
          action: ElevatedButton.icon(
            onPressed: () => _editSearchTerm(),
            icon: const Icon(Icons.add),
            label: const Text('Add Search Term'),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 68,
              dataRowMaxHeight: 82,
              columns: const [
                DataColumn(label: Text('Term')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Synonyms')),
                DataColumn(label: Text('Linked Target')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _searchTerms
                  .map(
                    (term) => DataRow(
                      cells: [
                        DataCell(Text(term.term)),
                        DataCell(Text(term.termType)),
                        DataCell(_TrimmedCell(term.synonyms)),
                        DataCell(
                          Text(
                            term.linkedProductId != null
                                ? 'Product #${term.linkedProductId}'
                                : term.linkedCategoryId != null
                                    ? 'Category #${term.linkedCategoryId}'
                                    : '-',
                          ),
                        ),
                        DataCell(
                          Icon(
                            term.isActive
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                            color: term.isActive
                                ? const Color(0xFF4C8A5A)
                                : AppColors.muted,
                          ),
                        ),
                        DataCell(
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _editSearchTerm(term),
                                child: const Text('Edit'),
                              ),
                              TextButton(
                                onPressed: () => _deleteSearchTerm(term),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _searchConfigFilters({required bool compact}) {
    return [
      SizedBox(
        width: compact ? double.infinity : 320,
        child: TextField(
          controller: _productSearchController,
          decoration: const InputDecoration(
            labelText: 'Product search',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (_) => _reloadDiscoveryProducts(),
        ),
      ),
      SizedBox(
        width: compact ? double.infinity : 220,
        child: DropdownButtonFormField<bool?>(
          initialValue: _hiddenFilter,
          decoration: const InputDecoration(
            labelText: 'Visibility',
            prefixIcon: Icon(Icons.visibility_outlined),
          ),
          items: const [
            DropdownMenuItem<bool?>(value: null, child: Text('All products')),
            DropdownMenuItem<bool?>(value: false, child: Text('Visible in search')),
            DropdownMenuItem<bool?>(value: true, child: Text('Hidden from search')),
          ],
          onChanged: (value) => setState(() => _hiddenFilter = value),
        ),
      ),
      ElevatedButton.icon(
        onPressed: _reloadDiscoveryProducts,
        icon: const Icon(Icons.filter_alt_outlined),
        label: const Text('Apply'),
      ),
    ];
  }

  Widget _buildFiltersTab() {
    final selectedGroup = _filterGroups
        .where((group) => group.id == _selectedGroupId)
        .cast<DiscoveryFilterGroupModel?>()
        .firstOrNull;

    return ListView(
      children: [
        _SectionCard(
          title: 'Filter Groups',
          subtitle:
              'Define the facets customers can browse by and map them to categories.',
          action: ElevatedButton.icon(
            onPressed: () => _editFilterGroup(),
            icon: const Icon(Icons.add),
            label: const Text('Add Filter Group'),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 68,
              dataRowMaxHeight: 82,
              columns: const [
                DataColumn(label: Text('Group')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Categories')),
                DataColumn(label: Text('Values')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _filterGroups
                  .map(
                    (group) => DataRow(
                      selected: _selectedGroupId == group.id,
                      onSelectChanged: (_) async {
                        setState(() => _selectedGroupId = group.id);
                        await _reloadFilterValues();
                      },
                      cells: [
                        DataCell(Text(group.name)),
                        DataCell(Text(group.filterType)),
                        DataCell(Text('${group.categoryIds.length} linked')),
                        DataCell(Text('${group.valueCount}')),
                        DataCell(
                          Icon(
                            group.isActive
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                            color: group.isActive
                                ? const Color(0xFF4C8A5A)
                                : AppColors.muted,
                          ),
                        ),
                        DataCell(
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _editFilterGroup(group),
                                child: const Text('Edit'),
                              ),
                              TextButton(
                                onPressed: () => _deleteFilterGroup(group),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: selectedGroup == null
              ? 'Filter Values'
              : 'Filter Values for ${selectedGroup.name}',
          subtitle:
              'Assign exact values to products so search and category listings can filter accurately.',
          action: ElevatedButton.icon(
            onPressed: _filterGroups.isEmpty ? null : () => _editFilterValue(),
            icon: const Icon(Icons.add),
            label: const Text('Add Filter Value'),
          ),
          child: _filterGroups.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Create a filter group first to manage values.'),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    dataRowMinHeight: 68,
                    dataRowMaxHeight: 82,
                    columns: const [
                      DataColumn(label: Text('Value')),
                      DataColumn(label: Text('Arabic')),
                      DataColumn(label: Text('Slug')),
                      DataColumn(label: Text('Products')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _filterValues
                        .map(
                          (value) => DataRow(
                            cells: [
                              DataCell(Text(value.value)),
                              DataCell(Text(value.valueAr ?? '-')),
                              DataCell(Text(value.slug)),
                              DataCell(Text('${value.productCount} linked')),
                              DataCell(
                                Icon(
                                  value.isActive
                                      ? Icons.check_circle_outline
                                      : Icons.pause_circle_outline,
                                  color: value.isActive
                                      ? const Color(0xFF4C8A5A)
                                      : AppColors.muted,
                                ),
                              ),
                              DataCell(
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: () => _editFilterValue(value),
                                      child: const Text('Edit'),
                                    ),
                                    TextButton(
                                      onPressed: () => _deleteFilterValue(value),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSessionTab(user) {
    return _SectionCard(
      title: 'Current Admin',
      subtitle:
          'Operational access is still handled here. Discovery configuration changes above save immediately to the platform database.',
      action: ElevatedButton.icon(
        onPressed: widget.sessionController.logout,
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user?.fullName ?? 'Admin',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(user?.email ?? ''),
          const SizedBox(height: 16),
          const Text(
            'Use the Search Config tab to control tags, explicit keywords, synonyms, hidden products, and merchandised search prompts.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Use the Filters tab to define filter groups, curate values, and map those values to real products and categories.',
          ),
        ],
      ),
    );
  }
}

class _DiscoveryProductDialog extends StatefulWidget {
  final AdminApiService apiService;
  final ProductModel product;

  const _DiscoveryProductDialog({
    required this.apiService,
    required this.product,
  });

  @override
  State<_DiscoveryProductDialog> createState() => _DiscoveryProductDialogState();
}

class _DiscoveryProductDialogState extends State<_DiscoveryProductDialog> {
  late final TextEditingController _tagsController;
  late final TextEditingController _keywordsController;
  late final TextEditingController _synonymsController;
  late bool _hidden;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tagsController = TextEditingController(text: widget.product.tags ?? '');
    _keywordsController =
        TextEditingController(text: widget.product.searchKeywords ?? '');
    _synonymsController =
        TextEditingController(text: widget.product.searchSynonyms ?? '');
    _hidden = widget.product.isHiddenFromSearch;
  }

  @override
  void dispose() {
    _tagsController.dispose();
    _keywordsController.dispose();
    _synonymsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.apiService.updateDiscoveryProduct(
        widget.product.id,
        {
          'tags': _tagsController.text.trim(),
          'search_keywords': _keywordsController.text.trim(),
          'search_synonyms': _synonymsController.text.trim(),
          'is_hidden_from_search': _hidden,
        },
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorDialogShell(
      title: 'Search Profile',
      onSave: _saving ? null : _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.product.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tagsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Product tags',
              hintText: 'coffee, saudi roast, arabic blend',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keywordsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Search keywords',
              hintText: 'gahwa, premium coffee, majlis',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _synonymsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Synonyms',
              hintText: 'qahwa, arabic coffee, coffee beans',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _hidden,
            onChanged: (value) => setState(() => _hidden = value),
            title: const Text('Hide from search'),
            subtitle: const Text(
              'The product remains in catalog listings but will be excluded from search discovery.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFF9A4D45)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchTermDialog extends StatefulWidget {
  final AdminApiService apiService;
  final SearchTermModel? term;
  final List<CategoryModel> categories;
  final List<ProductModel> products;

  const _SearchTermDialog({
    required this.apiService,
    required this.term,
    required this.categories,
    required this.products,
  });

  @override
  State<_SearchTermDialog> createState() => _SearchTermDialogState();
}

class _SearchTermDialogState extends State<_SearchTermDialog> {
  late final TextEditingController _termController;
  late final TextEditingController _synonymsController;
  late final TextEditingController _sortOrderController;
  String _termType = 'popular';
  int? _linkedCategoryId;
  int? _linkedProductId;
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _termController = TextEditingController(text: widget.term?.term ?? '');
    _synonymsController =
        TextEditingController(text: widget.term?.synonyms ?? '');
    _sortOrderController = TextEditingController(
      text: '${widget.term?.sortOrder ?? 0}',
    );
    _termType = widget.term?.termType ?? 'popular';
    _linkedCategoryId = widget.term?.linkedCategoryId;
    _linkedProductId = widget.term?.linkedProductId;
    _isActive = widget.term?.isActive ?? true;
  }

  @override
  void dispose() {
    _termController.dispose();
    _synonymsController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = {
        'term': _termController.text.trim(),
        'term_type': _termType,
        'synonyms': _synonymsController.text.trim(),
        'linked_category_id': _linkedCategoryId,
        'linked_product_id': _linkedProductId,
        'sort_order': int.tryParse(_sortOrderController.text.trim()) ?? 0,
        'is_active': _isActive,
      };
      if (widget.term == null) {
        await widget.apiService.createSearchTerm(payload);
      } else {
        await widget.apiService.updateSearchTerm(widget.term!.id, payload);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorDialogShell(
      title: widget.term == null ? 'Add Search Term' : 'Edit Search Term',
      onSave: _saving ? null : _save,
      child: Column(
        children: [
          TextField(
            controller: _termController,
            decoration: const InputDecoration(labelText: 'Term'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _termType,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'popular', child: Text('Popular')),
              DropdownMenuItem(value: 'featured', child: Text('Featured')),
            ],
            onChanged: (value) =>
                setState(() => _termType = value ?? 'popular'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _synonymsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Synonyms',
              hintText: 'gahwa,qahwa,coffee',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _linkedCategoryId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Linked category'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('None')),
              ...widget.categories.map(
                (category) => DropdownMenuItem<int?>(
                  value: category.id,
                  child: Text(category.name),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _linkedCategoryId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _linkedProductId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Linked product'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('None')),
              ...widget.products.map(
                (product) => DropdownMenuItem<int?>(
                  value: product.id,
                  child: Text(product.name),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _linkedProductId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sortOrderController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Sort order'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
            title: const Text('Active'),
          ),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFF9A4D45)),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterGroupDialog extends StatefulWidget {
  final AdminApiService apiService;
  final DiscoveryFilterGroupModel? group;
  final List<CategoryModel> categories;

  const _FilterGroupDialog({
    required this.apiService,
    required this.group,
    required this.categories,
  });

  @override
  State<_FilterGroupDialog> createState() => _FilterGroupDialogState();
}

class _FilterGroupDialogState extends State<_FilterGroupDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _sortOrderController;
  String _filterType = 'multi_select';
  bool _isActive = true;
  bool _isPublic = true;
  late final Set<int> _categoryIds;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group?.name ?? '');
    _slugController = TextEditingController(text: widget.group?.slug ?? '');
    _sortOrderController = TextEditingController(
      text: '${widget.group?.sortOrder ?? 0}',
    );
    _filterType = widget.group?.filterType ?? 'multi_select';
    _isActive = widget.group?.isActive ?? true;
    _isPublic = widget.group?.isPublic ?? true;
    _categoryIds = {...?widget.group?.categoryIds};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = {
        'name': _nameController.text.trim(),
        'slug': _slugController.text.trim(),
        'filter_type': _filterType,
        'sort_order': int.tryParse(_sortOrderController.text.trim()) ?? 0,
        'is_active': _isActive,
        'is_public': _isPublic,
        'category_ids': _categoryIds.toList(),
      };
      if (widget.group == null) {
        await widget.apiService.createFilterGroup(payload);
      } else {
        await widget.apiService.updateFilterGroup(widget.group!.id, payload);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorDialogShell(
      title: widget.group == null ? 'Add Filter Group' : 'Edit Filter Group',
      onSave: _saving ? null : _save,
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Group name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _slugController,
            decoration: const InputDecoration(labelText: 'Slug'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _filterType,
            decoration: const InputDecoration(labelText: 'Filter type'),
            items: const [
              DropdownMenuItem(
                value: 'multi_select',
                child: Text('Multi Select'),
              ),
              DropdownMenuItem(
                value: 'single_select',
                child: Text('Single Select'),
              ),
              DropdownMenuItem(value: 'swatch', child: Text('Swatch')),
              DropdownMenuItem(value: 'bucket', child: Text('Bucket')),
            ],
            onChanged: (value) =>
                setState(() => _filterType = value ?? 'multi_select'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sortOrderController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Sort order'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Linked Categories',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ListView(
              children: widget.categories
                  .map(
                    (category) => CheckboxListTile(
                      value: _categoryIds.contains(category.id),
                      title: Text(category.name),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _categoryIds.add(category.id);
                          } else {
                            _categoryIds.remove(category.id);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
            title: const Text('Active'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
            title: const Text('Visible in customer filters'),
          ),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFF9A4D45)),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterValueDialog extends StatefulWidget {
  final AdminApiService apiService;
  final DiscoveryFilterValueModel? value;
  final List<DiscoveryFilterGroupModel> groups;
  final List<ProductModel> products;
  final int? defaultGroupId;

  const _FilterValueDialog({
    required this.apiService,
    required this.value,
    required this.groups,
    required this.products,
    required this.defaultGroupId,
  });

  @override
  State<_FilterValueDialog> createState() => _FilterValueDialogState();
}

class _FilterValueDialogState extends State<_FilterValueDialog> {
  late final TextEditingController _valueController;
  late final TextEditingController _valueArController;
  late final TextEditingController _slugController;
  late final TextEditingController _sortOrderController;
  late int? _groupId;
  late bool _isActive;
  late final Set<int> _productIds;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(text: widget.value?.value ?? '');
    _valueArController =
        TextEditingController(text: widget.value?.valueAr ?? '');
    _slugController = TextEditingController(text: widget.value?.slug ?? '');
    _sortOrderController = TextEditingController(
      text: '${widget.value?.sortOrder ?? 0}',
    );
    _groupId = widget.value?.groupId ?? widget.defaultGroupId;
    _isActive = widget.value?.isActive ?? true;
    _productIds = {...?widget.value?.productIds};
  }

  @override
  void dispose() {
    _valueController.dispose();
    _valueArController.dispose();
    _slugController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = {
        'group_id': _groupId,
        'value': _valueController.text.trim(),
        'value_ar': _valueArController.text.trim(),
        'slug': _slugController.text.trim(),
        'sort_order': int.tryParse(_sortOrderController.text.trim()) ?? 0,
        'is_active': _isActive,
        'product_ids': _productIds.toList(),
      };
      if (widget.value == null) {
        await widget.apiService.createFilterValue(payload);
      } else {
        await widget.apiService.updateFilterValue(widget.value!.id, payload);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorDialogShell(
      title: widget.value == null ? 'Add Filter Value' : 'Edit Filter Value',
      onSave: _saving ? null : _save,
      child: Column(
        children: [
          DropdownButtonFormField<int?>(
            initialValue: _groupId,
            decoration: const InputDecoration(labelText: 'Filter group'),
            items: widget.groups
                .map(
                  (group) => DropdownMenuItem<int?>(
                    value: group.id,
                    child: Text(group.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _groupId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valueController,
            decoration: const InputDecoration(labelText: 'Value'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valueArController,
            decoration: const InputDecoration(labelText: 'Arabic value'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _slugController,
            decoration: const InputDecoration(labelText: 'Slug'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sortOrderController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Sort order'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Mapped Products',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: ListView(
              children: widget.products
                  .map(
                    (product) => CheckboxListTile(
                      value: _productIds.contains(product.id),
                      title: Text(product.name),
                      subtitle: Text(product.sku ?? '-'),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _productIds.add(product.id);
                          } else {
                            _productIds.remove(product.id);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
            title: const Text('Active'),
          ),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFF9A4D45)),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditorDialogShell extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onSave;

  const _EditorDialogShell({
    required this.title,
    required this.child,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                child,
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: onSave,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 12),
                action!,
              ],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String helper;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.softPanelGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _TrimmedCell extends StatelessWidget {
  final String? value;

  const _TrimmedCell(this.value);

  @override
  Widget build(BuildContext context) {
    final text = (value ?? '').trim();
    return SizedBox(
      width: 220,
      child: Text(
        text.isEmpty ? '-' : text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

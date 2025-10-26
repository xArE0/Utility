import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'datavault_db.dart';

class DataVaultPage extends StatefulWidget {
  const DataVaultPage({super.key});

  @override
  State<DataVaultPage> createState() => _DataVaultPageState();
}

class _DataVaultPageState extends State<DataVaultPage> {
  final db = DataVaultDB();
  List<Map<String, dynamic>> items = [];
  Set<int> visibleIds = {};

  final List<String> categories = ['Passwords','IDs','Cards','Bank Accounts'];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final data = await db.getAllItems();
    setState(() => items = data);
  }

  void _addItem() async {
    final labelController = TextEditingController();
    final valueController = TextEditingController();
    String selectedCategory = categories[0];

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Add Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                if (val != null) selectedCategory = val;
              },
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(labelText: 'Value'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (labelController.text.isNotEmpty &&
                  valueController.text.isNotEmpty) {
                await db.addItem(
                  labelController.text,
                  valueController.text,
                  selectedCategory,
                );
                Navigator.pop(dialogContext);
                _loadItems();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await db.deleteItem(id);
              Navigator.pop(dialogContext);
              _loadItems();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String category) {
    final categoryItems = items.where((i) => i['category'] == category).toList();
    if (categoryItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Text(category, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ...categoryItems.map((item) {
          final id = item['id'] as int;
          final isVisible = visibleIds.contains(id);
          return ListTile(
            title: Text(item['label']),
            subtitle: Text(
              isVisible ? item['value'] : '••••••••',
              style: const TextStyle(letterSpacing: 2),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      if (isVisible) {
                        visibleIds.remove(id);
                      } else {
                        visibleIds.add(id);
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyToClipboard(item['value']),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(id),
                ),
              ],
            ),
          );
        }),
        const Divider(thickness: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Vault')),
      body: ListView(
        children: categories.map(_buildCategorySection).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}

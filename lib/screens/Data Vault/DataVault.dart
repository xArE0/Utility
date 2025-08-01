import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'datavault_db.dart';

class DataVaultPage extends StatefulWidget {
  const DataVaultPage({super.key});

  @override
  State<DataVaultPage> createState() => _DataVaultPageState();
}

class _DataVaultPageState extends State<DataVaultPage> {
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final data = await DataVaultDB().getAllItems();
    setState(() => items = data);
  }

  void _addItem() async {
    final labelController = TextEditingController();
    final valueController = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: labelController, decoration: const InputDecoration(labelText: 'Label')),
            TextField(controller: valueController, decoration: const InputDecoration(labelText: 'Value')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (labelController.text.isNotEmpty && valueController.text.isNotEmpty) {
                await DataVaultDB().addItem(labelController.text, valueController.text);
                Navigator.pop(context);
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Vault')),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, i) {
          final item = items[i];
          return ListTile(
            title: Text(item['label']),
            subtitle: Text('••••••••', style: const TextStyle(letterSpacing: 2)),
            trailing: const Icon(Icons.copy),
            onTap: () => _copyToClipboard(item['value']),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}
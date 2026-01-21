import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'datavault_db.dart';
import '../../core/theme/app_colors.dart';

class DataVaultPage extends StatefulWidget {
  const DataVaultPage({super.key});

  @override
  State<DataVaultPage> createState() => _DataVaultPageState();
}

class _DataVaultPageState extends State<DataVaultPage> {
  final db = DataVaultDB();
  List<Map<String, dynamic>> items = [];
  Set<int> visibleIds = {}; // Track visibility of password text
  
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> categories = ['Passwords', 'IDs', 'Cards', 'Bank Accounts'];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final data = await db.getAllItems();
    setState(() => items = data);
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
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

  void _showItemDialog({Map<String, dynamic>? item}) async {
    final isEditing = item != null;
    final labelController = TextEditingController(text: isEditing ? item['label'] : '');
    final valueController = TextEditingController(text: isEditing ? item['value'] : '');
    String selectedCategory = isEditing ? item['category'] : categories[0];

    if (!categories.contains(selectedCategory)) {
      selectedCategory = categories[0];
    }

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(isEditing ? 'Edit Info' : 'Add Info'),
        content: SingleChildScrollView(
          child: Column(
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
                textCapitalization: TextCapitalization.sentences,
              ),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(labelText: 'Value'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (labelController.text.isNotEmpty &&
                  valueController.text.isNotEmpty) {
                if (isEditing) {
                  await db.updateItem(
                    item['id'],
                    labelController.text,
                    valueController.text,
                    selectedCategory,
                  );
                } else {
                  await db.addItem(
                    labelController.text,
                    valueController.text,
                    selectedCategory,
                  );
                }
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

  Widget _buildVaultCard(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final Color surface = isDark ? AppColors.slate800.withOpacity(0.6) : Colors.white;
    final Color border = isDark ? AppColors.slate700.withOpacity(0.8) : Colors.grey[300]!;
    final Color primaryText = isDark ? AppColors.slate50 : AppColors.slate900;
    final Color secondaryText = isDark ? AppColors.slate300 : Colors.grey[600]!;

    final id = item['id'] as int;
    final isVisible = visibleIds.contains(id);

    return Card(
      elevation: isDark ? 0 : 4,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border.withOpacity(isDark ? 0.6 : 1.0)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Content: Icon + Label + Value
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.lock, color: Theme.of(context).primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item['label'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                          // No maxLines, allow wrap
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: border.withOpacity(0.7)),
                  const SizedBox(height: 8),
                  Text(
                    'Value:',
                    style: TextStyle(
                      fontSize: 12, 
                      color: secondaryText,
                      fontWeight: FontWeight.w500
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isVisible ? item['value'] : '••••••••',
                    style: TextStyle(
                      fontSize: 16,
                      letterSpacing: 2.0, // Requested spacing
                      fontWeight: FontWeight.bold,
                      fontFamily: isVisible ? null : 'monospace',
                      color: primaryText,
                    ),
                    // No maxLines, allow wrap
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Right Content: 2x2 Button Matrix
            Container(
              decoration: BoxDecoration(
                 color: isDark ? AppColors.slate900.withOpacity(0.55) : Colors.grey[100],
                 borderRadius: BorderRadius.circular(12),
                 border: Border.all(color: border)
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MatrixButton(
                        icon: isVisible ? Icons.visibility_off : Icons.visibility,
                        color: cs.primary,
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
                      Container(width: 1, height: 40, color: border),
                      _MatrixButton(
                        icon: Icons.copy,
                        color: cs.primary,
                        onPressed: () => _copyToClipboard(item['value']),
                      ),
                    ],
                  ),
                  Container(height: 1, width: 80, color: border),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MatrixButton(
                        icon: Icons.edit,
                        color: AppColors.govGold,
                        onPressed: () => _showItemDialog(item: item),
                      ),
                      Container(width: 1, height: 40, color: border),
                      _MatrixButton(
                        icon: Icons.delete,
                        color: Colors.red,
                        onPressed: () => _confirmDelete(id),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color pageBg = isDark ? theme.scaffoldBackgroundColor : Colors.white;
    final Color inputFill = isDark ? AppColors.slate900.withOpacity(0.55) : Colors.grey[100]!;
    final Color border = isDark ? AppColors.slate700.withOpacity(0.8) : Colors.grey[300]!;
    final Color primaryText = isDark ? AppColors.slate50 : AppColors.slate900;
    final Color secondaryText = isDark ? AppColors.slate300 : Colors.grey[600]!;

    final filteredItems = items.where((item) {
      final label = item['label'].toString().toLowerCase();
      final category = item['category'].toString().toLowerCase();
      final query = searchQuery.toLowerCase();
      return label.contains(query) || category.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Data Vault'),
        centerTitle: true,
        backgroundColor: isDark ? Colors.transparent : theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Styled Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search your vault...',
                hintStyle: TextStyle(color: secondaryText),
                prefixIcon: Icon(Icons.search, color: secondaryText),
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                         _searchController.clear();
                         setState(() {
                           searchQuery = '';
                         });
                      },
                    )
                  : null,
              ),
              style: TextStyle(color: primaryText),
              onChanged: (val) {
                setState(() {
                  searchQuery = val;
                });
              },
            ),
          ),
          
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_open, size: 60, color: isDark ? AppColors.slate500 : Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          items.isEmpty 
                            ? 'Your vault is empty.\nProtect your data now!' 
                            : 'No matches found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: secondaryText, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: categories.map((category) {
                      final categoryItems = filteredItems
                          .where((i) => i['category'] == category)
                          .toList();
                      
                      if (categoryItems.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 4, height: 18, 
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor,
                                    borderRadius: BorderRadius.circular(2)
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.bold, 
                                    color: primaryText,
                                    letterSpacing: 0.5
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...categoryItems.map((item) => _buildVaultCard(item)),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _MatrixButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _MatrixButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        splashRadius: 20,
      ),
    );
  }
}

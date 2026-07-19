class VaultItem {
  final int? id;
  final String label;
  final String value;
  final String category;
  final String tags; // comma-separated, e.g. "share,money,family"
  final String username;
  final String website;
  final String note;
  final List<VaultCustomField> customFields;

  VaultItem({
    this.id,
    required this.label,
    required this.value,
    required this.category,
    this.tags = '',
    this.username = '',
    this.website = '',
    this.note = '',
    this.customFields = const [],
  });

  /// Parsed tag list for display/search
  List<String> get tagList =>
      tags.isEmpty ? [] : tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'value': value,
      'category': category,
      'tags': tags,
      'username': username,
      'website': website,
      'note': note,
    };
  }

  factory VaultItem.fromMap(Map<String, dynamic> map) {
    return VaultItem(
      id: map['id'],
      label: map['label'] ?? '',
      value: map['value'] ?? '',
      category: map['category'] ?? 'Passwords',
      tags: map['tags'] ?? '',
      username: map['username'] ?? '',
      website: map['website'] ?? '',
      note: map['note'] ?? '',
    );
  }

  VaultItem copyWith({
    int? id,
    String? label,
    String? value,
    String? category,
    String? tags,
    String? username,
    String? website,
    String? note,
    List<VaultCustomField>? customFields,
  }) {
    return VaultItem(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      username: username ?? this.username,
      website: website ?? this.website,
      note: note ?? this.note,
      customFields: customFields ?? this.customFields,
    );
  }
}

/// A user-defined name/value pair attached to a [VaultItem], e.g. "ID Number".
class VaultCustomField {
  final int? id;
  final int? vaultItemId;
  final String name;
  final String value;

  VaultCustomField({
    this.id,
    this.vaultItemId,
    required this.name,
    required this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vault_item_id': vaultItemId,
      'field_name': name,
      'field_value': value,
    };
  }

  factory VaultCustomField.fromMap(Map<String, dynamic> map) {
    return VaultCustomField(
      id: map['id'],
      vaultItemId: map['vault_item_id'],
      name: map['field_name'] ?? '',
      value: map['field_value'] ?? '',
    );
  }
}

class VaultHistory {
  final int? id;
  final int vaultItemId;
  final String oldValue;
  final DateTime changedAt;

  VaultHistory({
    this.id,
    required this.vaultItemId,
    required this.oldValue,
    required this.changedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vault_item_id': vaultItemId,
      'old_value': oldValue,
      'changed_at': changedAt.toIso8601String(),
    };
  }

  factory VaultHistory.fromMap(Map<String, dynamic> map) {
    return VaultHistory(
      id: map['id'],
      vaultItemId: map['vault_item_id'],
      oldValue: map['old_value'] ?? '',
      changedAt: DateTime.tryParse(map['changed_at'] ?? '') ?? DateTime.now(),
    );
  }
}

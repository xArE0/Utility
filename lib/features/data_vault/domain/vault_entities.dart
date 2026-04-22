class VaultItem {
  final int? id;
  final String label;
  final String value;
  final String category;

  VaultItem({
    this.id,
    required this.label,
    required this.value,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'value': value,
      'category': category,
    };
  }

  factory VaultItem.fromMap(Map<String, dynamic> map) {
    return VaultItem(
      id: map['id'],
      label: map['label'] ?? '',
      value: map['value'] ?? '',
      category: map['category'] ?? 'Passwords',
    );
  }

  VaultItem copyWith({
    int? id,
    String? label,
    String? value,
    String? category,
  }) {
    return VaultItem(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      category: category ?? this.category,
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

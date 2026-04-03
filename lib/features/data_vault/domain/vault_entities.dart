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

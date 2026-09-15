class ShoppingItemModel {
  final int? id;
  final String name;
  final int isPurchased;
  final int? gastoId;
  final String createdAt;

  ShoppingItemModel({
    this.id,
    required this.name,
    this.isPurchased = 0,
    this.gastoId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_purchased': isPurchased,
      'gasto_id': gastoId,
      'created_at': createdAt,
    };
  }

  factory ShoppingItemModel.fromMap(Map<String, dynamic> map) {
    return ShoppingItemModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      isPurchased: map['is_purchased'] as int,
      gastoId: map['gasto_id'] as int?,
      createdAt: map['created_at'] as String,
    );
  }

  ShoppingItemModel copyWith({
    int? id,
    String? name,
    int? isPurchased,
    int? gastoId,
    String? createdAt,
  }) {
    return ShoppingItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isPurchased: isPurchased ?? this.isPurchased,
      gastoId: gastoId ?? this.gastoId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


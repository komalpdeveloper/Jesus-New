class InventoryItem {
  final String id;
  final String name;
  final int quantity;
  final String description;
  final int value;
  final String? imageUrl; // Product image URL
  final String? productPngUrl; // Product PNG URL for altar

  InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.description,
    required this.value,
    this.imageUrl,
    this.productPngUrl,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      description: json['description'] ?? '',
      value: json['value'] ?? 0,
      imageUrl: json['imageUrl'],
      productPngUrl: json['productPngUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'description': description,
      'value': value,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (productPngUrl != null) 'productPngUrl': productPngUrl,
    };
  }
}

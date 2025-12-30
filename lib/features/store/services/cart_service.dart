import 'dart:convert';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItemModel {
  final String productId; // Firestore product document ID
  final String title;
  final String image; // asset or network
  final double price; // rings per item
  final int qty;

  const CartItemModel({
    required this.productId,
    required this.title,
    required this.image,
    required this.price,
    this.qty = 1,
  });

  CartItemModel copyWith({String? productId, String? title, String? image, double? price, int? qty}) => CartItemModel(
        productId: productId ?? this.productId,
        title: title ?? this.title,
        image: image ?? this.image,
        price: price ?? this.price,
        qty: qty ?? this.qty,
      );

  Map<String, dynamic> toJson() => {
        'pid': productId,
        't': title,
        'i': image,
        'p': price,
        'q': qty,
      };
  static CartItemModel fromJson(Map<String, dynamic> j) => CartItemModel(
        productId: j['pid'] ?? '',
        title: j['t'] ?? '',
        image: j['i'] ?? '',
        price: (j['p'] is int) ? (j['p'] as int).toDouble() : (j['p'] ?? 0.0),
        qty: (j['q'] ?? 1) as int,
      );

  // Unique key based on productId
  String get key => productId;
}

class CartController extends ChangeNotifier {
  static final CartController instance = CartController._internal();
  CartController._internal();

  static const _storageKey = 'cart_v1';
  bool _loaded = false;
  Future<void>? _loadingFuture;
  final List<CartItemModel> _items = [];

  UnmodifiableListView<CartItemModel> get items => UnmodifiableListView(_items);
  int get itemCount => _items.fold(0, (s, i) => s + i.qty);
  int get totalRings => _items.fold(0, (s, i) => s + (i.price * i.qty).round());

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    if (_loadingFuture != null) {
      await _loadingFuture;
      return;
    }
    _loadingFuture = _loadInternal();
    await _loadingFuture;
  }

  Future<void> _loadInternal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<dynamic>();
        _items
          ..clear()
          ..addAll(list.map((e) => CartItemModel.fromJson((e as Map).cast<String, dynamic>())));
      } catch (_) {
        // ignore malformed
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  Future<void> addItem(CartItemModel item, {int? qty}) async {
    await ensureLoaded();
    final idx = _items.indexWhere((e) => e.key == item.key);
    // Determine the quantity to add: explicit param or the item's own qty, clamped 1-999999
    final addQty = (qty ?? item.qty).clamp(1, 999999);
    if (idx >= 0) {
      final cur = _items[idx];
      final newQty = (cur.qty + addQty).clamp(1, 999999);
      _items[idx] = cur.copyWith(qty: newQty);
    } else {
      _items.add(item.copyWith(qty: addQty));
    }
    await _save();
    notifyListeners();
  }

  Future<void> setQtyAt(int index, int qty) async {
    if (index < 0 || index >= _items.length) return;
    final q = qty.clamp(0, 999999);
    if (q <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(qty: q);
    }
    await _save();
    notifyListeners();
  }

  Future<void> incrementAt(int index) async {
    if (index < 0 || index >= _items.length) return;
    _items[index] = _items[index].copyWith(qty: _items[index].qty + 1);
    await _save();
    notifyListeners();
  }

  Future<void> decrementAt(int index) async {
    if (index < 0 || index >= _items.length) return;
    final q = _items[index].qty - 1;
    if (q <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(qty: q);
    }
    await _save();
    notifyListeners();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    await _save();
    notifyListeners();
  }
}

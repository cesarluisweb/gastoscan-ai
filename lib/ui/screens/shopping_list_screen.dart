import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/models/shopping_item_model.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({Key? key}) : super(key: key);

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  List<ShoppingItemModel> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = await DatabaseHelper.instance.getAllShoppingItems();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _add() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    final newItem = ShoppingItemModel(
      name: text,
      createdAt: DateTime.now().toIso8601String(),
    );
    await DatabaseHelper.instance.insertShoppingItem(newItem);
    _ctrl.clear();
    _loadItems();
    _focusNode.requestFocus();
  }

  Future<void> _toggle(ShoppingItemModel item) async {
    await DatabaseHelper.instance.updateShoppingItemStatus(item.id!, item.isPurchased == 0);
    _loadItems();
  }

  Future<void> _delete(ShoppingItemModel item) async {
    await DatabaseHelper.instance.deleteShoppingItem(item.id!);
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Compras'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focusNode,
                    onEditingComplete: _add,
                    decoration: const InputDecoration(
                      hintText: 'Ej. Harina Pan',
                      prefixIcon: Icon(Icons.shopping_cart_checkout),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, size: 40, color: AppColors.primary),
                  onPressed: _add,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('Tu lista está vacía.', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final isPurchased = item.isPurchased == 1;
                          return ListTile(
                            leading: Checkbox(
                              value: isPurchased,
                              onChanged: (_) => _toggle(item),
                              activeColor: AppColors.primary,
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                color: isPurchased ? AppColors.textSecondary : AppColors.textPrimary,
                                decoration: isPurchased ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error),
                              onPressed: () => _delete(item),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}


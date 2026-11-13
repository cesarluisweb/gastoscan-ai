import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/models/shopping_item_model.dart';

class ShoppingListScreen extends StatefulWidget {
  final bool showBackButton;
  final VoidCallback? onBack;
  final DatabaseHelper? dbHelper;

  const ShoppingListScreen({
    Key? key,
    this.showBackButton = false,
    this.onBack,
    this.dbHelper,
  }) : super(key: key);

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  List<ShoppingItemModel> _items = [];
  bool _isLoading = true;

  DatabaseHelper get _db => widget.dbHelper ?? DatabaseHelper.instance;

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
    try {
      final items = await _db.getAllShoppingItems();
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    await _db.insertShoppingItem(newItem);
    _ctrl.clear();
    _loadItems();
    _focusNode.requestFocus();
  }

  Future<void> _toggle(ShoppingItemModel item) async {
    await _db.updateShoppingItemStatus(item.id!, item.isPurchased == 0);
    _loadItems();
  }

  Future<void> _delete(ShoppingItemModel item) async {
    if (item.id == null) return;
    await _db.deleteShoppingItem(item.id!);
    if (mounted) {
      _loadItems();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(
                child: Text(
                  '"${item.name}" eliminado',
                  style: const TextStyle(color: Colors.black),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                key: const Key('shopping_undo_delete_button'),
                borderRadius: BorderRadius.circular(6),
                onTap: () async {
                  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
                  await _db.insertShoppingItem(
                    ShoppingItemModel(
                      name: item.name,
                      isPurchased: item.isPurchased,
                      createdAt: DateTime.now().toIso8601String(),
                    ),
                  );
                  if (mounted) _loadItems();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.undo_rounded,
                        size: 15,
                        color: Colors.black87,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Deshacer',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Compras'),
        automaticallyImplyLeading: widget.showBackButton && widget.onBack == null,
        leading: (widget.showBackButton && widget.onBack != null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
                  widget.onBack!();
                },
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    onEditingComplete: _add,
                    decoration: const InputDecoration(
                      hintText: 'Ej. Harina Pan',
                      prefixIcon: Icon(Icons.shopping_cart_checkout),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, size: 40, color: AppColors.primaryDark),
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
                              activeColor: AppColors.primaryDark,
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
    ),
  ),
    );
  }
}


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/gasto_provider.dart';
import '../../core/constants/app_colors.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'scan_screen.dart';
import 'chat_screen.dart';
import 'shopping_list_screen.dart';
import 'review_expense_screen.dart'; // Para agregar manual

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GastoProvider>(context, listen: false).syncToFirestore();
    });
  }

  // Ahora solo 4 pantallas en el tab (Escanear ya no es un tab)
  final List<Widget> _pages = [
    const DashboardScreen(),
    const ShoppingListScreen(),
    const ChatScreen(),
    const SettingsScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '¿Qué deseas agregar?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(Icons.document_scanner, color: AppColors.textPrimary),
                ),
                title: const Text('Escanear Factura (IA)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Toma una foto y extrae los datos mágicamente'),
                onTap: () {
                  Navigator.pop(ctx);
                  // Navegar al tab de Scan o abrir ScanScreen directamente encima
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScanScreen()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.cardLighter,
                  child: const Icon(Icons.edit_note, color: AppColors.textPrimary),
                ),
                title: const Text('Ingreso Manual', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Registra un gasto sin factura'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReviewExpenseScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu(context),
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.qr_code_scanner, color: AppColors.textPrimary, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Inicio', index: 0),
            _buildTabItem(icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart, label: 'Lista', index: 1),
            const SizedBox(width: 48), // Espacio para el FAB
            _buildTabItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome, label: 'Asistente', index: 2),
            _buildTabItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Perfil', index: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

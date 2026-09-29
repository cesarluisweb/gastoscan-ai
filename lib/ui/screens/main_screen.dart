import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/scan_queue_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/gemini_extraction_result.dart';
import 'dashboard_screen.dart';
import 'expense_history_screen.dart';
import 'analysis_screen.dart';
import 'more_screen.dart';
import 'scan_screen.dart';
import 'review_expense_screen.dart'; // Para agregar manual
import 'chat_screen.dart';
import '../../data/models/item_gasto_model.dart';
import '../../providers/settings_provider.dart';
import '../widgets/voice_expense_sheet.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _CustomCenterDockedFabLocation extends FloatingActionButtonLocation {
  const _CustomCenterDockedFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = (scaffoldGeometry.scaffoldSize.width - scaffoldGeometry.floatingActionButtonSize.width) / 2.0;
    
    // El centerDocked normal centra el botón exactamente en el borde (50% arriba, 50% abajo).
    // Si bajamos el botón un 25% de su propio tamaño, quedará un 25% por encima del borde y 75% por debajo.
    final double defaultY = scaffoldGeometry.contentBottom - (scaffoldGeometry.floatingActionButtonSize.height / 2.0);
    final double fabY = defaultY + (scaffoldGeometry.floatingActionButtonSize.height * 0.25);
    
    return Offset(fabX, fabY);
  }
}

class _FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const _FadeIndexedStack({
    Key? key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 150),
  }) : super(key: key);

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void didUpdateWidget(_FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _currentIndex) {
      _currentIndex = widget.index;
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: IndexedStack(
        index: _currentIndex,
        children: widget.children,
      ),
    );
  }
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<MoreScreenState> _moreScreenKey = GlobalKey<MoreScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GastoProvider>(context, listen: false).sincronizarConFirestore();
    });
  }

  // 4 pantallas principales
  late final List<Widget> _pages = [
    DashboardScreen(
      onNavigateToGastos: () => _onTabTapped(1),
      onNavigateToAnalysis: () => _onTabTapped(2),
      onNavigateToChat: () {
        _onTabTapped(3);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _moreScreenKey.currentState?.openChat(fromHome: true);
        });
      },
      onAddExpense: () => _showAddMenu(context),
    ),
    const ExpenseHistoryScreen(),
    const AnalysisScreen(),
    MoreScreen(
      key: _moreScreenKey,
      onNavigateToHome: () => _onTabTapped(0),
    ),
  ];

  void _onTabTapped(int index) {
    if (index != 3 && _currentIndex == 3) {
      _moreScreenKey.currentState?.returnToHub();
    }
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
                  'Selecciona una opción',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.edit_note, color: AppColors.textPrimary),
                ),
                title: const Text('Registrar gasto', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Escribe los datos de tu compra'),
                onTap: () {
                  final settings = Provider.of<SettingsProvider>(context, listen: false);
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReviewExpenseScreen(
                        extractedData: GeminiExtractionResult(
                          comercio: '',
                          fecha: DateTime.now().toIso8601String().substring(0, 10),
                          moneda: settings.monedaPrincipal,
                          totalOriginal: 0.0,
                          tasaCambioDetectada: null,
                          impuestoIva: 0.0,
                          items: [
                            ItemGastoModel(
                              descripcion: '',
                              cantidad: 1.0,
                              precioUnitario: 0,
                              total: 0,
                              categoria: 'Otros',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(Icons.camera_alt, color: AppColors.textPrimary),
                ),
                title: const Text('Escanear factura (IA)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('La IA extrae los datos de la foto'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
                    if (picked != null && context.mounted) {
                      final scanQueue = Provider.of<ScanQueueProvider>(context, listen: false);
                      await scanQueue.enqueue(picked.path);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Factura añadida a la cola en segundo plano.', style: TextStyle(color: Colors.black)),
                            backgroundColor: AppColors.primary,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al capturar imagen: $e')),
                      );
                    }
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(Icons.image, color: AppColors.textPrimary),
                ),
                title: const Text('Subir comprobante (IA)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Sube una foto o captura de tu recibo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picker = ImagePicker();
                    final pickedFiles = await picker.pickMultiImage(imageQuality: 90);
                    if (pickedFiles.isNotEmpty && context.mounted) {
                      final scanQueue = Provider.of<ScanQueueProvider>(context, listen: false);
                      final paths = pickedFiles.map((f) => f.path).toList();
                      await scanQueue.enqueueMultiple(paths);
                      if (context.mounted) {
                        final countText = paths.length == 1 ? '1 comprobante añadido' : '${paths.length} comprobantes añadidos';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$countText a la cola en segundo plano.', style: const TextStyle(color: Colors.black)),
                            backgroundColor: AppColors.primary,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al seleccionar imágenes: $e')),
                      );
                    }
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(Icons.mic, color: AppColors.textPrimary),
                ),
                title: const Text('Dictar gasto (Voz)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Habla y la IA organizará tu compra'),
                onTap: () {
                  Navigator.pop(ctx);
                  VoiceExpenseSheet.show(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlobalScanBanner(BuildContext context, ScanQueueProvider scanQueue) {
    if (scanQueue.readyItems.isNotEmpty) {
      final count = scanQueue.readyItems.length;
      final isProcessingMore = scanQueue.isProcessing || scanQueue.pendingCount > 0;
      final String label;
      if (isProcessingMore) {
        label = count == 1
            ? '1 factura lista para revisar (${scanQueue.pendingCount} en cola)'
            : '$count facturas listas para revisar (${scanQueue.pendingCount} en cola)';
      } else {
        label = count == 1
            ? '1 factura lista para revisar. Toca aquí.'
            : '$count facturas listas para revisar. Toca aquí.';
      }

      return Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: AppColors.primary,
          child: InkWell(
            onTap: () {
              if (scanQueue.readyItems.isNotEmpty) {
                final item = scanQueue.readyItems.first;
                final data = jsonDecode(item['extracted_data']);
                final result = GeminiExtractionResult.fromJson(data);
                final file = File(item['image_path']);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReviewExpenseScreen(
                      imageFile: file.existsSync() ? file : null,
                      extractedData: result,
                      queueItemId: item['id'],
                    ),
                  ),
                ).then((_) {
                  scanQueue.loadReadyItems();
                });
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppColors.textPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textPrimary),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (scanQueue.isProcessing || scanQueue.pendingItems.isNotEmpty) {
      final count = scanQueue.pendingCount > 0 ? scanQueue.pendingCount : 1;
      final label = count == 1
          ? 'Procesando factura en segundo plano...'
          : 'Procesando $count facturas en segundo plano...';

      return Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(12),
          color: AppColors.card,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final scanQueue = Provider.of<ScanQueueProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          _FadeIndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          _buildGlobalScanBanner(context, scanQueue),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu(context),
        backgroundColor: AppColors.primary,
        elevation: 3,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: AppColors.textPrimary, size: 32),
      ),
      floatingActionButtonLocation: const _CustomCenterDockedFabLocation(),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        padding: EdgeInsets.zero,
        height: 65, // Reducir altura
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTabItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Inicio',
              index: 0,
              badgeCount: scanQueue.readyItems.length,
            ),
            _buildTabItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long,
              label: 'Gastos',
              index: 1,
            ),
            const SizedBox(width: 48), // Espacio para el FAB
            _buildTabItem(
              icon: Icons.analytics_outlined,
              activeIcon: Icons.analytics,
              label: 'Análisis',
              index: 2,
            ),
            _buildTabItem(
              icon: Icons.more_horiz,
              activeIcon: Icons.more_horiz,
              label: 'Más',
              index: 3,
            ),
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
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;

    Widget iconWidget = Icon(
      isSelected ? activeIcon : icon,
      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
      size: 24,
    );

    if (badgeCount > 0) {
      iconWidget = Badge.count(
        count: badgeCount,
        backgroundColor: AppColors.primaryDark,
        textColor: Colors.white,
        child: iconWidget,
      );
    }

    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 60, // Fixed width to ensure indicator is centered and tabs look even
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isSelected ? 24 : 0,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            iconWidget,
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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

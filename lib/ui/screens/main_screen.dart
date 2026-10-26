import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/scan_queue_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/gemini_extraction_result.dart';
import '../../services/notification_service.dart';
import 'dashboard_screen.dart';
import 'expense_history_screen.dart';
import 'analysis_screen.dart';
import 'more_screen.dart';
import 'chat_screen.dart';
import 'review_expense_screen.dart'; // Para agregar manual
import '../../data/models/item_gasto_model.dart';
import '../../providers/settings_provider.dart';
import '../widgets/voice_expense_sheet.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  static void showAddMenu(BuildContext context) => _MainScreenState.mostrarMenuAgregar(context);

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

  const _FadeIndexedStack({
    Key? key,
    required this.index,
    required this.children,
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _showingChat = false;
  int _chatOriginIndex = 0;
  final GlobalKey<MoreScreenState> _moreScreenKey = GlobalKey<MoreScreenState>();
  final GlobalKey<ExpenseHistoryScreenState> _expenseHistoryKey = GlobalKey<ExpenseHistoryScreenState>();
  DateTime? _lastBackPressTime;

  void _openChat({int fromIndex = 0}) {
    setState(() {
      _chatOriginIndex = fromIndex;
      _showingChat = true;
    });
  }

  void _closeChat() {
    setState(() {
      _showingChat = false;
      _currentIndex = _chatOriginIndex;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.selectedPayloadNotifier.addListener(_handleNotificationPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
      gastoProvider.sincronizarConFirestore();

      // Auto-reparación transparente de tasas incompletas en gastos históricos (ejecutada una sola vez)
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool('pref_fixed_tasas_v1') ?? false)) {
          final settings = Provider.of<SettingsProvider>(context, listen: false);
          await gastoProvider.repararTasasHistoricas(
            tasaFallback: settings.tasaCambioVesUsd > 0
                ? settings.tasaCambioVesUsd
                : 474.0,
          );
          await prefs.setBool('pref_fixed_tasas_v1', true);
        }
      } catch (e) {
        debugPrint('Error en reparación de tasas: $e');
      }

      final initial = NotificationService.instance.initialPayload;
      if (initial != null) {
        _handleNotificationPayload();
      }
    });
  }

  void _handleNotificationPayload() {
    final payload = NotificationService.instance.selectedPayloadNotifier.value ??
        NotificationService.instance.initialPayload;
    if (payload == null || !mounted) return;

    NotificationService.instance.clearPayload();

    if (payload == 'pending_reviews') {
      final scanQueue = Provider.of<ScanQueueProvider>(context, listen: false);
      if (scanQueue.readyItems.isNotEmpty) {
        final item = scanQueue.readyItems.first;
        try {
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
        } catch (e) {
          debugPrint('Error al abrir factura desde notificación: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    NotificationService.instance.selectedPayloadNotifier.removeListener(_handleNotificationPayload);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Provider.of<ScanQueueProvider>(context, listen: false).resumeQueueWhenOnline();
    }
  }

  void _openSearchFromAnywhere() {
    if (_showingChat) {
      _showingChat = false;
    }
    _onTabTapped(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _expenseHistoryKey.currentState?.activateSearch();
    });
  }

  // 4 pantallas principales
  late final List<Widget> _pages = [
    DashboardScreen(
      onNavigateToGastos: () => _onTabTapped(1),
      onNavigateToAnalysis: () => _onTabTapped(2),
      onNavigateToChat: () => _openChat(fromIndex: 0),
      onNavigateToSearch: _openSearchFromAnywhere,
      onAddExpense: () => _showAddMenu(context),
    ),
    ExpenseHistoryScreen(
      key: _expenseHistoryKey,
      onNavigateToChat: () => _openChat(fromIndex: 1),
    ),
    AnalysisScreen(
      onNavigateToSearch: _openSearchFromAnywhere,
      onNavigateToChat: () => _openChat(fromIndex: 2),
    ),
    MoreScreen(
      key: _moreScreenKey,
      onNavigateToHome: () => _onTabTapped(0),
      onNavigateToChat: () => _openChat(fromIndex: 3),
      onNavigateToSearch: _openSearchFromAnywhere,
    ),
  ];

  void _onTabTapped(int index) {
    if (_showingChat) {
      _showingChat = false;
    }
    if (index != 3 && _currentIndex == 3) {
      _moreScreenKey.currentState?.returnToHub();
    }
    setState(() {
      _currentIndex = index;
    });
  }

  void _showAddMenu(BuildContext context) => MainScreen.showAddMenu(context);

  static void mostrarMenuAgregar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Material(
            key: const Key('sheet_surface_add_menu'),
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
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
                      HapticFeedback.mediumImpact();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No se pudo abrir la cámara. Intenta de nuevo.'), backgroundColor: AppColors.error),
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
                      HapticFeedback.mediumImpact();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No se pudieron seleccionar las imágenes. Intenta de nuevo.'), backgroundColor: AppColors.error),
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
        ),
      ),
    ),
  );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanQueue = Provider.of<ScanQueueProvider>(context);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showingChat) {
          _closeChat();
          return;
        }
        if (_currentIndex == 1 && (_expenseHistoryKey.currentState?.isSearching ?? false)) {
          _expenseHistoryKey.currentState?.closeSearch();
          return;
        }
        if (_currentIndex == 3 && (_moreScreenKey.currentState?.isSubViewOpen ?? false)) {
          _moreScreenKey.currentState?.returnToHub();
          return;
        }
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Presiona de nuevo para salir'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _showingChat
                ? ChatScreen(
                    showBackButton: true,
                    onBack: _closeChat,
                  )
                : _FadeIndexedStack(
                    index: _currentIndex,
                    children: _pages,
                  ),
          ),
        ),
        floatingActionButton: isKeyboardOpen
            ? null
            : FloatingActionButton(
                onPressed: () => _showAddMenu(context),
                backgroundColor: AppColors.primary,
                elevation: 3,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, color: AppColors.textPrimary, size: 32),
              ),
        floatingActionButtonLocation: const _CustomCenterDockedFabLocation(),
        bottomNavigationBar: isKeyboardOpen
            ? null
            : BottomAppBar(
                color: AppColors.surface,
                shape: const CircularNotchedRectangle(),
                notchMargin: 6.0,
                padding: EdgeInsets.zero,
                height: 65, // Reducir altura
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
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
            ),
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
    final isSelected = !_showingChat && _currentIndex == index;

    Widget iconWidget = Icon(
      isSelected ? activeIcon : icon,
      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
      size: 24,
    );

    if (badgeCount > 0) {
      iconWidget = Badge.count(
        count: badgeCount,
        backgroundColor: AppColors.primaryDark,
        textColor: Colors.black,
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

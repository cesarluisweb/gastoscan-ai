import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/scan_queue_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/gemini_extraction_result.dart';
import '../../services/notification_service.dart';
import '../../services/document_scanner_service.dart';
import '../../services/sync_coordinator.dart';
import '../../services/sync_service.dart';
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
    NotificationService.instance.pendingActionNotifier.addListener(_drainLaunchActions);
    NotificationService.instance.selectedPayloadNotifier.addListener(_drainLaunchActions);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializarServiciosSegundoPlano();
      _drainLaunchActions();
    });
  }

  /// Inicialización desacoplada en segundo plano tras el primer renderizado de UI.
  Future<void> _inicializarServiciosSegundoPlano() async {
    // 1. Captura de intenciones: inicializar sin solicitar permisos bloqueantes
    try {
      await NotificationService.instance.initialize(requestPermission: false);
    } catch (e) {
      debugPrint('MainScreen: Error inicializando notificaciones locales: $e');
    }

    // 2. Suscripciones diferidas y reprogramación de recordatorios
    try {
      await NotificationService.instance.initializeFirebaseMessaging();
      await NotificationService.instance.recordActivityAndReschedule();
    } catch (e) {
      debugPrint('MainScreen: Error configurando FCM o reprogramando recordatorio: $e');
    }

    // 3. Restauración silenciosa de sesión y autenticación en 2.º plano
    if (Firebase.apps.isNotEmpty) {
      try {
        if (FirebaseAuth.instance.currentUser == null) {
          final syncService = SyncService();
          final user = await syncService.intentarLoginSilencioso().timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );
          if (user == null && FirebaseAuth.instance.currentUser == null) {
            await FirebaseAuth.instance.signInAnonymously();
          }
        }
      } catch (e) {
        debugPrint('MainScreen: Error en autenticación de segundo plano: $e');
      }
    }

    // 4. Sincronización en segundo plano centralizada en SyncCoordinator
    try {
      SyncCoordinator.instance.request(SyncTrigger.arranque);
    } catch (e) {
      debugPrint('MainScreen: Error en arranque de SyncCoordinator: $e');
    }
  }

  bool _isHandlingAction = false;

  /// Consume intenciones de navegación pendientes asegurando que ScanQueueProvider.ready
  /// haya completado su carga desde SQLite antes de evaluar comprobantes disponibles.
  Future<void> _drainLaunchActions() async {
    if (!mounted || _isHandlingAction) return;

    final action = NotificationService.instance.pendingAction;
    final payload = action?.payload ??
        NotificationService.instance.selectedPayloadNotifier.value ??
        NotificationService.instance.initialPayload;

    if (payload == null) return;

    _isHandlingAction = true;
    try {
      if (payload == 'pending_reviews') {
        final scanQueue = Provider.of<ScanQueueProvider>(context, listen: false);

        // Esperar a que ScanQueueProvider termine su carga inicial desde SQLite (máximo 8 segundos)
        try {
          await scanQueue.ready.timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('MainScreen: Tiempo de espera agotado esperando a ScanQueueProvider.ready: $e');
        }

        if (!mounted) return;

        if (scanQueue.readyItems.isNotEmpty) {
          final item = scanQueue.readyItems.first;
          try {
            final result = GeminiExtractionResult.fromQueueJson(item['extracted_data']);
            final file = File((item['image_path'] as String?) ?? '');

            if (action != null) {
              NotificationService.instance.markActionHandled(action.id);
            } else {
              NotificationService.instance.clearPayload();
            }

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReviewExpenseScreen(
                  imageFile: file.existsSync() ? file : null,
                  extractedData: result,
                  queueItemId: item['id'],
                ),
              ),
            );
            if (mounted) {
              scanQueue.loadReadyItems();
            }
          } catch (e) {
            debugPrint('Error al abrir factura desde notificación: $e');
            if (action != null) {
              NotificationService.instance.markActionHandled(action.id);
            } else {
              NotificationService.instance.clearPayload();
            }
          }
        } else {
          // No hay comprobantes listos en la cola
          if (action != null) {
            NotificationService.instance.markActionHandled(action.id);
          } else {
            NotificationService.instance.clearPayload();
          }

          _onTabTapped(1); // Navegar a pestaña Gastos
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay comprobantes pendientes por revisar.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Otros payloads (ej. broadcast_opened)
        if (action != null) {
          NotificationService.instance.markActionHandled(action.id);
        } else {
          NotificationService.instance.clearPayload();
        }
      }
    } finally {
      _isHandlingAction = false;
    }
  }

  @override
  void dispose() {
    NotificationService.instance.pendingActionNotifier.removeListener(_drainLaunchActions);
    NotificationService.instance.selectedPayloadNotifier.removeListener(_drainLaunchActions);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Provider.of<ScanQueueProvider>(context, listen: false).resumeQueueWhenOnline();
      Provider.of<GastoProvider>(context, listen: false).verificarReanudacionMesActual();
      unawaited(Provider.of<SettingsProvider>(context, listen: false).refrescarTasasSiDesactualizadas());
      SyncCoordinator.instance.request(SyncTrigger.reanudacion);
      _drainLaunchActions();
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
    if (index == 3) {
      _moreScreenKey.currentState?.onTabVisible();
      unawaited(Provider.of<SettingsProvider>(context, listen: false).refrescarTasasSiDesactualizadas());
    }
  }

  static void _abrirFormularioManual(BuildContext rootContext) {
    if (!rootContext.mounted) return;
    final gastoProvider = Provider.of<GastoProvider>(rootContext, listen: false);
    if (gastoProvider.hasPendingReplaceBlock) {
      ScaffoldMessenger.of(rootContext).clearSnackBars();
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(
          content: Text('Descarga pendiente en curso. Completa la sincronización antes de registrar gastos.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final settings = Provider.of<SettingsProvider>(rootContext, listen: false);
    Navigator.of(rootContext).push(
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
  }

  void _showAddMenu(BuildContext context) => MainScreen.showAddMenu(context);

  static void mostrarMenuAgregar(BuildContext context) {
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    if (gastoProvider.hasPendingReplaceBlock) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Descarga pendiente en curso. Completa la sincronización antes de registrar gastos.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        key: const Key('add_menu_drag_handle'),
                        margin: const EdgeInsets.only(top: 10, bottom: 14),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Text(
                        '¿Cómo quieres registrar el gasto?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.25,
                        ),
                      ),
                    ),
                    _buildAddMenuOption(
                      key: const Key('add_menu_option_manual'),
                      icon: Icons.edit_outlined,
                      title: 'Escribir gasto',
                      subtitle: 'Ingresa los datos de tu compra',
                      onTap: () {
                        Navigator.pop(ctx);
                        _abrirFormularioManual(context);
                      },
                    ),
                    _buildAddMenuDivider(),
                    _buildAddMenuOption(
                      key: const Key('add_menu_option_camera'),
                      icon: Icons.camera_alt_outlined,
                      title: 'Tomar foto de factura',
                      subtitle: 'Extrae los productos y precios',
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          final scanner = DocumentScannerService();
                          final scannedPaths = await scanner.scanDocuments();
                          if (scannedPaths.isNotEmpty && context.mounted) {
                            final scanQueue = Provider.of<ScanQueueProvider>(context, listen: false);
                            if (scannedPaths.length == 1) {
                              await scanQueue.enqueue(scannedPaths.first);
                            } else {
                              await scanQueue.enqueueMultiple(scannedPaths);
                            }
                            HapticFeedback.mediumImpact();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No se pudo abrir la cámara. Intenta de nuevo.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    _buildAddMenuDivider(),
                    _buildAddMenuOption(
                      key: const Key('add_menu_option_gallery'),
                      icon: Icons.image_outlined,
                      title: 'Elegir imagen',
                      subtitle: 'Usa una foto o captura de tu galería',
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
                              const SnackBar(
                                content: Text('No se pudieron seleccionar las imágenes. Intenta de nuevo.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    _buildAddMenuDivider(),
                    _buildAddMenuOption(
                      key: const Key('add_menu_option_voice'),
                      icon: Icons.mic_none_outlined,
                      title: 'Dictar gasto',
                      subtitle: 'Describe tu compra con tu voz',
                      onTap: () {
                        Navigator.pop(ctx);
                        VoiceExpenseSheet.show(
                          context,
                          onOpenManualExpense: () => _abrirFormularioManual(context),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildAddMenuDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 20,
      endIndent: 20,
      color: AppColors.border.withValues(alpha: 0.8),
    );
  }

  static Widget _buildAddMenuOption({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryDark,
                  width: 1,
                ),
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              reverseDuration: const Duration(milliseconds: 130),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slideAnimation = Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: slideAnimation,
                    child: child,
                  ),
                );
              },
              child: _showingChat
                  ? KeyedSubtree(
                      key: const ValueKey('main_chat_screen'),
                      child: ChatScreen(
                        showBackButton: true,
                        onBack: _closeChat,
                      ),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('main_tab_pages'),
                      child: _FadeIndexedStack(
                        index: _currentIndex,
                        children: _pages,
                      ),
                    ),
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

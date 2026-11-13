import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/settings_provider.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scan_queue_provider.dart';
import '../../services/export_service.dart';
import '../../services/update_service.dart';
import '../widgets/global_scan_queue_banner.dart';
import '../widgets/app_bar_month_selector.dart';
import '../widgets/auth_modal_sheet.dart';
import 'shopping_list_screen.dart';
import 'chat_screen.dart';
import 'receipt_gallery_screen.dart';
import 'currency_calculator_screen.dart';
import '../widgets/more/more_rates_card.dart';
import '../widgets/more/more_tools_grid.dart';
import '../widgets/currency_lens_dropdown.dart';
import '../widgets/bcv_legal_disclaimer_card.dart';
import '../../data/datasources/local/database_helper.dart';

enum MoreSubView { hub, shoppingList, chat, receiptGallery, calculator }

class MoreScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;
  final VoidCallback? onNavigateToChat;
  final VoidCallback? onNavigateToSearch;
  final User? customUser;
  final Stream<User?>? customUserStream;

  const MoreScreen({
    Key? key,
    this.onNavigateToHome,
    this.onNavigateToChat,
    this.onNavigateToSearch,
    this.customUser,
    this.customUserStream,
  }) : super(key: key);

  @override
  State<MoreScreen> createState() => MoreScreenState();
}

class MoreScreenState extends State<MoreScreen> {
  MoreSubView _currentSubView = MoreSubView.hub;
  bool get isSubViewOpen => _currentSubView != MoreSubView.hub;
  bool _isLinkingGoogle = false;
  String _currentAppVersion = '1.0.1';
  int _shoppingPendingCount = 0;

  @override
  void initState() {
    super.initState();
    _cargarVersionActual();
    _cargarComprasPendientes();
  }

  Future<void> _cargarComprasPendientes() async {
    try {
      final items = await DatabaseHelper.instance.getAllShoppingItems();
      final pendientes = items.where((it) => it.isPurchased == 0).length;
      if (mounted) {
        setState(() {
          _shoppingPendingCount = pendientes;
        });
      }
    } catch (e) {
      debugPrint('Error cargando lista de compras pendientes: $e');
    }
  }

  Future<void> _cargarVersionActual() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentAppVersion = '${info.version} (Build ${info.buildNumber})';
        });
      }
    } catch (e) {
      debugPrint('Error cargando versión de la app: $e');
    }
  }

  Future<void> _abrirGooglePlay() async {
    final launched = await UpdateService.openDownloadUrl();
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir Google Play Store.'),
        ),
      );
    }
  }

  void openChat({bool fromHome = false}) {
    if (widget.onNavigateToChat != null) {
      widget.onNavigateToChat!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ChatScreen(showBackButton: true),
        ),
      );
    }
  }

  void openShoppingList() {
    setState(() {
      _currentSubView = MoreSubView.shoppingList;
    });
  }

  void openCurrencyCalculator() {
    setState(() {
      _currentSubView = MoreSubView.calculator;
    });
  }

  void returnToHub() {
    setState(() {
      _currentSubView = MoreSubView.hub;
    });
    _cargarComprasPendientes();
  }

  bool get _isFirebaseInitialized {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<User?>? get _userStream {
    if (widget.customUserStream != null) return widget.customUserStream;
    if (widget.customUser != null) return Stream.value(widget.customUser);
    if (!_isFirebaseInitialized) return null;
    try {
      return FirebaseAuth.instance.userChanges();
    } catch (_) {
      return null;
    }
  }

  User? get _currentUser {
    if (widget.customUser != null) return widget.customUser;
    if (!_isFirebaseInitialized) return null;
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  void _exportarCsv(BuildContext context) async {
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    final gastosMes = gastoProvider.gastos;

    if (gastosMes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay gastos en este mes para exportar.')),
      );
      return;
    }

    final csvContent = ExportService.generateCsvData(gastosMes);
    final mes = DateFormatter.getMonthName(gastoProvider.selectedMonth);
    final anio = gastoProvider.selectedYear;
    final fileName = 'gastos_${mes}_$anio.csv';

    await ExportService.exportAndShare(
      content: csvContent,
      filename: fileName,
      mimeType: 'text/csv',
    );
  }

  void _exportarMarkdown(BuildContext context) async {
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    final gastosMes = gastoProvider.gastos;

    if (gastosMes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay gastos en este mes para exportar.')),
      );
      return;
    }

    final mes = DateFormatter.getMonthName(gastoProvider.selectedMonth);
    final anio = gastoProvider.selectedYear;
    final mdContent = ExportService.generateMarkdownReport(gastosMes, periodo: '$mes $anio');
    final fileName = 'reporte_${mes}_$anio.md';

    await ExportService.exportAndShare(
      content: mdContent,
      filename: fileName,
      mimeType: 'text/markdown',
    );
  }

  Future<void> _abrirUrl(String url, String mensajeError) async {
    final uri = Uri.parse(url);
    try {
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeError)),
        );
      }
    } catch (e) {
      debugPrint('Fallo al abrir URL en app externa ($url): $e');
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensajeError)),
          );
        }
      } catch (e2) {
        debugPrint('Fallo al abrir URL en fallback ($url): $e2');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensajeError)),
          );
        }
      }
    }
  }

  Future<void> _contactarSoporteWhatsApp() async {
    await _abrirUrl(
      AppConstants.soporteWhatsAppUrl,
      'No se pudo abrir WhatsApp. Escribe al: ${AppConstants.soporteWhatsAppNumero}',
    );
  }

  Future<void> _abrirSitioWeb() async {
    await _abrirUrl(
      AppConstants.websiteUrl,
      'No se pudo abrir el sitio web.',
    );
  }

  Future<void> _abrirDonaciones() async {
    await _abrirUrl(
      AppConstants.donarUrl,
      'No se pudo abrir la página de donaciones.',
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget currentWidget;

    if (_currentSubView == MoreSubView.shoppingList) {
      currentWidget = PopScope(
        key: const ValueKey('more_subview_shopping_list'),
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
          setState(() => _currentSubView = MoreSubView.hub);
        },
        child: ShoppingListScreen(
          showBackButton: true,
          onBack: () {
            ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
            setState(() => _currentSubView = MoreSubView.hub);
            _cargarComprasPendientes();
          },
        ),
      );
    } else if (_currentSubView == MoreSubView.receiptGallery) {
      currentWidget = PopScope(
        key: const ValueKey('more_subview_receipt_gallery'),
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          setState(() => _currentSubView = MoreSubView.hub);
        },
        child: ReceiptGalleryScreen(
          showBackButton: true,
          onBack: () => setState(() => _currentSubView = MoreSubView.hub),
        ),
      );
    } else if (_currentSubView == MoreSubView.calculator) {
      currentWidget = PopScope(
        key: const ValueKey('more_subview_calculator'),
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          setState(() => _currentSubView = MoreSubView.hub);
        },
        child: CurrencyCalculatorScreen(
          showBackButton: true,
          onBack: () => setState(() => _currentSubView = MoreSubView.hub),
        ),
      );
    } else {
      currentWidget = KeyedSubtree(
        key: const ValueKey('more_subview_hub'),
        child: _buildHub(context),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.05),
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
      child: currentWidget,
    );
  }

  Widget _buildHub(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final gastoProvider = Provider.of<GastoProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Más'),
        automaticallyImplyLeading: false,
        actions: [
          const AppBarMonthSelector(keyPrefix: 'more_'),
          const SizedBox(width: 4),
          IconButton(
            key: const Key('more_search_button'),
            icon: const Icon(
              Icons.search,
              size: 19,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Buscar',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border, width: 1),
              shape: const CircleBorder(),
              minimumSize: const Size(34, 34),
              maximumSize: const Size(34, 34),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: widget.onNavigateToSearch,
          ),
          const SizedBox(width: 4),
          IconButton(
            key: const Key('more_ai_chat_button'),
            icon: const Icon(
              Icons.auto_awesome,
              size: 19,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Asistente IA',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border, width: 1),
              shape: const CircleBorder(),
              minimumSize: const Size(34, 34),
              maximumSize: const Size(34, 34),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => openChat(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const GlobalScanQueueBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
              children: [
                _buildAccountSection(context),
                const SizedBox(height: 14),
                MoreRatesCard(
                  settings: settings,
                  onRefresh: () async {
                    await settings.actualizarTasaAutomatica();
                  },
                ),
                const SizedBox(height: 16),
                MoreToolsGrid(
                  shoppingListPendingCount: _shoppingPendingCount,
                  receiptCountMonth: gastoProvider.gastos
                      .where((g) => g.rutaFotoLocal != null && g.rutaFotoLocal!.isNotEmpty)
                      .length,
                  monthName: DateFormatter.getMonthName(gastoProvider.selectedMonth),
                  onOpenShoppingList: openShoppingList,
                  onOpenCalculator: openCurrencyCalculator,
                  onOpenReceipts: () {
                    setState(() {
                      _currentSubView = MoreSubView.receiptGallery;
                    });
                  },
                  onOpenChat: () => openChat(fromHome: false),
                ),
                const SizedBox(height: 16),
                _buildMasterSettingsCard(context, settings),
                const SizedBox(height: 16),
                _buildDiscreetLegalFooter(),
              ],
            ),
          ),
        ],
      ),
);
  }

  Widget _buildAccountSection(BuildContext context) {
    final stream = _userStream;
    if (stream != null) {
      return StreamBuilder<User?>(
        stream: stream,
        initialData: _currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data ?? _currentUser;
          return _buildAccountCard(context, user);
        },
      );
    }
    return _buildAccountCard(context, _currentUser);
  }

  Widget _buildAccountCard(BuildContext context, User? user) {
    final isAnon = user == null || user.isAnonymous;

    String? photoUrl = user?.photoURL;
    String? email = user?.email;
    String? displayName = user?.displayName;

    if (user != null && user.providerData.isNotEmpty) {
      for (var p in user.providerData) {
        photoUrl ??= p.photoURL;
        email ??= p.email;
        displayName ??= p.displayName;
      }
    }

    if (!isAnon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      (displayName?.isNotEmpty == true
                              ? displayName![0]
                              : (email?.isNotEmpty == true ? email![0] : 'U'))
                          .toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (displayName != null && displayName.isNotEmpty)
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    email ?? 'Cuenta vinculada',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Row(
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Sincronización activa',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('btn_ajustes_cuenta'),
              icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 20),
              tooltip: 'Ajustes de cuenta',
              onPressed: () => _mostrarHojaCuenta(context, false),
            ),
          ],
        ),
      );
    }

    // Usuario anónimo / invitado
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off, color: AppColors.primaryDark, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tus datos solo están en este teléfono',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Solo usamos tu cuenta para respaldar tus facturas en tu propio espacio privado. Sin accesos bancarios ni contraseñas.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('btn_vincular_google'),
                  icon: _isLinkingGoogle
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.login, size: 16),
                  label: Text(
                    _isLinkingGoogle ? 'Conectando...' : 'Google',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isLinkingGoogle ? null : _vincularGoogleHandler,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('btn_vincular_email'),
                  icon: const Icon(Icons.alternate_email, color: AppColors.primaryDark, size: 16),
                  label: const Text(
                    'Correo',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isLinkingGoogle ? null : () => mostrarModalAutenticacionEmail(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('btn_borrar_datos_local'),
              onPressed: () => _confirmarCerrarSesion(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Borrar datos de este teléfono',
                style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _vincularGoogleHandler() async {
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    bool descartarLocales = false;

    if (gastoProvider.gastos.isNotEmpty) {
      final decision = await mostrarDialogoFusionarOReemplazar(context);
      if (decision == null || !mounted) return;
      descartarLocales = decision;
    }

    setState(() {
      _isLinkingGoogle = true;
    });

    try {
      final error = await gastoProvider
          .vincularCuentaGoogle(descartarDatosLocales: descartarLocales);
      if (!mounted) return;
      await gastoProvider.checkPendingReplaceBlock();
      if (!mounted) return;
      if (error != null && error != 'CANCELLED') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error, style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      } else if (error == null) {
        if (descartarLocales) {
          try {
            Provider.of<ChatProvider>(context, listen: false).clearConversation();
          } catch (e) {
            debugPrint('No se pudo limpiar ChatProvider al vincular: $e');
          }
        }
        await Provider.of<SettingsProvider>(context, listen: false).loadSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta vinculada con éxito',
                style: TextStyle(color: Colors.black)),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLinkingGoogle = false;
        });
      }
    }
  }

  Widget _buildMasterSettingsCard(BuildContext context, SettingsProvider settings) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            key: const Key('more_group_preferences'),
            leading: const Icon(Icons.tune_outlined, color: AppColors.primaryDark, size: 22),
            title: const Text(
              'Preferencias y datos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
            ),
            subtitle: const Text(
              'Moneda, fotos, exportar, avisos',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            onTap: () => _mostrarHojaPreferencias(context, settings),
          ),
          const Divider(height: 1, color: AppColors.border),
          ListTile(
            key: const Key('more_group_support'),
            leading: const Icon(Icons.favorite_border, color: AppColors.primaryDark, size: 22),
            title: const Text(
              'Soporte y comunidad',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
            ),
            subtitle: const Text(
              'WhatsApp, sitio web, apoyar',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            onTap: () => _mostrarHojaSoporte(context),
          ),
          const Divider(height: 1, color: AppColors.border),
          ListTile(
            key: const Key('more_group_about'),
            leading: const Icon(Icons.info_outline, color: AppColors.primaryDark, size: 22),
            title: const Text(
              'Sobre Rinde Más',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
            ),
            subtitle: const Text(
              'Google Play, privacidad, términos',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            onTap: () => _mostrarHojaSobreApp(context),
          ),
        ],
      ),
    );
  }

  void _mostrarHojaPreferencias(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Material(
            key: const Key('sheet_surface_preferences'),
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Preferencias y datos',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 14),
                      AnimatedBuilder(
                        animation: settings,
                        builder: (animCtx, _) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Moneda de reportes',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Define la moneda predeterminada en Inicio, Gastos y Análisis.',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  CurrencyLensDropdown(
                                    dropdownKey: const Key('more_currency_lens_dropdown'),
                                    monedaSeleccionada: settings.monedaPrincipal,
                                    onMonedaChanged: (newMoneda) {
                                      settings.setMonedaPrincipal(newMoneda);
                                    },
                                  ),
                                ],
                              ),
                              const Divider(height: 20, color: AppColors.border),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeThumbColor: AppColors.primaryDark,
                                title: const Text(
                                  'Guardar copia en la galería del teléfono',
                                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text(
                                  'Guarda una copia en el álbum "Rinde Más" de tu galería. Queda en tu teléfono aunque elimines tu cuenta.',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                                value: settings.guardarFotos,
                                onChanged: (val) => settings.setGuardarFotos(val),
                              ),
                            ],
                          );
                        },
                      ),
                      const Divider(height: 16, color: AppColors.border),
                      const Text(
                        'Exportar gastos del mes',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _exportarCsv(context);
                              },
                              icon: const Icon(Icons.table_chart_outlined, size: 16, color: AppColors.textPrimary),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Excel (.csv)', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _exportarMarkdown(context);
                              },
                              icon: const Icon(Icons.description_outlined, size: 16, color: AppColors.textPrimary),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Texto (.md)', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: AppColors.border),
                      ListTile(
                        key: const Key('more_menu_notifications'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.notifications_outlined, color: AppColors.primaryDark, size: 22),
                        title: const Text('Notificaciones y avisos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        subtitle: const Text('Recordatorios de compras y alertas del asistente', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showNotificationSettingsModal(context, settings);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _mostrarHojaSoporte(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Material(
            key: const Key('sheet_surface_support'),
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Soporte y comunidad',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        key: const Key('more_menu_support_whatsapp'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.chat_outlined, color: AppColors.primaryDark),
                        title: const Text('Escribir a soporte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('Contáctanos directamente por WhatsApp', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        trailing: const Icon(Icons.open_in_new, size: 16, color: AppColors.textSecondary),
                        onTap: () {
                          Navigator.pop(ctx);
                          _contactarSoporteWhatsApp();
                        },
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      ListTile(
                        key: const Key('more_menu_website'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.language_outlined, color: AppColors.primaryDark),
                        title: const Text('Visitar sitio web', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('rindemas.cesarluis.com', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        trailing: const Icon(Icons.open_in_new, size: 16, color: AppColors.textSecondary),
                        onTap: () {
                          Navigator.pop(ctx);
                          _abrirSitioWeb();
                        },
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      ListTile(
                        key: const Key('more_menu_donate'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.coffee_outlined, color: AppColors.primaryDark),
                        title: const Text('Apoyar el proyecto ☕', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('Haz una donación para mantener Rinde Más gratuito', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        trailing: const Icon(Icons.open_in_new, size: 16, color: AppColors.textSecondary),
                        onTap: () {
                          Navigator.pop(ctx);
                          _abrirDonaciones();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _mostrarHojaSobreApp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Material(
            key: const Key('sheet_surface_about'),
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Sobre Rinde Más',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        key: const Key('btn_ver_google_play'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.shop_outlined, color: AppColors.primaryDark),
                        title: const Text('Ver en Google Play', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(
                          'Actualizaciones, reseñas · v$_currentAppVersion',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        trailing: const Icon(Icons.open_in_new, size: 16, color: AppColors.textSecondary),
                        onTap: () {
                          Navigator.pop(ctx);
                          _abrirGooglePlay();
                        },
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      ListTile(
                        key: const Key('more_menu_privacy_policy'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primaryDark),
                        title: const Text('Política de privacidad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('Cómo protegemos tus datos y facturas', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        trailing: const Icon(Icons.open_in_new, size: 16, color: AppColors.textSecondary),
                        onTap: () {
                          Navigator.pop(ctx);
                          _abrirUrl(AppConstants.privacidadUrl, 'No se pudo abrir la política de privacidad');
                        },
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      ListTile(
                        key: const Key('more_menu_terms'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined, color: AppColors.primaryDark),
                        title: const Text('Términos y condiciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('Condiciones de uso de Rinde Más', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        trailing: const Icon(Icons.open_in_new, size: 16, color: AppColors.textSecondary),
                        onTap: () {
                          Navigator.pop(ctx);
                          _abrirUrl(AppConstants.terminosUrl, 'No se pudo abrir los términos');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _mostrarHojaCuenta(BuildContext context, bool isAnon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Material(
            key: const Key('sheet_surface_account'),
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Cuenta y seguridad',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('btn_cerrar_sesion'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.logout, size: 16, color: AppColors.textSecondary),
                        label: const Text('Cerrar sesión', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmarCerrarSesion(context);
                        },
                      ),
                      if (!isAnon) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Zona de Peligro',
                                      style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Elimina tu usuario en la nube, presupuestos y gastos sincronizados.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  key: const Key('btn_eliminar_cuenta'),
                                  icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                  label: const Text('Eliminar cuenta y datos', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.error),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _confirmarEliminarCuenta(context);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscreetLegalFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BcvLegalDisclaimerCard(
          cardKey: const Key('more_rates_bcv_disclaimer'),
          linkKey: const Key('more_rates_bcv_source_link'),
          onOpenBcv: () => _abrirUrl(
            'https://www.bcv.org.ve/',
            'No se pudo abrir la página del BCV',
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Rinde Más v$_currentAppVersion',
            key: const Key('more_app_version_footer'),
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmarCerrarSesion(BuildContext context) async {
    final user = _currentUser;
    final esVinculado = user != null && !user.isAnonymous;
    final copyMensaje = esVinculado
        ? 'Tus gastos numéricos están respaldados en la nube. Las fotos de facturas quedarán guardadas en este teléfono pero no se sincronizan con la nube ni se volverán a vincular a tus gastos.'
        : 'Al cerrar sesión sin vincular una cuenta, tus datos se perderán de forma permanente. Las fotos guardadas permanecerán en este teléfono pero no podrás volver a verlas desde la app.';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: Text(
          copyMensaje,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: esVinculado ? AppColors.primary : AppColors.error,
              foregroundColor: esVinculado ? Colors.black : Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    final scanQueue = Provider.of<ScanQueueProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    await gastoProvider.cerrarSesion();
    try {
      Provider.of<ChatProvider>(context, listen: false).clearConversation();
    } catch (e) {
      debugPrint('No se pudo limpiar ChatProvider al cerrar sesión: $e');
    }
    await scanQueue.loadQueue();
    await settingsProvider.loadSettings();

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión cerrada. Dispositivo listo para una nueva cuenta.',
              style: TextStyle(color: Colors.black)),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _confirmarEliminarCuenta(BuildContext context) async {
    bool eliminarFotos = false;
    String deleteConfirmText = '';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogBodyCtx, setDialogState) => AlertDialog(
          title: const Text('¿Eliminar cuenta y datos?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esta acción es definitiva e irreversible. Se eliminará permanentemente tu usuario en la nube, tus gastos y tus presupuestos sincronizados. Los registros en este dispositivo también se borrarán.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Para confirmar, escribe "ELIMINAR" abajo:',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('delete_account_confirm_input'),
                  decoration: const InputDecoration(
                    hintText: 'ELIMINAR',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onChanged: (val) {
                    setDialogState(() {
                      deleteConfirmText = val.trim();
                    });
                  },
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: eliminarFotos,
                  activeColor: AppColors.error,
                  title: const Text(
                    'Eliminar también los archivos de fotos de comprobantes de este teléfono',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  ),
                  onChanged: (val) {
                    setDialogState(() {
                      eliminarFotos = val ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: deleteConfirmText.toUpperCase() == 'ELIMINAR'
                  ? () => Navigator.pop(dialogCtx, true)
                  : null,
              child: const Text('Eliminar definitivamente'),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true || !mounted) return;

    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    final scanQueue = Provider.of<ScanQueueProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    String? error = await gastoProvider.eliminarCuentaYDatos(eliminarFotos: eliminarFotos);

    if (!mounted) return;

    if (error == 'REQUIRES_PASSWORD_REAUTH') {
      String enteredPassword = '';
      final reauthConfirm = await showDialog<bool>(
        context: context,
        builder: (reauthCtx) => AlertDialog(
          title: const Text('Confirma tu contraseña'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Por seguridad, ingresa tu contraseña actual para autorizar la eliminación de tu cuenta.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  onChanged: (val) {
                    enteredPassword = val.trim();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(reauthCtx, false),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(reauthCtx, true),
              child: const Text('Confirmar y eliminar'),
            ),
          ],
        ),
      );

      if (reauthConfirm == true && enteredPassword.isNotEmpty && mounted) {
        error = await gastoProvider.eliminarCuentaYDatos(
          reauthPassword: enteredPassword,
          eliminarFotos: eliminarFotos,
        );
      } else {
        return;
      }
    }

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error,
        ),
      );
    } else {
      try {
        Provider.of<ChatProvider>(context, listen: false).clearConversation();
      } catch (e) {
        debugPrint('No se pudo limpiar ChatProvider al eliminar cuenta: $e');
      }
      await scanQueue.loadQueue();
      await settingsProvider.loadSettings();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta y datos eliminados. Sesión cerrada.',
                style: TextStyle(color: Colors.black)),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  void _showNotificationSettingsModal(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Material(
                key: const Key('sheet_surface_notifications'),
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.notifications_active_outlined, color: AppColors.primaryDark, size: 22),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Notificaciones',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                                onPressed: () => Navigator.pop(modalCtx),
                              ),
                            ],
                          ),
                          const Text(
                            'Personaliza cómo y cuándo Rinde Más se comunica contigo.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: AppColors.primaryDark,
                            title: const Text(
                              'Recordatorio quincenal de compras',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Avisos los sábados cada dos semanas para fotografiar facturas y comprobantes.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            value: settings.recordatorioFinDeSemana,
                            onChanged: (val) {
                              setModalState(() {});
                              settings.setRecordatorioFinDeSemana(val);
                            },
                          ),
                          const Divider(height: 16, color: AppColors.border),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: AppColors.primaryDark,
                            title: const Text(
                              'Recordatorio de inactividad',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Aviso suave si pasa un mes sin registrar gastos para mantener tu presupuesto al día.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            value: settings.recordatoriosActivos,
                            onChanged: (val) {
                              setModalState(() {});
                              settings.setRecordatoriosActivos(val);
                            },
                          ),
                          const Divider(height: 16, color: AppColors.border),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: AppColors.primaryDark,
                            title: const Text(
                              'Avisos y novedades',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Notificaciones sobre nuevas funciones y mejoras importantes de Rinde Más.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            value: settings.anunciosActivos,
                            onChanged: (val) {
                              setModalState(() {});
                              settings.setAnunciosActivos(val);
                            },
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(modalCtx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Listo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

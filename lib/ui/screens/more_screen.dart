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
import '../../services/export_service.dart';
import '../../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../widgets/global_scan_queue_banner.dart';
import 'shopping_list_screen.dart';
import 'chat_screen.dart';

enum MoreSubView { hub, shoppingList, chat }

class MoreScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;
  const MoreScreen({Key? key, this.onNavigateToHome}) : super(key: key);

  @override
  State<MoreScreen> createState() => MoreScreenState();
}

class MoreScreenState extends State<MoreScreen> {
  MoreSubView _currentSubView = MoreSubView.hub;
  bool _openedFromHome = false;
  bool _isCheckingUpdate = false;
  String _currentAppVersion = '1.0.1';

  @override
  void initState() {
    super.initState();
    _cargarVersionActual();
  }

  Future<void> _cargarVersionActual() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentAppVersion = '${info.version} (Build ${info.buildNumber})';
        });
      }
    } catch (_) {}
  }

  Future<void> _comprobarActualizacionManual() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    try {
      final updateService = UpdateService();
      final updateInfo = await updateService.checkForUpdate(force: true);

      if (!mounted) return;
      setState(() => _isCheckingUpdate = false);

      if (updateInfo != null && updateInfo.hasUpdate) {
        UpdateDialog.show(context, updateInfo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tienes la versión más reciente instalada.',
              style: TextStyle(color: Colors.black),
            ),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingUpdate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo verificar actualizaciones en este momento.'),
        ),
      );
    }
  }

  void openChat({bool fromHome = false}) {
    setState(() {
      _openedFromHome = fromHome;
      _currentSubView = MoreSubView.chat;
    });
  }

  void openShoppingList() {
    setState(() {
      _currentSubView = MoreSubView.shoppingList;
    });
  }

  void returnToHub() {
    setState(() {
      _openedFromHome = false;
      _currentSubView = MoreSubView.hub;
    });
  }

  bool get _isFirebaseInitialized {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<User?>? get _userStream {
    if (!_isFirebaseInitialized) return null;
    try {
      return FirebaseAuth.instance.userChanges();
    } catch (_) {
      return null;
    }
  }

  User? get _currentUser {
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
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeError)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeError)),
        );
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
    if (_currentSubView == MoreSubView.shoppingList) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          setState(() => _currentSubView = MoreSubView.hub);
        },
        child: ShoppingListScreen(
          showBackButton: true,
          onBack: () => setState(() => _currentSubView = MoreSubView.hub),
        ),
      );
    }

    if (_currentSubView == MoreSubView.chat) {
      void handleBack() {
        final wasFromHome = _openedFromHome;
        setState(() {
          _currentSubView = MoreSubView.hub;
          _openedFromHome = false;
        });
        if (wasFromHome) {
          widget.onNavigateToHome?.call();
        }
      }

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          handleBack();
        },
        child: ChatScreen(
          showBackButton: true,
          onBack: handleBack,
        ),
      );
    }

    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Más'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const GlobalScanQueueBanner(),
          Expanded(
            child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
        children: [
          // Sección de Cuenta y Respaldo en la Nube
          _buildAccountSection(context),
          const SizedBox(height: 16),

          // Herramientas: Lista de Compras y Asistente IA
          Material(
            color: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  key: const Key('more_menu_shopping_list'),
                  leading: const Icon(Icons.shopping_cart_outlined, color: AppColors.primaryDark, size: 24),
                  title: const Text('Lista de Compras',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Prepara tus compras del supermercado',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () {
                    setState(() {
                      _currentSubView = MoreSubView.shoppingList;
                    });
                  },
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  key: const Key('more_menu_chat_ai'),
                  leading: const Icon(Icons.auto_awesome, color: AppColors.primaryDark, size: 24),
                  title: const Text('Asistente IA',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Consultas inteligentes sobre tus finanzas',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () {
                    openChat(fromHome: false);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sección de Moneda y Tasas
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.currency_exchange, color: AppColors.primaryDark, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Tasas de Cambio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            () {
                              final updateDate = settings.ultimaActualizacionTasas;
                              final today = DateTime.now();
                              if (updateDate != null &&
                                  updateDate.year == today.year &&
                                  updateDate.month == today.month &&
                                  updateDate.day == today.day) {
                                return '✓ Actualizada hoy';
                              }
                              return 'Tasas del día';
                            }(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          key: const Key('refresh_rates_btn'),
                          icon: settings.isSyncingRate
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
                          tooltip: 'Actualizar tasas',
                          onPressed: settings.isSyncingRate
                              ? null
                              : () async {
                                  await settings.actualizarTasaAutomatica();
                                },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      // Fila Dólar BCV
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.attach_money, size: 18, color: AppColors.primaryDark),
                              SizedBox(width: 6),
                              Text(
                                'Dólar BCV',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Bs. ${settings.tasaCambioVesUsd.toStringAsFixed(2)} / USD',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: AppColors.border),
                      ),
                      // Fila Euro BCV
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.euro, size: 18, color: AppColors.primaryDark),
                              SizedBox(width: 6),
                              Text(
                                'Euro BCV',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Bs. ${settings.tasaCambioVesEur.toStringAsFixed(2)} / EUR',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: AppColors.border),
                      ),
                      // Fila USDT Binance
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.currency_bitcoin, size: 18, color: AppColors.primaryDark),
                              SizedBox(width: 6),
                              Text(
                                'USDT Binance',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Bs. ${settings.tasaCambioVesUsdt.toStringAsFixed(2)} / USDT',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: AppConstants.monedas.contains(settings.monedaPrincipal) ? settings.monedaPrincipal : 'USD',
                  decoration: const InputDecoration(
                    labelText: 'Moneda Principal de Reportes',
                    prefixIcon: Icon(Icons.monetization_on_outlined, color: AppColors.textSecondary),
                  ),
                  dropdownColor: AppColors.surface,
                  items: const [
                    DropdownMenuItem(value: 'USD', child: Text('Dólares (\$ USD)')),
                    DropdownMenuItem(value: 'VES', child: Text('Bolívares (Bs. VES)')),
                    DropdownMenuItem(value: 'EUR', child: Text('Euros (€ EUR)')),
                    DropdownMenuItem(value: 'USDT', child: Text('USDT (Binance)')),
                  ],
                  onChanged: (val) {
                    if (val != null) settings.setMonedaPrincipal(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sección de Almacenamiento y Fotos
          Material(
            color: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storage_outlined, color: AppColors.primaryDark, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Almacenamiento y Fotos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryDark,
                    title: const Text(
                      'Guardar copia de fotos en el dispositivo',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Si está desactivado, la foto se elimina inmediatamente tras extraer los datos para ahorrar espacio.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    value: settings.guardarFotos,
                    onChanged: (val) => settings.setGuardarFotos(val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sección de Exportar Reportes
          Material(
            color: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined, color: AppColors.primaryDark),
                  title: const Text('Exportar a Excel (.csv)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: const Icon(Icons.share_outlined, size: 20, color: AppColors.textSecondary),
                  onTap: () => _exportarCsv(context),
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: AppColors.primaryDark),
                  title: const Text('Exportar como Texto (.md)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: const Icon(Icons.share_outlined, size: 20, color: AppColors.textSecondary),
                  onTap: () => _exportarMarkdown(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sección de Ayuda y Comunidad
          Material(
            color: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  key: const Key('more_menu_support_whatsapp'),
                  leading: const Icon(Icons.chat_outlined, color: AppColors.primaryDark),
                  title: const Text(
                    'Escribir a soporte',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Contáctanos directamente por WhatsApp',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 18, color: AppColors.textSecondary),
                  onTap: _contactarSoporteWhatsApp,
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  key: const Key('more_menu_website'),
                  leading: const Icon(Icons.language_outlined, color: AppColors.primaryDark),
                  title: const Text(
                    'Visitar sitio web',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'rindemas.cesarluis.com',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 18, color: AppColors.textSecondary),
                  onTap: _abrirSitioWeb,
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  key: const Key('more_menu_donate'),
                  leading: const Icon(Icons.coffee_outlined, color: AppColors.primaryDark),
                  title: const Text(
                    'Apoyar el proyecto ☕',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Haz una donación para mantener Rinde Más gratuito',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 18, color: AppColors.textSecondary),
                  onTap: _abrirDonaciones,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sección de Versión y Actualizaciones
          Material(
            color: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: AppColors.primaryDark),
                  title: const Text(
                    'Versión de la App',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Rinde Más v$_currentAppVersion',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  trailing: _isCheckingUpdate
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                        )
                      : TextButton.icon(
                          onPressed: _comprobarActualizacionManual,
                          icon: const Icon(Icons.refresh, size: 16, color: AppColors.textPrimary),
                          label: const Text(
                            'Buscar',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
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
        builder: (context, snapshot) {
          final user = snapshot.data ?? _currentUser;
          return _buildAccountCard(context, user);
        },
      );
    }
    return _buildAccountCard(context, null);
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isAnon ? Icons.cloud_off : Icons.cloud_done,
                  color: AppColors.primaryDark, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Respaldo en la Nube',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isAnon)
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
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
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (displayName != null && displayName.isNotEmpty)
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      Text(
                        email ?? 'Cuenta de Google vinculada',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      const Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Sincronización activa',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            const Text(
              'Solo usamos tu cuenta de Google para respaldar tus facturas en tu propio espacio privado. Sin accesos bancarios ni contraseñas.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          const SizedBox(height: 16),
          if (isAnon)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Vincular con Google'),
                onPressed: () async {
                  final error = await Provider.of<GastoProvider>(context, listen: false)
                      .vincularCuentaGoogle();
                  if (!mounted) return;
                  if (error != null && error != 'CANCELLED') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $error')),
                    );
                  } else if (error == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cuenta vinculada con éxito',
                            style: TextStyle(color: Colors.black)),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                },
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text('Cerrar Sesión', style: TextStyle(color: AppColors.error)),
                onPressed: () async {
                  if (_isFirebaseInitialized) {
                    await FirebaseAuth.instance.signOut();
                    await FirebaseAuth.instance.signInAnonymously();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

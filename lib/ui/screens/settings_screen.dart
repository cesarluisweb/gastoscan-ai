import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/settings_provider.dart';
import '../../providers/gasto_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _tasaCambioCtrl = TextEditingController();
  final _presupuestoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      _tasaCambioCtrl.text = settings.tasaCambioVesUsd.toString();
      if (settings.presupuestoMensual > 0) {
        _presupuestoCtrl.text = settings.presupuestoMensual.toStringAsFixed(2);
      }
    });
  }

  @override
  void dispose() {
    _tasaCambioCtrl.dispose();
    _presupuestoCtrl.dispose();
    super.dispose();
  }

  void _guardarConfiguracion() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    final tasa = double.tryParse(_tasaCambioCtrl.text.replaceAll(',', '.'));
    if (tasa != null) {
      await settings.setTasaCambio(tasa);
    }

    final presupuesto = double.tryParse(_presupuestoCtrl.text.replaceAll(',', '.'));
    if (presupuesto != null) {
      await settings.setPresupuestoMensual(presupuesto);
    } else if (_presupuestoCtrl.text.trim().isEmpty) {
      await settings.setPresupuestoMensual(0.0);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ajustes guardados correctamente'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    final user = FirebaseAuth.instance.currentUser;
    final isAnon = user == null || user.isAnonymous;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección de Cuenta y Sincronización
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isAnon ? Icons.cloud_off : Icons.cloud_done, color: AppColors.primary, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Respaldo en la Nube',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isAnon && user.photoURL != null)
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(user.photoURL!),
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sincronización activa.\n${user.email}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    isAnon
                        ? 'Inicia sesión con Google para no perder tus datos si cambias de teléfono. Tus gastos actuales se guardarán.'
                        : 'Sincronización activa. Cuenta vinculada a:\n${user.email}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                const SizedBox(height: 16),
                if (isAnon)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Vincular con Google'),
                      onPressed: () async {
                        final error = await Provider.of<GastoProvider>(context, listen: false).vincularCuentaGoogle();
                        if (error != null) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $error')),
                          );
                        }
                        setState(() {}); // Refrescar UI tras login
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
                        await FirebaseAuth.instance.signOut();
                        await FirebaseAuth.instance.signInAnonymously();
                        setState(() {});
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sección de Almacenamiento y Fotos
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
                const Row(
                  children: [
                    Icon(Icons.storage_outlined, color: AppColors.secondary, size: 20),
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
                  activeColor: AppColors.primary,
                  title: const Text(
                    'Guardar copia de fotos en el dispositivo',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Si está desactivado, la foto se elimina inmediatamente tras extraer el texto para ahorrar espacio.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  value: settings.guardarFotos,
                  onChanged: (val) => settings.setGuardarFotos(val),
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
                const Row(
                  children: [
                    Icon(Icons.currency_exchange, color: AppColors.warning, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Tasa de Cambio Automática',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tasa Oficial BCV del Día:',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bs. ${settings.tasaCambioVesUsd.toStringAsFixed(2)} / USD',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: settings.isSyncingRate
                            ? null
                            : () async {
                                await settings.actualizarTasaAutomatica();
                                _tasaCambioCtrl.text = settings.tasaCambioVesUsd.toStringAsFixed(2);
                              },
                        icon: settings.isSyncingRate
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.sync, size: 16),
                        label: const Text('Actualizar'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: settings.monedaPrincipal,
                  decoration: const InputDecoration(
                    labelText: 'Moneda Principal de Reportes',
                    prefixIcon: Icon(Icons.monetization_on_outlined, color: AppColors.textSecondary),
                  ),
                  dropdownColor: AppColors.surface,
                  items: AppConstants.monedas.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) settings.setMonedaPrincipal(val);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _presupuestoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Presupuesto Mensual (USD)',
                    hintText: 'Ej. 300',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _guardarConfiguracion,
            child: const Text('Guardar Ajustes'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    final user = _currentUser;
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
          StreamBuilder<User?>(
            stream: _userStream ?? const Stream.empty(),
            builder: (context, snapshot) {
              final user = snapshot.data ?? _currentUser;
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
                        Icon(isAnon ? Icons.cloud_off : Icons.cloud_done, color: AppColors.primaryDark, size: 24),
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
                        'Inicia sesión con Google para no perder tus datos si cambias de teléfono. Tus gastos actuales se guardarán.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
                            if (!mounted) return;
                            if (error != null && error != 'CANCELLED') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $error')),
                              );
                            } else if (error == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cuenta vinculada con éxito', style: TextStyle(color: Colors.black)),
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
            },
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
                  activeColor: AppColors.primaryDark,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

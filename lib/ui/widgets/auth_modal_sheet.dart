import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';

/// Diálogo reutilizable para preguntar al usuario si desea conservar/sumar
/// los gastos locales no respaldados o reemplazarlos con el respaldo existente en la nube.
Future<bool?> mostrarDialogoFusionarOReemplazar(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Gastos en este teléfono'),
      content: const Text(
        'Tienes gastos registrados en este dispositivo sin cuenta. ¿Deseas conservarlos y sumarlos a tu cuenta en la nube, o reemplazarlos con tu respaldo existente?',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, true),
          child: const Text('Reemplazar', style: TextStyle(color: AppColors.error)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
          ),
          onPressed: () => Navigator.pop(dialogCtx, false),
          child: const Text('Conservar y sumar'),
        ),
      ],
    ),
  );
}

/// Modal inferior centralizado para vincular o iniciar sesión con correo electrónico
Future<void> mostrarModalAutenticacionEmail(
  BuildContext context, {
  VoidCallback? onSuccess,
}) {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool esRegistro = true;
  bool obscurePassword = true;
  bool isLoading = false;
  String? localError;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (modalContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final mediaQuery = MediaQuery.of(context);
          return Padding(
            padding: EdgeInsets.only(
              bottom: mediaQuery.viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.alternate_email, color: AppColors.primaryDark, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            esRegistro ? 'Vincular con Correo' : 'Iniciar Sesión con Correo',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(modalContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    esRegistro
                        ? 'Puedes usar cualquier correo electrónico para respaldar tus facturas de forma segura.'
                        : 'Ingresa tu correo y contraseña para restaurar y sincronizar tus gastos.',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (localError != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              localError!,
                              style: const TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'tu@correo.com',
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryDark),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      hintText: 'Mínimo 6 caracteres',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryDark),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setModalState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              final email = emailController.text.trim();
                              final password = passwordController.text;

                              if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
                                setModalState(() {
                                  localError = 'Ingresa un correo electrónico válido.';
                                });
                                return;
                              }
                              if (password.length < 6) {
                                setModalState(() {
                                  localError = 'La contraseña debe tener al menos 6 caracteres.';
                                });
                                return;
                              }

                              setModalState(() {
                                isLoading = true;
                                localError = null;
                              });

                              final provider = Provider.of<GastoProvider>(context, listen: false);
                              bool descartarLocales = false;

                              if (provider.gastos.isNotEmpty) {
                                final decision = await mostrarDialogoFusionarOReemplazar(context);
                                if (decision == null) {
                                  if (modalContext.mounted) {
                                    setModalState(() {
                                      isLoading = false;
                                    });
                                  }
                                  return;
                                }
                                descartarLocales = decision;
                              }

                              final error = esRegistro
                                  ? await provider.vincularConEmail(email, password, descartarDatosLocales: descartarLocales)
                                  : await provider.iniciarSesionConEmail(email, password, descartarDatosLocales: descartarLocales);

                              if (!modalContext.mounted) return;

                              if (error != null) {
                                setModalState(() {
                                  isLoading = false;
                                  localError = error;
                                });
                              } else {
                                Navigator.pop(modalContext);
                                await Provider.of<SettingsProvider>(context, listen: false).loadSettings();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      esRegistro ? 'Cuenta vinculada con éxito' : 'Sesión iniciada con éxito',
                                      style: const TextStyle(color: Colors.black),
                                    ),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                                onSuccess?.call();
                              }
                            },
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : Text(
                              esRegistro ? 'Vincular y Respaldar' : 'Iniciar Sesión',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              setModalState(() {
                                esRegistro = !esRegistro;
                                localError = null;
                              });
                            },
                      child: Text(
                        esRegistro
                            ? '¿Ya tienes una cuenta registrada? Inicia sesión aquí'
                            : '¿No tienes cuenta? Vincular correo aquí',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

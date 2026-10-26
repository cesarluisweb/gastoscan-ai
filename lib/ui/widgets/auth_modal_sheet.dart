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

/// Diálogo flotante centrado para vincular o iniciar sesión con correo electrónico
Future<void> mostrarModalAutenticacionEmail(
  BuildContext context, {
  VoidCallback? onSuccess,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AuthEmailDialog(onSuccess: onSuccess),
  );
}

class AuthEmailDialog extends StatefulWidget {
  final VoidCallback? onSuccess;

  const AuthEmailDialog({Key? key, this.onSuccess}) : super(key: key);

  @override
  State<AuthEmailDialog> createState() => _AuthEmailDialogState();
}

class _AuthEmailDialogState extends State<AuthEmailDialog> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _esRegistro = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _localError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() {
        _localError = 'Ingresa un correo electrónico válido.';
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _localError = 'La contraseña debe tener al menos 6 caracteres.';
      });
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    bool descartarLocales = false;
    if (gastoProvider.gastos.isNotEmpty) {
      final decision = await mostrarDialogoFusionarOReemplazar(context);
      if (decision == null) return;
      descartarLocales = decision;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _localError = null;
    });

    try {
      final error = _esRegistro
          ? await gastoProvider.vincularConEmail(email, password, descartarDatosLocales: descartarLocales)
          : await gastoProvider.iniciarSesionConEmail(email, password, descartarDatosLocales: descartarLocales);

      if (!mounted) return;

      if (error != null) {
        setState(() {
          _isLoading = false;
          _localError = error;
        });
      } else {
        Navigator.pop(context);
        await settingsProvider.loadSettings();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _esRegistro ? 'Cuenta vinculada con éxito' : 'Sesión iniciada con éxito',
              style: const TextStyle(color: Colors.black),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        widget.onSuccess?.call();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _localError = 'Ocurrió un error al procesar la solicitud. Verifica tu conexión e intenta de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          key: const Key('dialog_surface_auth'),
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.alternate_email, color: AppColors.primaryDark, size: 24),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _esRegistro ? 'Vincular con Correo' : 'Iniciar Sesión con Correo',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _esRegistro
                      ? 'Puedes usar cualquier correo electrónico para respaldar tus facturas de forma segura.'
                      : 'Ingresa tu correo y contraseña para restaurar y sincronizar tus gastos.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (_localError != null) ...[
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
                            _localError!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  key: const Key('auth_email_input'),
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'tu@correo.com',
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryDark),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('auth_password_input'),
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Mínimo 6 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryDark),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
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
                    key: const Key('auth_submit_btn'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.8),
                      disabledForegroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  _esRegistro ? 'Sincronizando...' : 'Iniciando sesión...',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _esRegistro ? 'Vincular y Respaldar' : 'Iniciar Sesión',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    key: const Key('auth_toggle_mode_btn'),
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _esRegistro = !_esRegistro;
                              _localError = null;
                            });
                          },
                    child: Text(
                      _esRegistro
                          ? '¿Ya tienes una cuenta registrada? Inicia sesión aquí'
                          : '¿No tienes cuenta? Vincular correo aquí',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

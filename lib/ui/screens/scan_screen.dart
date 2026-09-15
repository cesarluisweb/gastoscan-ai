import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/datasources/remote/gemini_service.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/scan_queue_provider.dart';
import '../../services/image_service.dart';
import 'review_expense_screen.dart';
import 'settings_screen.dart';

class ScanScreen extends StatefulWidget {
  final ImagePicker? imagePicker;
  const ScanScreen({Key? key, this.imagePicker}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final ImagePicker _picker;
  final GeminiService _geminiService = GeminiService();
  File? _selectedImage;
  bool _isProcessing = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final pickedFiles = await _picker.pickMultiImage(imageQuality: 90);
        if (pickedFiles.isNotEmpty) {
          if (pickedFiles.length == 1) {
            setState(() {
              _selectedImage = File(pickedFiles.first.path);
            });
          } else {
            final queueProvider = Provider.of<ScanQueueProvider>(context, listen: false);
            final paths = pickedFiles.map((file) => file.path).toList();
            await queueProvider.enqueueMultiple(paths);
            if (!mounted) return;
            Navigator.pop(context); // Volver al inicio de forma silenciosa e inmediata
          }
        }
      } else {
        final pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 90,
        );

        if (pickedFile != null) {
          setState(() {
            _selectedImage = File(pickedFile.path);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al capturar imagen: ${e.toString()}')),
      );
    }
  }

  Future<void> _processWithGemini() async {
    if (_selectedImage == null) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final keyToUse = 'proxy';

    setState(() {
      _isProcessing = true;
      _statusText = 'Comprimiendo imagen...';
    });

    try {
      final compressedBytes = await ImageService.compressImage(_selectedImage!);

      setState(() {
        _statusText = 'Obteniendo lista de compras pendiente...';
      });
      final pendingItems = await DatabaseHelper.instance.getPendingShoppingItems();

      setState(() {
        _statusText = 'Leyendo factura...';
      });

      final extractionResult = await _geminiService.analyzeReceiptImage(
        imageBytes: compressedBytes,
        apiKey: keyToUse,
        pendingShoppingItems: pendingItems,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewExpenseScreen(
            imageFile: _selectedImage!,
            extractedData: extractionResult,
          ),
        ),
      );

      // Limpiar el estado al regresar
      if (mounted) {
        setState(() {
          _selectedImage = null;
          _isProcessing = false;
          _statusText = null;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = null;
      });

      // Guardar en la cola offline si falla
      final queueProvider = Provider.of<ScanQueueProvider>(context, listen: false);
      await queueProvider.addPendingItem(_selectedImage!.path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sin conexión. La factura se guardó en cola y se procesará cuando haya internet.'),
          backgroundColor: AppColors.info,
          duration: Duration(seconds: 4),
        ),
      );
      Navigator.pop(context); // Volver al inicio
    }
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Factura'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Expanded(
                  child: _selectedImage == null
                      ? _buildEmptyState()
                      : _buildImagePreview(),
                ),
                const SizedBox(height: 20),
                if (_selectedImage == null)
                  _buildCaptureOptions()
                else
                  _buildActionButtons(),
              ],
            ),
          ),
          if (_isProcessing) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Digitaliza tus facturas',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Toma una foto a una factura física o sube una imagen de tu galería.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildCaptureOptions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Galería'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Cámara'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _selectedImage = null),
            child: const Text('Reintentar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _processWithGemini,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Procesar con IA'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                _statusText ?? 'Procesando...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Detectando comercio, montos y productos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

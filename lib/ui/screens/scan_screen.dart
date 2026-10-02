import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/datasources/remote/gemini_service.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/scan_queue_provider.dart';
import '../../services/image_service.dart';
import '../../services/document_scanner_service.dart';
import 'review_expense_screen.dart';
import 'settings_screen.dart';

class ScanScreen extends StatefulWidget {
  final ImagePicker? imagePicker;
  final ImageSource? initialSource;
  final GeminiService? geminiService;
  final DatabaseHelper? dbHelper;
  final DocumentScannerService? documentScannerService;
  const ScanScreen({
    Key? key,
    this.imagePicker,
    this.initialSource,
    this.geminiService,
    this.dbHelper,
    this.documentScannerService,
  }) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final ImagePicker _picker;
  late final GeminiService _geminiService;
  late final DatabaseHelper _dbHelper;
  late final DocumentScannerService _scannerService;
  File? _selectedImage;
  bool _isProcessing = false;
  String? _statusText;

    @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
    _geminiService = widget.geminiService ?? GeminiService();
    _dbHelper = widget.dbHelper ?? DatabaseHelper.instance;
    _scannerService = widget.documentScannerService ?? DocumentScannerService();
    if (widget.initialSource != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickImage(widget.initialSource!);
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final pickedFiles = await _picker.pickMultiImage(imageQuality: 90);
        debugPrint('[ScanScreen] pickMultiImage returned ${pickedFiles.length} files');
        if (pickedFiles.isNotEmpty) {
          if (pickedFiles.length == 1) {
            setState(() {
              _selectedImage = File(pickedFiles.first.path);
            });
          } else {
            final queueProvider = Provider.of<ScanQueueProvider>(context, listen: false);
            final paths = pickedFiles.map((file) => file.path).toList();
            debugPrint('[ScanScreen] Enqueueing multiple paths: $paths');
            await queueProvider.enqueueMultiple(paths);
            debugPrint('[ScanScreen] Finished enqueueMultiple. Provider pendingCount: ${queueProvider.pendingCount}');
            if (!mounted) return;
            Navigator.pop(context); // Volver al inicio de forma silenciosa e inmediata
          }
        }
      } else {
        // Cámara física: Document Scanner de ML Kit con corrección de perspectiva y fallback a cámara estándar
        final scannedPaths = await _scannerService.scanDocuments();
        if (scannedPaths.isNotEmpty) {
          if (scannedPaths.length == 1) {
            setState(() {
              _selectedImage = File(scannedPaths.first);
            });
          } else {
            final queueProvider = Provider.of<ScanQueueProvider>(context, listen: false);
            await queueProvider.enqueueMultiple(scannedPaths);
            if (!mounted) return;
            Navigator.pop(context);
          }
        }
      }
    } catch (e, stack) {
      debugPrint('Error en _pickImage: $e\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al capturar imagen: ${e.toString()}')),
      );
    }
  }

  Future<void> _processWithGemini() async {
    if (_selectedImage == null || _isProcessing) return;

    final queueProvider = Provider.of<ScanQueueProvider>(context, listen: false);
    
    // Add to background queue
    await queueProvider.enqueue(_selectedImage!.path);
    HapticFeedback.mediumImpact();
    
    if (!mounted) return;
    
    Navigator.pop(context); // Volver al inicio
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Factura'),
      ),
      body: Padding(
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
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.contain,
            ),
          ),
        ),
        if (_isProcessing)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusText ?? 'Analizando factura...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCaptureOptions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('gallery_button'),
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Galería'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            key: const Key('camera_button'),
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
            onPressed: _isProcessing ? null : () => setState(() => _selectedImage = null),
            child: const Text('Reintentar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _processWithGemini,
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black87,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_isProcessing ? 'Analizando...' : 'Procesar con IA'),
          ),
        ),
      ],
    );
  }
}

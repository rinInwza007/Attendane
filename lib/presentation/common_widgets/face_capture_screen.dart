import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FaceCaptureScreen extends StatefulWidget {
  final Function(String imagePath)? onImageCaptured;
  final String? instructionText;

  const FaceCaptureScreen({
    Key? key,
    this.onImageCaptured,
    this.instructionText,
  }) : super(key: key);

  @override
  FaceCaptureScreenState createState() => FaceCaptureScreenState();
}

class FaceCaptureScreenState extends State<FaceCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  String? _imagePath;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize the camera
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        _showErrorSnackBar('No cameras available');
        return;
      }

      // Select front camera
      final frontCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      // Initialize controller
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      _showErrorSnackBar('Error initializing camera: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imageName =
          'face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(appDir.path, imageName);

      final XFile picture = await _controller!.takePicture();
      await picture.saveTo(filePath);

      setState(() {
        _imagePath = filePath;
        _isProcessing = false;
      });

      _showConfirmationDialog(filePath);
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      _showErrorSnackBar('Error taking picture: $e');
    }
  }

  void _showConfirmationDialog(String filePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Image'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(File(filePath)),
              const SizedBox(height: 16),
              const Text('Do you want to use this image?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retakePicture();
            },
            child: const Text('Retake'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onImageCaptured?.call(filePath);
              Navigator.of(context).pop();
              Navigator.of(context).pop(filePath);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _retakePicture() {
    setState(() {
      _imagePath = null;
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Capture'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Instructions
            if (widget.instructionText != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(child: Text(widget.instructionText!)),
                      ],
                    ),
                  ),
                ),
              ),

            // Camera Preview
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!_isCameraInitialized)
                    const Center(child: CircularProgressIndicator())
                  else if (_imagePath == null)
                    CameraPreview(_controller!)
                  else
                    Image.file(File(_imagePath!)),
                  if (_imagePath == null && _isCameraInitialized)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: FaceFramePainter(),
                      ),
                    ),
                  if (_isProcessing)
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),

            // Camera Controls
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.black12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_imagePath == null)
                    FloatingActionButton(
                      onPressed: _isProcessing ? null : _takePicture,
                      backgroundColor:
                          _isProcessing ? Colors.grey : Colors.blue,
                      child: const Icon(Icons.camera_alt),
                    )
                  else
                    FloatingActionButton(
                      onPressed: _retakePicture,
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.refresh),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for face frame
class FaceFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw frame for face positioning
    final rect = Rect.fromLTWH(
      size.width * 0.2,
      size.height * 0.2,
      size.width * 0.6,
      size.height * 0.6,
    );

    // Draw corner lines
    final cornerLength = size.width * 0.1;

    // Top left
    canvas.drawLine(
        rect.topLeft, rect.topLeft.translate(cornerLength, 0), paint);
    canvas.drawLine(
        rect.topLeft, rect.topLeft.translate(0, cornerLength), paint);

    // Top right
    canvas.drawLine(
        rect.topRight, rect.topRight.translate(-cornerLength, 0), paint);
    canvas.drawLine(
        rect.topRight, rect.topRight.translate(0, cornerLength), paint);

    // Bottom left
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft.translate(cornerLength, 0), paint);
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft.translate(0, -cornerLength), paint);

    // Bottom right
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight.translate(-cornerLength, 0), paint);
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight.translate(0, -cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

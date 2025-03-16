import 'dart:io';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'base_service.dart';

class FaceRecognitionException implements Exception {
  final String message;
  FaceRecognitionException(this.message);

  @override
  String toString() => 'FaceRecognitionException: $message';
}

class FaceRecognitionService extends BaseService {
  static final FaceRecognitionService _instance =
      FaceRecognitionService._internal();

  factory FaceRecognitionService() => _instance;

  FaceRecognitionService._internal();

  Interpreter? _interpreter;
  FaceDetector? _faceDetector;

  static const int MODEL_INPUT_SIZE = 112;
  static const int EMBEDDING_SIZE = 256;

  bool get isInitialized => _interpreter != null && _faceDetector != null;

  Future<void> initialize() async {
    return await handleError(() async {
      if (isInitialized) return;

      // Initialize face detector
      _faceDetector = GoogleMlKit.vision.faceDetector(
        FaceDetectorOptions(
          enableLandmarks: true,
          enableClassification: true,
          enableTracking: true,
          minFaceSize: 0.15,
        ),
      );

      // Initialize interpreter
      _interpreter = await Interpreter.fromAsset(
        'assets/face_net_model.tflite',
        options: InterpreterOptions()..threads = 4,
      );
    });
  }

  Future<List<double>> getFaceEmbedding(String imagePath) async {
    return await handleError(() async {
      // Ensure service is initialized
      if (!isInitialized) {
        await initialize();
      }

      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw FaceRecognitionException('Image file does not exist: $imagePath');
      }

      // Detect faces
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        throw FaceRecognitionException('No face detected in the image');
      }
      if (faces.length > 1) {
        throw FaceRecognitionException('Multiple faces detected in the image');
      }

      // Process image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw FaceRecognitionException('Failed to decode image');
      }

      // Resize and preprocess image
      final preprocessedImage = img.copyResize(
        image,
        width: MODEL_INPUT_SIZE,
        height: MODEL_INPUT_SIZE,
        interpolation: img.Interpolation.linear,
      );

      final inputArray = _preprocessImage(preprocessedImage);
      final outputArray =
          List.filled(1 * EMBEDDING_SIZE, 0.0).reshape([1, EMBEDDING_SIZE]);

      _interpreter!.run(inputArray, outputArray);

      // Normalize embedding vector
      final embedding = outputArray[0];
      final magnitude = _calculateMagnitude(embedding);
      return embedding.map((x) => x / magnitude).toList();
    });
  }

  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    return List.generate(
      1,
      (index) => List.generate(
        MODEL_INPUT_SIZE,
        (y) => List.generate(
          MODEL_INPUT_SIZE,
          (x) => List.generate(3, (c) {
            final pixel = image.getPixel(x, y);
            final value = c == 0
                ? img.getRed(pixel)
                : (c == 1 ? img.getGreen(pixel) : img.getBlue(pixel));
            // Normalize pixel values to [-1, 1]
            return value / 127.5 - 1.0;
          }),
        ),
      ),
    );
  }

  double _calculateMagnitude(List<double> vector) {
    double sumOfSquares = 0.0;
    for (var value in vector) {
      sumOfSquares += value * value;
    }
    return _sqrt(sumOfSquares);
  }

  double _sqrt(double x) {
    double z = x;
    for (int i = 0; i < 10; i++) {
      z = (z + x / z) / 2;
    }
    return z;
  }

  Future<void> dispose() async {
    _interpreter?.close();
    await _faceDetector?.close();
    _interpreter = null;
    _faceDetector = null;
  }
}

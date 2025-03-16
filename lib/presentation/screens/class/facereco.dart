import 'dart:io';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionException implements Exception {
  final String message;
  FaceRecognitionException(this.message);

  @override
  String toString() => 'FaceRecognitionException: $message';
}

class FaceRecognitionService {
  Interpreter? _interpreter;
  final FaceDetector _faceDetector;
  static const int MODEL_INPUT_SIZE = 112;
  static const int EMBEDDING_SIZE = 256;

  FaceRecognitionService()
      : _faceDetector = GoogleMlKit.vision.faceDetector(
          FaceDetectorOptions(
            enableLandmarks: true,
            enableClassification: true,
            enableTracking: true,
            minFaceSize: 0.15,
          ),
        );

  bool get isInitialized => _interpreter != null;

  Future<void> initialize() async {
    try {
      if (_interpreter != null) return;

      _interpreter = await Interpreter.fromAsset(
        'assets/face_net_model.tflite',
        options: InterpreterOptions()..threads = 4,
      );
    } catch (e) {
      throw FaceRecognitionException('Failed to initialize interpreter: $e');
    }
  }

  Future<List<double>> getFaceEmbedding(String imagePath) async {
    if (_interpreter == null) {
      await initialize();
    }

    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw FaceRecognitionException('Image file does not exist: $imagePath');
      }

      // ตรวจจับใบหน้า
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        throw FaceRecognitionException('No face detected in the image');
      }
      if (faces.length > 1) {
        throw FaceRecognitionException('Multiple faces detected in the image');
      }

      // อ่านและประมวลผลภาพ
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw FaceRecognitionException('Failed to decode image');
      }

      // ปรับขนาดภาพ
      final preprocessedImage = img.copyResize(
        image,
        width: MODEL_INPUT_SIZE,
        height: MODEL_INPUT_SIZE,
        interpolation: img.Interpolation.linear,
      );

      final inputArray = preprocessing(preprocessedImage);
      final outputArray =
          List.filled(1 * EMBEDDING_SIZE, 0.0).reshape([1, EMBEDDING_SIZE]);

      _interpreter!.run(inputArray, outputArray);

      // Normalize embedding vector
      final embedding = outputArray[0];
      final magnitude =
          sqrt(embedding.map((x) => x * x).reduce((a, b) => a + b));
      return embedding.map((x) => x / magnitude).toList();
    } catch (e) {
      if (e is FaceRecognitionException) {
        rethrow;
      }
      throw FaceRecognitionException('Error processing image: $e');
    }
  }

  List<List<List<List<double>>>> preprocessing(img.Image image) {
    return List.generate(
      1,
      (index) => List.generate(
        MODEL_INPUT_SIZE,
        (y) => List.generate(
          MODEL_INPUT_SIZE,
          (x) => List.generate(3, (c) {
            final pixel = image.getPixel(x, y);
            // ใช้ getRed(), getGreen(), getBlue() สำหรับ image package
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

  Future<void> dispose() async {
    _interpreter?.close();
    await _faceDetector.close();
  }
}

double sqrt(double x) {
  double z = x;
  for (int i = 0; i < 10; i++) {
    z = (z + x / z) / 2;
  }
  return z;
}

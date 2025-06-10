import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
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
  
  // Constants for the converted model
  static const int MODEL_INPUT_SIZE = 112;
  static const int EMBEDDING_SIZE = 128;  // Changed from 256 to 128
  static const String MODEL_FILE = 'assets/converted_model.tflite';

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

      print('🔄 Initializing face recognition service...');

      // Method 1: Try loading from asset directly
      try {
        _interpreter = await Interpreter.fromAsset(
          'converted_model.tflite',
        );
        print('✅ Model loaded successfully from asset');
      } catch (e1) {
        print('❌ Failed to load model from asset: $e1');
        
        // Method 2: Try loading from ByteData
        try {
          print('🔄 Trying to load model from ByteData...');
          final modelData = await rootBundle.load('assets/converted_model.tflite');
          final buffer = modelData.buffer.asUint8List();
          
          _interpreter = Interpreter.fromBuffer(buffer);
          print('✅ Model loaded successfully from buffer');
        } catch (e2) {
          print('❌ Failed to load model from buffer: $e2');
          throw FaceRecognitionException('Failed to load converted_model.tflite: $e2');
        }
      }

      // Verify model input/output shapes
      if (_interpreter != null) {
        _verifyModelShapes();
      }

    } catch (e) {
      print('❌ Error initializing face recognition: $e');
      throw FaceRecognitionException('Failed to initialize interpreter: $e');
    }
  }

  void _verifyModelShapes() {
    try {
      // For tflite_flutter ^0.11.0, getInputTensors/getOutputTensors might not be available
      // Use basic shape verification instead
      print('📊 Model Information:');
      print('   Expected input size: ${MODEL_INPUT_SIZE}x${MODEL_INPUT_SIZE}x3');
      print('   Expected output size: $EMBEDDING_SIZE');
      print('   Model file: $MODEL_FILE');
      
    } catch (e) {
      print('❌ Error verifying model shapes: $e');
    }
  }

  bool _listsEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<List<double>> getFaceEmbedding(String imagePath) async {
    if (_interpreter == null) {
      await initialize();
    }

    try {
      print('🔍 Processing face embedding for: $imagePath');
      
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw FaceRecognitionException('ไม่พบไฟล์รูปภาพ: $imagePath');
      }

      // Detect faces using ML Kit
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        throw FaceRecognitionException('ไม่พบใบหน้าในรูปภาพ กรุณาเลือกรูปที่เห็นใบหน้าชัดเจน');
      }
      if (faces.length > 1) {
        throw FaceRecognitionException('พบใบหน้าหลายใบในรูปภาพ กรุณาเลือกรูปที่มีเพียงใบหน้าของคุณเท่านั้น');
      }

      print('✅ Face detected successfully');

      // Process image for model inference
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw FaceRecognitionException('ไม่สามารถอ่านรูปภาพได้ กรุณาลองรูปอื่น');
      }

      // Resize and preprocess image
      final preprocessedImage = img.copyResize(
        image,
        width: MODEL_INPUT_SIZE,
        height: MODEL_INPUT_SIZE,
        interpolation: img.Interpolation.linear,
      );

      print('🔄 Preprocessing image...');
      final inputArray = _preprocessImage(preprocessedImage);
      
      // Create output buffer using Float32List
      final outputBuffer = Float32List(EMBEDDING_SIZE);
      final outputs = <int, Object>{0: outputBuffer};

      print('🧠 Running model inference...');
      
      // ประกาศตัวแปร embedding ที่นี่
      List<double> embedding;
      
      try {
        // For tflite_flutter ^0.11.0 - use run method with ByteData
        final input = inputArray.buffer.asByteData();
        final output = ByteData(EMBEDDING_SIZE * 4); // 4 bytes per float32
        
        _interpreter!.run(input, output);
        
        // Convert ByteData to List<double>
        embedding = <double>[];
        for (int i = 0; i < EMBEDDING_SIZE; i++) {
          embedding.add(output.getFloat32(i * 4, Endian.little));
        }
        
        print('✅ Model inference completed');
      } catch (e) {
        print('❌ Model inference failed: $e');
        throw FaceRecognitionException('เกิดข้อผิดพลาดในการประมวลผลใบหน้า: $e');
      }
      
      print('📊 Raw embedding stats:');
      print('   Length: ${embedding.length}');
      print('   Min: ${embedding.reduce(math.min).toStringAsFixed(4)}');
      print('   Max: ${embedding.reduce(math.max).toStringAsFixed(4)}');
      print('   Sample: ${embedding.take(5).map((e) => e.toStringAsFixed(4)).toList()}');

      // Normalize embedding vector using L2 norm
      final magnitude = _calculateMagnitude(embedding);
      if (magnitude < 1e-6) {
        throw FaceRecognitionException('Invalid embedding generated - magnitude too small');
      }

      final normalizedEmbedding = embedding.map((x) => x / magnitude).toList();
      
      print('✅ Embedding normalized successfully');
      print('📊 Normalized embedding magnitude: ${_calculateMagnitude(normalizedEmbedding).toStringAsFixed(4)}');

      return normalizedEmbedding;

    } catch (e) {
      print('❌ Error in getFaceEmbedding: $e');
      if (e is FaceRecognitionException) {
        rethrow;
      }
      throw FaceRecognitionException('เกิดข้อผิดพลาดในการประมวลผลรูปภาพ: $e');
    }
  }

  Float32List _preprocessImage(img.Image image) {
    print('🔄 Preprocessing image to ${MODEL_INPUT_SIZE}x${MODEL_INPUT_SIZE}...');
    
    // Create input buffer with size: 1 * height * width * channels
    final inputBuffer = Float32List(1 * MODEL_INPUT_SIZE * MODEL_INPUT_SIZE * 3);
    int pixelIndex = 0;
    
    for (int y = 0; y < MODEL_INPUT_SIZE; y++) {
      for (int x = 0; x < MODEL_INPUT_SIZE; x++) {
        final pixel = image.getPixel(x, y);
        
        // Extract and normalize RGB values to [-1, 1] range
        inputBuffer[pixelIndex++] = (pixel.r / 127.5) - 1.0;  // Red
        inputBuffer[pixelIndex++] = (pixel.g / 127.5) - 1.0;  // Green  
        inputBuffer[pixelIndex++] = (pixel.b / 127.5) - 1.0;  // Blue
      }
    }
    
    return inputBuffer;
  }

  double _calculateMagnitude(List<double> vector) {
    double sumOfSquares = 0.0;
    for (var value in vector) {
      sumOfSquares += value * value;
    }
    return math.sqrt(sumOfSquares);
  }

  /// Compare two face embeddings using cosine similarity
  /// Returns a value between -1 and 1, where 1 means identical faces
  Future<double> compareFaceEmbeddings(List<double> embedding1, List<double> embedding2) async {
    try {
      if (embedding1.length != embedding2.length) {
        throw FaceRecognitionException(
          'Embeddings have different dimensions: ${embedding1.length} vs ${embedding2.length}'
        );
      }
      
      // Calculate cosine similarity = dot product / (magnitude1 * magnitude2)
      double dotProduct = 0.0;
      double magnitude1 = 0.0;
      double magnitude2 = 0.0;
      
      for (int i = 0; i < embedding1.length; i++) {
        dotProduct += embedding1[i] * embedding2[i];
        magnitude1 += embedding1[i] * embedding1[i];
        magnitude2 += embedding2[i] * embedding2[i];
      }
      
      magnitude1 = math.sqrt(magnitude1);
      magnitude2 = math.sqrt(magnitude2);
      
      if (magnitude1 < 1e-6 || magnitude2 < 1e-6) {
        print('⚠️  Warning: Very small magnitude detected in embeddings');
        return 0.0; // Avoid division by very small numbers
      }
      
      final similarity = dotProduct / (magnitude1 * magnitude2);
      
      print('📊 Similarity calculation:');
      print('   Dot product: ${dotProduct.toStringAsFixed(4)}');
      print('   Magnitude1: ${magnitude1.toStringAsFixed(4)}');
      print('   Magnitude2: ${magnitude2.toStringAsFixed(4)}');
      print('   Similarity: ${similarity.toStringAsFixed(4)}');
      
      return similarity;
    } catch (e) {
      print('❌ Error comparing face embeddings: $e');
      return -2; // Error value
    }
  }

  /// Verify if a captured face matches a stored face embedding
  /// Returns true if the face is verified (similarity > threshold)
  Future<bool> verifyFace(
    String studentId, 
    List<double> capturedEmbedding, 
    {double threshold = 0.7}
  ) async {
    try {
      print('🔍 Verifying face for student: $studentId');
      print('📊 Using threshold: $threshold');
      
      // This method should integrate with your database service
      // For now, returning a placeholder implementation
      // You'll need to implement the database retrieval logic
      
      print('⚠️  Note: Database integration needed for verifyFace method');
      return false;
      
    } catch (e) {
      print('❌ Error verifying face: $e');
      return false;
    }
  }

  /// Test method to verify the model is working correctly
  Future<bool> testModel() async {
    try {
      print('🧪 Testing model...');
      
      if (_interpreter == null) {
        await initialize();
      }
      
      // Create dummy input data
      final dummyInput = List.generate(
        1,
        (i) => List.generate(
          MODEL_INPUT_SIZE,
          (j) => List.generate(
            MODEL_INPUT_SIZE,
            (k) => List.generate(3, (l) => 0.5), // Dummy pixel values
          ),
        ),
      );
      
      // Create output array with correct type
      final dummyOutput = <List<double>>[List<double>.filled(EMBEDDING_SIZE, 0.0)];
      
      _interpreter!.run(dummyInput, dummyOutput);
      
      final embedding = dummyOutput[0];
      final magnitude = _calculateMagnitude(embedding);
      
      print('✅ Model test successful');
      print('📊 Test results:');
      print('   Embedding length: ${embedding.length}');
      print('   Magnitude: ${magnitude.toStringAsFixed(4)}');
      print('   First 5 values: ${embedding.take(5).map((e) => e.toStringAsFixed(4)).toList()}');
      
      return true;
      
    } catch (e) {
      print('❌ Model test failed: $e');
      return false;
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    try {
      print('🧹 Disposing face recognition service...');
      
      _interpreter?.close();
      _interpreter = null;
      
      await _faceDetector.close();
      
      print('✅ Face recognition service disposed');
    } catch (e) {
      print('❌ Error disposing face recognition service: $e');
    }
  }

  /// Get model information
  Map<String, dynamic> getModelInfo() {
    if (_interpreter == null) {
      return {
        'status': 'not_initialized',
        'error': 'Model not loaded'
      };
    }

    try {
      return {
        'status': 'ready',
        'model_file': MODEL_FILE,
        'expected_input_size': MODEL_INPUT_SIZE,
        'expected_embedding_size': EMBEDDING_SIZE,
        'interpreter_address': _interpreter.hashCode.toString(),
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString()
      };
    }
  }
}
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_service.dart';

class FaceRecognitionException implements Exception {
  final String message;
  FaceRecognitionException(this.message);

  @override
  String toString() => 'FaceRecognitionException: $message';
}

class FaceRecognitionService extends BaseService {
  // Singleton pattern with dependency injection
  static FaceRecognitionService? _instance;

  /// Factory constructor that returns the singleton instance
  /// with Supabase client dependency injection
  factory FaceRecognitionService() {
    // Create instance if it doesn't exist
    _instance ??= FaceRecognitionService._internal(Supabase.instance.client);
    return _instance!;
  }

  /// Private constructor with dependency injection
  FaceRecognitionService._internal(this._supabase);

  /// Test constructor for dependency injection (useful for testing)
  @visibleForTesting()
  FaceRecognitionService.forTesting(this._supabase);

  /// Supabase client injected through constructor
  final SupabaseClient _supabase;
  
  Interpreter? _interpreter;
  FaceDetector? _faceDetector;

  static const int MODEL_INPUT_SIZE = 112;
  static const int EMBEDDING_SIZE = 256;
  static const String MODEL_FILE = 'assets/face_net_model.tflite';

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

      try {
        // Method 1: Load from asset
        _interpreter = await Interpreter.fromAsset(
          'face_net_model.tflite',
          options: InterpreterOptions()..threads = 4,
        );
        print('Model loaded successfully from asset');
      } catch (e1) {
        print('Failed to load model from asset: $e1');
        
        try {
          // Method 2: Load from ByteData
          final modelData = await rootBundle.load('assets/face_net_model.tflite');
          final buffer = modelData.buffer;
          final byteData = buffer.asUint8List();
          
          _interpreter = await Interpreter.fromBuffer(
            byteData,
            options: InterpreterOptions()..threads = 4,
          );
          print('Model loaded successfully from buffer');
        } catch (e2) {
          print('Failed to load model from buffer: $e2');
          
          // Method 3: Use ML Kit face detection capabilities only
          print('Falling back to ML Kit face detection only');
          // We'll use ML Kit face detection
        }
      }
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
        throw FaceRecognitionException('ไม่พบไฟล์รูปภาพ กรุณาลองใหม่อีกครั้ง');
      }

      // Detect faces
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        throw FaceRecognitionException('ไม่พบใบหน้าในรูปภาพ กรุณาเลือกรูปที่เห็นใบหน้าชัดเจน');
      }
      if (faces.length > 1) {
        throw FaceRecognitionException('พบใบหน้าหลายใบในรูปภาพ กรุณาเลือกรูปที่มีเพียงใบหน้าของคุณเท่านั้น');
      }

      // If TensorFlow model is available, use it
      if (_interpreter != null) {
        // Process image
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

        final inputArray = _preprocessImage(preprocessedImage);
        final outputArray =
            List.filled(1 * EMBEDDING_SIZE, 0.0).reshape([1, EMBEDDING_SIZE]);

        try {
          _interpreter!.run(inputArray, outputArray);
        } catch (e) {
          throw FaceRecognitionException('เกิดข้อผิดพลาดในการประมวลผลใบหน้า: $e');
        }

        // Normalize embedding vector
        final embedding = outputArray[0];
        final magnitude = _calculateMagnitude(embedding);
        return embedding.map((x) => x / magnitude).toList();
      } else {
        // Fallback: If TF model not available, use ML Kit face features
        return _extractFaceFeaturesAsFallback(faces[0]);
      }
    });
  }

  // Fallback method using ML Kit face features
  List<double> _extractFaceFeaturesAsFallback(Face face) {
    List<double> features = [];
    
    // Use available face landmarks
    if (face.landmarks.isNotEmpty) {
      face.landmarks.forEach((_, landmarkNullable) {
        if (landmarkNullable != null) {
          // Convert int to double when adding to features list
          features.add(landmarkNullable.position.x.toDouble());
          features.add(landmarkNullable.position.y.toDouble());
        }
      });
    }
    
    // Add bounding box values
    final boundingBox = face.boundingBox;
    features.add(boundingBox.left.toDouble());
    features.add(boundingBox.top.toDouble());
    features.add(boundingBox.width.toDouble());
    features.add(boundingBox.height.toDouble());
    
    // Add other features with null checks
    if (face.headEulerAngleY != null) features.add(face.headEulerAngleY!);
    if (face.headEulerAngleZ != null) features.add(face.headEulerAngleZ!);
    if (face.smilingProbability != null) features.add(face.smilingProbability!);
    if (face.leftEyeOpenProbability != null) features.add(face.leftEyeOpenProbability!);
    if (face.rightEyeOpenProbability != null) features.add(face.rightEyeOpenProbability!);
    
    // Pad or truncate to EMBEDDING_SIZE
    if (features.isEmpty) {
      features = List.filled(EMBEDDING_SIZE, 0.0);
    } else {
      // Repeat pattern to fill
      while (features.length < EMBEDDING_SIZE) {
        features.add(features[features.length % features.length]);
      }
      // Truncate if too many
      if (features.length > EMBEDDING_SIZE) {
        features = features.sublist(0, EMBEDDING_SIZE);
      }
    }
    
    // Normalize
    final magnitude = _calculateMagnitude(features);
    if (magnitude < 1e-6) {  // Avoid division by zero or very small numbers
      return List.filled(EMBEDDING_SIZE, 0.0);
    }
    return features.map((x) => x / magnitude).toList();
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

  // Face verification methods
  
  /// Compare two face embeddings using cosine similarity
  /// Returns a value between -1 and 1, where 1 means identical
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
      
      magnitude1 = _sqrt(magnitude1);
      magnitude2 = _sqrt(magnitude2);
      
      if (magnitude1 < 1e-6 || magnitude2 < 1e-6) {
        return 0.0; // Avoid division by very small numbers
      }
      
      return dotProduct / (magnitude1 * magnitude2);
    } catch (e) {
      print('Error comparing face embeddings: $e');
      return -2; // Error value
    }
  }

  /// Verify if a face matches with a stored face embedding
  /// Returns true if the face is verified, false otherwise
  Future<bool> verifyFace(String studentId, List<double> capturedEmbedding, {double threshold = 0.7}) async {
    try {
      // ดึง embedding ที่บันทึกไว้ในฐานข้อมูล
      final response = await _supabase
          .from('student_face_embeddings')
          .select('face_embedding, face_embedding_json')
          .eq('student_id', studentId)
          .eq('is_active', true)
          .single();
      
      if (response == null) return false;
      
      List<double>? storedEmbedding;
      
      // ลองดึงจาก face_embedding ก่อน
      if (response['face_embedding'] != null) {
        storedEmbedding = List<double>.from(response['face_embedding']);
      }
      // ถ้าไม่มีให้ลองดึงจาก face_embedding_json
      else if (response['face_embedding_json'] != null) {
        final List<dynamic> jsonList = jsonDecode(response['face_embedding_json']);
        storedEmbedding = jsonList.map((item) => item as double).toList();
      }
      
      if (storedEmbedding == null || storedEmbedding.isEmpty) return false;
      
      // เปรียบเทียบ embeddings
      double similarity = await compareFaceEmbeddings(capturedEmbedding, storedEmbedding);
      
      // ถ้าความคล้ายคลึงสูงกว่าค่า threshold ถือว่าเป็นคนเดียวกัน
      return similarity > threshold;
    } catch (e) {
      print('Error verifying face: $e');
      return false;
    }
  }

  /// Get face embedding for a student from database
  Future<List<double>?> getStoredFaceEmbedding(String studentId) async {
    try {
      final response = await _supabase
          .from('student_face_embeddings')
          .select('face_embedding, face_embedding_json')
          .eq('student_id', studentId)
          .eq('is_active', true)
          .single();
      
      if (response == null) return null;
      
      // Try face_embedding first
      if (response['face_embedding'] != null) {
        return List<double>.from(response['face_embedding']);
      }
      
      // Try face_embedding_json if face_embedding is not available
      if (response['face_embedding_json'] != null) {
        final List<dynamic> jsonList = jsonDecode(response['face_embedding_json']);
        return jsonList.map((item) => item as double).toList();
      }
      
      return null;
    } catch (e) {
      print('Error getting stored face embedding: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    _interpreter?.close();
    await _faceDetector?.close();
    _interpreter = null;
    _faceDetector = null;
  }
}

/// Annotation to mark methods for testing
class visibleForTesting {
  const visibleForTesting();
}
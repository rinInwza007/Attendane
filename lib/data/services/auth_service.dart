// lib/data/services/face_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myproject2/data/services/auth_service.dart';

class FaceService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // ==================== Face Embedding Management ====================
  
  Future<bool> hasFaceEmbedding() async {
    try {
      final userEmail = _authService.getCurrentUserEmail();
      if (userEmail == null) return false;

      final schoolId = await _getSchoolId(userEmail);
      if (schoolId == null) return false;

      final response = await _supabase
          .from('student_face_embeddings')
          .select('id, face_quality, created_at')
          .eq('student_id', schoolId)
          .eq('is_active', true)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking face embedding: $e');
      return false;
    }
  }

  Future<void> saveFaceEmbedding(List<double> embedding) async {
    try {
      _validateEmbedding(embedding);
      
      final userEmail = _authService.getCurrentUserEmail();
      if (userEmail == null) {
        throw FaceServiceException('No authenticated user');
      }

      final schoolId = await _getSchoolId(userEmail);
      if (schoolId == null) {
        throw FaceServiceException('School ID not found');
      }

      final embeddingJson = jsonEncode(embedding);
      final quality = _calculateEmbeddingQuality(embedding);
      final timestamp = DateTime.now().toIso8601String();

      // Check if embedding already exists
      final existing = await _getExistingEmbedding(schoolId);

      if (existing != null) {
        await _updateEmbedding(schoolId, embeddingJson, quality, timestamp);
      } else {
        await _insertEmbedding(schoolId, embeddingJson, quality, timestamp);
      }

      // Verify save was successful
      await _verifyEmbeddingSaved(schoolId);
      
    } catch (e) {
      throw FaceServiceException(_getFriendlyErrorMessage(e.toString()));
    }
  }

  Future<void> deactivateFaceEmbedding() async {
    try {
      final userEmail = _authService.getCurrentUserEmail();
      if (userEmail == null) {
        throw FaceServiceException('No authenticated user');
      }

      final schoolId = await _getSchoolId(userEmail);
      if (schoolId == null) {
        throw FaceServiceException('School ID not found');
      }

      await _supabase
          .from('student_face_embeddings')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('student_id', schoolId);
          
    } catch (e) {
      throw FaceServiceException('Failed to deactivate face embedding: $e');
    }
  }

  Future<Map<String, dynamic>?> getFaceEmbeddingDetails() async {
    try {
      final userEmail = _authService.getCurrentUserEmail();
      if (userEmail == null) return null;

      final schoolId = await _getSchoolId(userEmail);
      if (schoolId == null) return null;

      return await _supabase
          .from('student_face_embeddings')
          .select('id, face_quality, created_at, updated_at')
          .eq('student_id', schoolId)
          .eq('is_active', true)
          .maybeSingle();
    } catch (e) {
      print('Error getting face embedding details: $e');
      return null;
    }
  }

  Future<List<double>?> getFaceEmbedding() async {
    try {
      final userEmail = _authService.getCurrentUserEmail();
      if (userEmail == null) return null;

      final schoolId = await _getSchoolId(userEmail);
      if (schoolId == null) return null;

      final response = await _supabase
          .from('student_face_embeddings')
          .select('face_embedding_json')
          .eq('student_id', schoolId)
          .eq('is_active', true)
          .maybeSingle();
      
      if (response?['face_embedding_json'] != null) {
        final List<dynamic> jsonList = jsonDecode(response['face_embedding_json']);
        final embedding = jsonList.map((item) => item as double).toList();
        
        if (embedding.length != 128) {
          print('Warning: Invalid embedding size: ${embedding.length}');
          return null;
        }
        
        return embedding;
      }
      
      return null;
    } catch (e) {
      print('Error fetching face embedding: $e');
      return null;
    }
  }

  // ==================== Face Verification ====================
  
  Future<bool> verifyFace(String studentId, List<double> capturedEmbedding, {double threshold = 0.7}) async {
    try {
      final storedEmbedding = await _getStoredEmbedding(studentId);
      if (storedEmbedding == null) return false;
      
      if (storedEmbedding.length != capturedEmbedding.length) {
        print('Embedding size mismatch: ${storedEmbedding.length} vs ${capturedEmbedding.length}');
        return false;
      }
      
      final similarity = _compareFaceEmbeddings(capturedEmbedding, storedEmbedding);
      
      if (similarity == -2.0) {
        print('Error in similarity calculation');
        return false;
      }
      
      final isVerified = similarity > threshold;
      print('Face verification: ${isVerified ? "PASSED" : "FAILED"} (similarity: ${similarity.toStringAsFixed(4)})');
      
      return isVerified;
    } catch (e) {
      print('Error verifying face: $e');
      return false;
    }
  }

  double _compareFaceEmbeddings(List<double> embedding1, List<double> embedding2) {
    try {
      if (embedding1.length != embedding2.length) {
        throw Exception('Embeddings have different dimensions');
      }
      
      // Validate embeddings
      for (int i = 0; i < embedding1.length; i++) {
        if (!embedding1[i].isFinite || !embedding2[i].isFinite) {
          throw Exception('Invalid embedding values detected');
        }
      }
      
      double dotProduct = 0.0;
      for (int i = 0; i < embedding1.length; i++) {
        dotProduct += embedding1[i] * embedding2[i];
      }
      
      // For normalized embeddings, cosine similarity = dot product
      return dotProduct.clamp(-1.0, 1.0);
    } catch (e) {
      print('Error comparing face embeddings: $e');
      return -2.0; // Error value
    }
  }

  // ==================== Private Helper Methods ====================
  
  Future<String?> _getSchoolId(String userEmail) async {
    final userResponse = await _supabase
        .from('users')
        .select('school_id')
        .eq('email', userEmail)
        .maybeSingle();

    final schoolId = userResponse?['school_id']?.toString();
    return (schoolId?.isNotEmpty == true) ? schoolId : null;
  }

  Future<Map<String, dynamic>?> _getExistingEmbedding(String schoolId) async {
    return await _supabase
        .from('student_face_embeddings')
        .select('id, student_id, is_active, created_at')
        .eq('student_id', schoolId)
        .maybeSingle();
  }

  Future<List<double>?> _getStoredEmbedding(String studentId) async {
    final response = await _supabase
        .from('student_face_embeddings')
        .select('face_embedding_json')
        .eq('student_id', studentId)
        .eq('is_active', true)
        .maybeSingle();
    
    if (response?['face_embedding_json'] == null) return null;
    
    final List<dynamic> jsonList = jsonDecode(response ['face_embedding_json']);
    return jsonList.map((item) => item as double).toList();
  }

  Future<void> _updateEmbedding(String schoolId, String embeddingJson, double quality, String timestamp) async {
    final updateData = {
      'face_embedding_json': embeddingJson,
      'face_quality': quality,
      'is_active': true,
      'updated_at': timestamp,
    };

    await _supabase
        .from('student_face_embeddings')
        .update(updateData)
        .eq('student_id', schoolId);
  }

  Future<void> _insertEmbedding(String schoolId, String embeddingJson, double quality, String timestamp) async {
    final insertData = {
      'student_id': schoolId,
      'face_embedding_json': embeddingJson,
      'face_quality': quality,
      'is_active': true,
      'created_at': timestamp,
      'updated_at': timestamp,
    };

    await _supabase
        .from('student_face_embeddings')
        .insert(insertData);
  }

  Future<void> _verifyEmbeddingSaved(String schoolId) async {
    final finalCheck = await _supabase
        .from('student_face_embeddings')
        .select('id, student_id, face_quality, is_active')
        .eq('student_id', schoolId)
        .eq('is_active', true)
        .maybeSingle();

    if (finalCheck == null) {
      throw Exception('Failed to verify saved face embedding');
    }
  }

  void _validateEmbedding(List<double> embedding) {
    if (embedding.isEmpty) {
      throw Exception('Empty embedding provided');
    }
    
    if (embedding.length != 128) {
      throw Exception('Invalid embedding size: ${embedding.length}, expected: 128');
    }

    // Check for invalid values
    for (int i = 0; i < embedding.length; i++) {
      if (!embedding[i].isFinite) {
        throw Exception('Invalid embedding values detected at index $i');
      }
    }
  }

  double _calculateEmbeddingQuality(List<double> embedding) {
    try {
      double sum = 0.0;
      double sumSquares = 0.0;
      double minVal = embedding[0];
      double maxVal = embedding[0];
      
      for (var value in embedding) {
        sum += value;
        sumSquares += value * value;
        if (value < minVal) minVal = value;
        if (value > maxVal) maxVal = value;
      }
      
      final mean = sum / embedding.length;
      final variance = (sumSquares / embedding.length) - (mean * mean);
      final stdDev = math.sqrt(variance);
      final range = maxVal - minVal;
      
      // Quality score based on distribution and range
      double quality = 0.5; // Base quality
      
      // Good standard deviation indicates good feature distribution
      if (stdDev > 0.1 && stdDev < 1.0) {
        quality += 0.2;
      }
      
      // Good range indicates good feature separation
      if (range > 0.5 && range < 3.0) {
        quality += 0.2;
      }
      
      // Penalize if mean is too far from 0 (should be normalized)
      if (mean.abs() < 0.1) {
        quality += 0.1;
      }
      
      return quality.clamp(0.0, 1.0);
    } catch (e) {
      print('Warning: Failed to calculate embedding quality: $e');
      return 0.5; // Default quality
    }
  }

  String _getFriendlyErrorMessage(String error) {
    if (error.contains('No authenticated user')) {
      return 'กรุณาเข้าสู่ระบบใหม่';
    } else if (error.contains('School ID not found')) {
      return 'ไม่พบข้อมูลรหัสนักเรียน กรุณาติดต่อผู้ดูแลระบบ';
    } else if (error.contains('Invalid embedding')) {
      return 'ข้อมูลใบหน้าไม่ถูกต้อง กรุณาลองถ่ายรูปใหม่';
    } else if (error.contains('connection') || error.contains('network')) {
      return 'ปัญหาการเชื่อมต่อ กรุณาตรวจสอบอินเทอร์เน็ต';
    }
    return 'ไม่สามารถบันทึกข้อมูลใบหน้าได้: $error';
  }
}

// ==================== Custom Exception ====================

class FaceServiceException implements Exception {
  final String message;
  
  FaceServiceException(this.message);
  
  @override
  String toString() => 'FaceServiceException: $message';
}
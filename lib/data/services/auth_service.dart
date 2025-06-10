// lib/data/services/auth_service.dart

import 'dart:math';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // เพิ่มเพื่อให้เข้าถึง _supabase ได้จากภายนอก
  SupabaseClient get supabase => _supabase;

  // Authentication functions
  Future<AuthResponse> signInWithEmailPassword(String email, String password) async {
    try {
      return await _supabase.auth.signInWithPassword(password: password, email: email);
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  Future<AuthResponse> signUpWithEmailPassword(String email, String password) async {
    try {
      return await _supabase.auth.signUp(password: password, email: email);
    } catch (e) {
      print('Error signing up: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  String? getCurrentUserEmail() {
    return _supabase.auth.currentSession?.user.email;
  }

  String? getCurrentUserId() {
    return _supabase.auth.currentSession?.user.id;
  }

  // User profile functions
  Future<Map<String, dynamic>?> getUserProfile() async {
    final email = getCurrentUserEmail();
    if (email == null) {
      print('🔍 getUserProfile: No current user email');
      return null;
    }

    print('🔍 getUserProfile: Getting profile for $email');

    try {
      final response = await _supabase
          .from('users')
          .select('*')
          .eq('email', email)
          .maybeSingle();
      
      print('🔍 getUserProfile: Raw response: $response');
      
      if (response == null) {
        print('❌ getUserProfile: No user found');
        return null;
      }
      
      // เพิ่มข้อมูล has_face_data
      final hasFace = await hasFaceEmbedding();
      final userData = {...response, 'has_face_data': hasFace};
      
      print('✅ getUserProfile: Final data: $userData');
      return userData;
      
    } catch (e) {
      print('❌ getUserProfile error: $e');
      return null;
    }
  }

  Future<bool> checkUserProfileExists() async {
    final email = getCurrentUserEmail();
    if (email == null) return false;

    try {
      final response = await _supabase.from('users').select().eq('email', email).single();
      return response != null;
    } catch (e) {
      print('Error checking profile: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> checkUserProfile() async {
    final email = getCurrentUserEmail();
    if (email == null) {
      return {'exists': false, 'userType': null};
    }

    try {
      final response = await _supabase
          .from('users')
          .select('user_type')
          .eq('email', email)
          .single();

      return {
        'exists': response != null,
        'userType': response['user_type'],
      };
    } catch (e) {
      return {'exists': false, 'userType': null};
    }
  }

  Future<void> saveUserProfile({
    required String fullName,
    required String schoolId,
    required String userType,
  }) async {
    final email = getCurrentUserEmail();
    if (email == null) throw Exception('No authenticated user');

    print('Saving user profile - Email: $email, SchoolId: $schoolId');

    try {
      final response = await _supabase.from('users').upsert({
        'email': email,
        'full_name': fullName,
        'school_id': schoolId,
        'user_type': userType,
        'is_active': true,
      }, onConflict: 'email');

      print('User profile saved successfully');
      
      // ตรวจสอบว่าข้อมูลถูกบันทึกจริง
      final savedData = await _supabase
          .from('users')
          .select('*')
          .eq('email', email)
          .maybeSingle();
      
      print('Verified saved data: $savedData');
      
    } catch (e) {
      print('Error saving user profile: $e');
      throw Exception('Failed to save user profile: $e');
    }
  }

  Future<String?> getUserType() async {
    final email = getCurrentUserEmail();
    if (email == null) return null;

    try {
      final response = await _supabase
          .from('users')
          .select('user_type')
          .eq('email', email)
          .single();
      return response?['user_type'];
    } catch (e) {
      return null;
    }
  }

  // Face recognition functions - แก้ไขให้ใช้ school_id
  Future<bool> hasFaceEmbedding() async {
    try {
      final email = getCurrentUserEmail();
      if (email == null) {
        print('🔍 hasFaceEmbedding: No current user email');
        return false;
      }

      print('🔍 hasFaceEmbedding: Checking for email: $email');

      // ดึง school_id จาก users table
      final userResponse = await _supabase
          .from('users')
          .select('school_id')
          .eq('email', email)
          .maybeSingle();

      if (userResponse == null) {
        print('❌ hasFaceEmbedding: User not found');
        return false;
      }
      
      final schoolId = userResponse['school_id'];
      if (schoolId == null || schoolId.toString().isEmpty) {
        print('❌ hasFaceEmbedding: School ID is empty');
        return false;
      }

      print('🎓 hasFaceEmbedding: Checking school_id: $schoolId');

      // ตรวจสอบใน student_face_embeddings table โดยใช้ school_id
      final response = await _supabase
          .from('student_face_embeddings')
          .select('id, face_quality, created_at')
          .eq('student_id', schoolId.toString())
          .eq('is_active', true)
          .maybeSingle();

      final hasFace = response != null;
      print('✅ hasFaceEmbedding result: $hasFace');
      
      if (hasFace) {
        print('📊 Face data: quality=${response['face_quality']}, created=${response['created_at']}');
      }

      return hasFace;
    } catch (e) {
      print('❌ Error checking face embedding: $e');
      return false;
    }
  }

  Future<void> saveFaceEmbedding(List<double> embedding) async {
    try {
      final email = getCurrentUserEmail();
      if (email == null) {
        throw Exception('No authenticated user');
      }

      print('🔍 Step 1: Current user email: $email');

      // Validate embedding
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

      print('✅ Step 1.5: Embedding validation passed');

      // ดึงข้อมูล user จาก database
      final userResponse = await _supabase
          .from('users')
          .select('email, school_id, full_name, user_type')
          .eq('email', email)
          .maybeSingle();

      if (userResponse == null) {
        throw Exception('User not found in database: $email');
      }

      print('📋 Step 2: User data from DB: $userResponse');

      final schoolId = userResponse['school_id'];
      if (schoolId == null || schoolId.toString().isEmpty) {
        throw Exception('School ID is null or empty for user: $email');
      }

      final schoolIdString = schoolId.toString().trim();
      print('🎓 Step 3: Using school_id: "$schoolIdString" (type: ${schoolId.runtimeType})');

      // ตรวจสอบว่า school_id นี้มีอยู่จริงในฐานข้อมูล
      final schoolIdCheck = await _supabase
          .from('users')
          .select('school_id')
          .eq('school_id', schoolIdString)
          .maybeSingle();

      if (schoolIdCheck == null) {
        print('❌ School ID verification failed');
        throw Exception('School ID "$schoolIdString" not found in users table');
      }

      print('✅ Step 4: School ID verified in database');

      // ตรวจสอบข้อมูลเดิมใน student_face_embeddings
      final existing = await _supabase
          .from('student_face_embeddings')
          .select('id, student_id, is_active, created_at')
          .eq('student_id', schoolIdString)
          .maybeSingle();

      print('📋 Step 5: Existing face data check: $existing');

      // Prepare embedding data
      final embeddingJson = jsonEncode(embedding);
      final quality = _calculateEmbeddingQuality(embedding);
      final timestamp = DateTime.now().toIso8601String();

      print('📊 Step 6: Embedding quality calculated: ${quality.toStringAsFixed(3)}');

      if (existing != null) {
        print('📝 Step 7: Updating existing record...');
        
        final updateData = {
          'face_embedding_json': embeddingJson,
          'face_quality': quality,
          'is_active': true,
          'updated_at': timestamp,
        };

        print('📤 Update data prepared (size: ${embeddingJson.length} chars)');

        final updateResult = await _supabase
            .from('student_face_embeddings')
            .update(updateData)
            .eq('student_id', schoolIdString)
            .select();
        
        print('✅ Successfully updated face embedding: $updateResult');
      } else {
        print('➕ Step 7: Inserting new record...');
        
        final insertData = {
          'student_id': schoolIdString,
          'face_embedding_json': embeddingJson,
          'face_quality': quality,
          'is_active': true,
          'created_at': timestamp,
          'updated_at': timestamp,
        };

        print('📤 Insert data prepared (size: ${embeddingJson.length} chars)');

        final insertResult = await _supabase
            .from('student_face_embeddings')
            .insert(insertData)
            .select();
        
        print('✅ Successfully inserted face embedding: $insertResult');
      }

      // ตรวจสอบผลลัพธ์สุดท้าย
      final finalCheck = await _supabase
          .from('student_face_embeddings')
          .select('id, student_id, face_quality, is_active, created_at, updated_at')
          .eq('student_id', schoolIdString)
          .eq('is_active', true)
          .maybeSingle();

      if (finalCheck == null) {
        throw Exception('Failed to verify saved face embedding');
      }

      print('🎯 Final verification successful: $finalCheck');
      print('✅ Face embedding saved successfully for student: $schoolIdString');
      
    } catch (e) {
      print('❌ ERROR in saveFaceEmbedding: $e');
      
      // Provide more specific error messages
      String errorMessage = 'ไม่สามารถบันทึกข้อมูลใบหน้าได้';
      
      if (e.toString().contains('No authenticated user')) {
        errorMessage = 'กรุณาเข้าสู่ระบบใหม่';
      } else if (e.toString().contains('User not found')) {
        errorMessage = 'ไม่พบข้อมูลผู้ใช้ กรุณาติดต่อผู้ดูแลระบบ';
      } else if (e.toString().contains('School ID')) {
        errorMessage = 'ข้อมูลรหัสนักเรียนไม่ถูกต้อง กรุณาติดต่อผู้ดูแลระบบ';
      } else if (e.toString().contains('Invalid embedding')) {
        errorMessage = 'ข้อมูลใบหน้าไม่ถูกต้อง กรุณาลองถ่ายรูปใหม่';
      } else if (e.toString().contains('connection') || e.toString().contains('network')) {
        errorMessage = 'ปัญหาการเชื่อมต่อ กรุณาตรวจสอบอินเทอร์เน็ต';
      }
      
      throw Exception('$errorMessage: ${e.toString()}');
    }
  }

  double _calculateEmbeddingQuality(List<double> embedding) {
    try {
      // Calculate basic quality metrics
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

  Future<void> ensureUserProfileExists() async {
    final email = getCurrentUserEmail();
    if (email == null) return;

    try {
      final existingUser = await _supabase
          .from('users')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (existingUser == null) {
        print('Creating missing user profile for: $email');
        
        // สร้าง user profile พื้นฐาน
        await _supabase.from('users').insert({
          'email': email,
          'full_name': 'User', // ค่า default
          'school_id': email.split('@')[0], // ใช้ส่วนแรกของ email เป็น school_id ชั่วคราว
          'user_type': 'student',
          'is_active': true,
        });
        
        print('User profile created successfully');
      }
    } catch (e) {
      print('Error ensuring user profile: $e');
    }
  }

  Future<void> deactivateFaceEmbedding() async {
    try {
      final email = getCurrentUserEmail();
      if (email == null) {
        throw Exception('No authenticated user');
      }

      print('🔄 Deactivating face embedding for user: $email');

      // ดึง school_id จาก users table
      final userResponse = await _supabase
          .from('users')
          .select('school_id')
          .eq('email', email)
          .maybeSingle();

      if (userResponse == null) {
        throw Exception('User not found');
      }
      
      final schoolId = userResponse['school_id'];
      if (schoolId == null || schoolId.toString().isEmpty) {
        throw Exception('School ID not found');
      }

      final result = await _supabase
          .from('student_face_embeddings')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('student_id', schoolId.toString())
          .select();
      
      print('✅ Deactivated face embedding for student: $schoolId');
      print('📊 Update result: $result');
    } catch (e) {
      print('❌ Error deactivating face embedding: $e');
      throw Exception('ไม่สามารถลบข้อมูลใบหน้าได้: $e');
    }
  }

  Future<Map<String, dynamic>?> getFaceEmbeddingDetails() async {
    try {
      final email = getCurrentUserEmail();
      if (email == null) return null;

      // ดึง school_id จาก users table
      final userResponse = await _supabase
          .from('users')
          .select('school_id')
          .eq('email', email)
          .maybeSingle();

      if (userResponse == null) return null;
      
      final schoolId = userResponse['school_id'];
      if (schoolId == null || schoolId.toString().isEmpty) return null;

      try {
        final response = await _supabase
            .from('student_face_embeddings')
            .select('id, face_quality, created_at, updated_at')
            .eq('student_id', schoolId.toString())
            .eq('is_active', true)
            .single();
        
        return response;
      } catch (e) {
        print('No face embedding found for student: $schoolId');
        return null;
      }
    } catch (e) {
      print('Error getting face embedding details: $e');
      return null;
    }
  }

  Future<List<double>?> getFaceEmbedding() async {
    try {
      final email = getCurrentUserEmail();
      if (email == null) return null;

      // ดึง school_id จาก users table
      final userResponse = await _supabase
          .from('users')
          .select('school_id')
          .eq('email', email)
          .maybeSingle();

      if (userResponse == null) return null;
      
      final schoolId = userResponse['school_id'];
      if (schoolId == null || schoolId.toString().isEmpty) return null;

      final response = await _supabase
          .from('student_face_embeddings')
          .select('face_embedding_json')
          .eq('student_id', schoolId.toString())
          .eq('is_active', true)
          .single();
      
      if (response['face_embedding_json'] != null) {
        final List<dynamic> jsonList = jsonDecode(response['face_embedding_json']);
        final embedding = jsonList.map((item) => item as double).toList();
        
        // Validate embedding
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

  Future<void> updateFaceQuality(double quality) async {
    try {
      final email = getCurrentUserEmail();
      if (email == null) return;

      // ดึง school_id จาก users table
      final userResponse = await _supabase
          .from('users')
          .select('school_id')
          .eq('email', email)
          .maybeSingle();

      if (userResponse == null) return;
      
      final schoolId = userResponse['school_id'];
      if (schoolId == null || schoolId.toString().isEmpty) return;

      await _supabase.from('student_face_embeddings')
          .update({
            'face_quality': quality.clamp(0.0, 1.0),
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('student_id', schoolId.toString());
          
      print('✅ Updated face quality to: ${quality.toStringAsFixed(3)}');
    } catch (e) {
      print('❌ Error updating face quality: $e');
    }
  }


  // Face comparison for attendance
  Future<double> compareFaceEmbeddings(List<double> embedding1, List<double> embedding2) async {
    try {
      if (embedding1.length != embedding2.length) {
        throw Exception('Embeddings have different dimensions: ${embedding1.length} vs ${embedding2.length}');
      }
      
      if (embedding1.length != 128) {
        throw Exception('Invalid embedding size: ${embedding1.length}');
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
      print('❌ Error comparing face embeddings: $e');
      return -2.0; // Error value
    }
  }

  Future<bool> verifyFace(String studentId, List<double> capturedEmbedding, {double threshold = 0.7}) async {
    try {
      print('🔍 Verifying face for student: $studentId with threshold: $threshold');
      
      final response = await _supabase
          .from('student_face_embeddings')
          .select('face_embedding_json')
          .eq('student_id', studentId)
          .eq('is_active', true)
          .single();
      
      if (response['face_embedding_json'] == null) {
        print('❌ No face embedding found for student: $studentId');
        return false;
      }
      
      final List<dynamic> jsonList = jsonDecode(response['face_embedding_json']);
      final storedEmbedding = jsonList.map((item) => item as double).toList();
      
      if (storedEmbedding.length != capturedEmbedding.length) {
        print('❌ Embedding size mismatch: ${storedEmbedding.length} vs ${capturedEmbedding.length}');
        return false;
      }
      
      double similarity = await compareFaceEmbeddings(capturedEmbedding, storedEmbedding);
      
      if (similarity == -2.0) {
        print('❌ Error in similarity calculation');
        return false;
      }
      
      final isVerified = similarity > threshold;
      print('📊 Face verification result: ${isVerified ? "PASSED" : "FAILED"}');
      print('   Similarity: ${similarity.toStringAsFixed(4)}');
      print('   Threshold: ${threshold.toStringAsFixed(4)}');
      
      return isVerified;
    } catch (e) {
      print('❌ Error verifying face: $e');
      return false;
    }
  }

  // Class management functions
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<List<Map<String, dynamic>>> getTeacherClasses() async {
    final email = getCurrentUserEmail();
    if (email == null) return [];

    try {
      final response = await _supabase.from('classes').select().eq('teacher_email', email);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching classes: $e');
      return [];
    }
  }

  Future<void> createClass({
    required String classId,
    required String className,
    required String schedule,
    required String room,
  }) async {
    final email = getCurrentUserEmail();
    if (email == null) throw Exception('No authenticated user');

    final inviteCode = _generateInviteCode();
    try {
      await _supabase.from('classes').insert({
        'class_id': classId,
        'class_name': className,
        'teacher_email': email,
        'schedule': schedule,
        'room': room,
        'invite_code': inviteCode,
      });
    } catch (e) {
      print('Error creating class: $e');
      throw Exception('Failed to create class: ${e.toString()}');
    }
  }

  Future<bool> checkClassExists(String classId) async {
    try {
      final response = await _supabase
          .from('classes')
          .select('class_id')
          .eq('class_id', classId)
          .single();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateClass({
    required String classId,
    required String className,
    required String schedule,
    required String room,
  }) async {
    final email = getCurrentUserEmail();
    if (email == null) throw Exception('No authenticated user');

    await _supabase.from('classes').update({
      'class_name': className,
      'schedule': schedule,
      'room': room,
    }).match({'class_id': classId, 'teacher_email': email});
  }

  Future<void> deleteClass(String classId) async {
    final email = getCurrentUserEmail();
    if (email == null) throw Exception('No authenticated user');

    await _supabase
        .from('classes')
        .delete()
        .match({'class_id': classId, 'teacher_email': email});
  }

  Future<Map<String, dynamic>?> getClassDetail(String classId) async {
    try {
      if (classId.isEmpty) {
        throw Exception('Class ID cannot be empty');
      }

      final response = await _supabase
          .from('classes')
          .select()
          .eq('class_id', classId)
          .single();
      return response;
    } catch (e) {
      print('Error fetching class detail: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getClassStudents(String classId) async {
    try {
      final response = await _supabase
          .from('class_students')
          .select('*, users!inner(*)')
          .eq('class_id', classId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching students: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getClassByInviteCode(String inviteCode) async {
    try {
      final response = await _supabase
          .from('classes')
          .select()
          .eq('invite_code', inviteCode)
          .single();
      return response;
    } catch (e) {
      print('Error fetching class by invite code: $e');
      return null;
    }
  }

  Future<void> joinClass({
    required String classId,
    required String studentEmail,
  }) async {
    try {
      await _supabase.from('class_students').insert({
        'class_id': classId,
        'student_email': studentEmail,
      });
    } catch (e) {
      print('Error joining class: $e');
      throw Exception('Failed to join class: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getStudentClasses() async {
    final email = getCurrentUserEmail();
    if (email == null) return [];

    try {
      final response = await _supabase.from('class_students').select('''
        id,
        joined_at,
        classes (
          class_id,
          class_name,
          teacher_email,
          schedule,
          room,
          invite_code
        )
      ''').eq('student_email', email);

      return (response as List)
          .map((item) => {
                'id': item['classes']['class_id'],
                'name': item['classes']['class_name'],
                'teacher': item['classes']['teacher_email'],
                'code': item['classes']['invite_code'],
                'schedule': item['classes']['schedule'],
                'room': item['classes']['room'],
                'joinedDate': DateTime.parse(item['joined_at']),
                'isFavorite': false,
              })
          .toList();
    } catch (e) {
      print('Error fetching student classes: $e');
      return [];
    }
  }

  Future<void> leaveClass({
    required String classId,
    required String studentEmail,
  }) async {
    try {
      await _supabase.from('class_students').delete().match({
        'class_id': classId,
        'student_email': studentEmail,
      });
    } catch (e) {
      print('Error leaving class: $e');
      throw Exception('Failed to leave class: ${e.toString()}');
    }
  }
  
}
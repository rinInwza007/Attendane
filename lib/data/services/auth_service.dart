// แก้ไขทั้งหมดใน auth_server.dart เพื่อให้ตรงกับ DB Schema

import 'dart:math';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthServer {
  final SupabaseClient _supabase = Supabase.instance.client;

  // เพิ่มเพื่อให้เข้าถึง _supabase ได้จากภายนอก
  SupabaseClient get supabase => _supabase;

  // Authentication functions (เหมือนเดิม)
  Future<AuthResponse> siginWithEmailPassword(String email, String password) async {
    try {
      return await _supabase.auth.signInWithPassword(password: password, email: email);
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  Future<AuthResponse> sigUpWithEmailPassword(String email, String password) async {
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

  // Face recognition functions - แก้ไขให้ตรงกับ DB Schema
  Future<bool> hasFaceEmbedding() async {
  try {
    final userProfile = await getUserProfile();
    if (userProfile == null) return false;
    
    // ใช้ข้อมูลจาก view
    return userProfile['has_face_data'] ?? false;
  } catch (e) {
    print('Error checking face embedding: $e');
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

    final schoolIdString = schoolId.toString();
    print('🎓 Step 3: Using school_id: "$schoolIdString" (type: ${schoolId.runtimeType})');

    // ตรวจสอบว่า school_id นี้มีอยู่จริงในฐานข้อมูล
    final schoolIdCheck = await _supabase
        .from('users')
        .select('school_id')
        .eq('school_id', schoolIdString)
        .maybeSingle();

    if (schoolIdCheck == null) {
      print('❌ School ID verification failed');
      print('Available school_ids in database:');
      
      // แสดงรายการ school_id ที่มีอยู่
      final allUsers = await _supabase
          .from('users')
          .select('email, school_id');
      
      for (var user in allUsers) {
        print('  - ${user['email']}: "${user['school_id']}" (${user['school_id'].runtimeType})');
      }
      
      throw Exception('School ID "$schoolIdString" not found in users table');
    }

    print('✅ Step 4: School ID verified in database');

    // ตรวจสอบข้อมูลเดิมใน student_face_embeddings
    final existing = await _supabase
        .from('student_face_embeddings')
        .select('id, student_id, is_active')
        .eq('student_id', schoolIdString)
        .maybeSingle();

    print('📋 Step 5: Existing face data check: $existing');

    final embeddingJson = jsonEncode(embedding);
    final quality = 0.95;

    if (existing != null) {
      print('📝 Step 6: Updating existing record...');
      
      final updateData = {
        'face_embedding_json': embeddingJson,
        'face_quality': quality,
        'is_active': true,
      };

      print('📤 Update data: $updateData');

      await _supabase.from('student_face_embeddings')
          .update(updateData)
          .eq('student_id', schoolIdString);
      
      print('✅ Successfully updated face embedding');
    } else {
      print('➕ Step 6: Inserting new record...');
      
      final insertData = {
        'student_id': schoolIdString,
        'face_embedding_json': embeddingJson,
        'face_quality': quality,
        'is_active': true
      };

      print('📤 Insert data: $insertData');
      print('📤 student_id type: ${schoolIdString.runtimeType}');
      print('📤 student_id value: "$schoolIdString"');

      await _supabase.from('student_face_embeddings').insert(insertData);
      
      print('✅ Successfully inserted face embedding');
    }

    // ตรวจสอบผลลัพธ์สุดท้าย
    final finalCheck = await _supabase
        .from('student_face_embeddings')
        .select('id, student_id, face_quality, is_active, created_at')
        .eq('student_id', schoolIdString)
        .eq('is_active', true)
        .maybeSingle();

    print('🎯 Final verification: $finalCheck');
    
  } catch (e) {
    print('❌ ERROR in saveFaceEmbedding: $e');
    print('❌ Error type: ${e.runtimeType}');
    
    // แสดงข้อมูล debug เพิ่มเติม
    try {
      final email = getCurrentUserEmail();
      print('🔍 Debug - Current email: $email');
      
      if (email != null) {
        final debugUser = await _supabase
            .from('users')
            .select('*')
            .eq('email', email)
            .maybeSingle();
        print('🔍 Debug - User data: $debugUser');
      }
    } catch (debugError) {
      print('❌ Debug error: $debugError');
    }
    
    throw Exception('ไม่สามารถบันทึกข้อมูลใบหน้าได้: $e');
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
      final userProfile = await getUserProfile();
      if (userProfile == null) return;
      
      final schoolId = userProfile['school_id'];
      if (schoolId == null || schoolId.isEmpty) return;

      await _supabase.from('student_face_embeddings')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('student_id', schoolId);
      
      print('Deactivated face embedding for student: $schoolId');
    } catch (e) {
      print('Error deactivating face embedding: $e');
      throw Exception('ไม่สามารถลบข้อมูลใบหน้าได้: $e');
    }
  }

  Future<Map<String, dynamic>?> getFaceEmbeddingDetails() async {
    try {
      final userProfile = await getUserProfile();
      if (userProfile == null) return null;
      
      final schoolId = userProfile['school_id'];
      if (schoolId == null || schoolId.isEmpty) return null;

      try {
        final response = await _supabase
            .from('student_face_embeddings')
            .select('id, face_quality, created_at, updated_at')
            .eq('student_id', schoolId)
            .eq('is_active', true)
            .single();
        
        return response;
      } catch (e) {
        print('Error fetching face details: $e');
        return null;
      }
    } catch (e) {
      print('Error getting face embedding details: $e');
      return null;
    }
  }

  Future<List<double>?> getFaceEmbedding() async {
    try {
      final userProfile = await getUserProfile();
      if (userProfile == null) return null;
      
      final schoolId = userProfile['school_id'];
      if (schoolId == null || schoolId.isEmpty) return null;

      final response = await _supabase
          .from('student_face_embeddings')
          .select('face_embedding, face_embedding_json')
          .eq('student_id', schoolId)
          .eq('is_active', true)
          .single();
      
      if (response['face_embedding'] != null) {
        return List<double>.from(response['face_embedding']);
      }
      
      if (response['face_embedding_json'] != null) {
        final List<dynamic> jsonList = jsonDecode(response['face_embedding_json']);
        return jsonList.map((item) => item as double).toList();
      }
      
      return null;
    } catch (e) {
      print('Error fetching face embedding: $e');
      return null;
    }
  }

  Future<void> updateFaceQuality(double quality) async {
    try {
      final userProfile = await getUserProfile();
      if (userProfile == null) return;
      
      final schoolId = userProfile['school_id'];
      if (schoolId == null || schoolId.isEmpty) return;

      await _supabase.from('student_face_embeddings')
          .update({
            'face_quality': quality,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('student_id', schoolId);
    } catch (e) {
      print('Error updating face quality: $e');
    }
  }

  // Face comparison for attendance
  Future<double> compareFaceEmbeddings(List<double> embedding1, List<double> embedding2) async {
    try {
      double dotProduct = 0.0;
      for (int i = 0; i < embedding1.length; i++) {
        dotProduct += embedding1[i] * embedding2[i];
      }
      
      return dotProduct;
    } catch (e) {
      print('Error comparing face embeddings: $e');
      return -2;
    }
  }

  Future<bool> verifyFace(String studentId, List<double> capturedEmbedding, {double threshold = 0.7}) async {
    try {
      final response = await _supabase
          .from('student_face_embeddings')
          .select('face_embedding, face_embedding_json')
          .eq('student_id', studentId)
          .eq('is_active', true)
          .single();
      
      List<double>? storedEmbedding;
      
      if (response['face_embedding'] != null) {
        storedEmbedding = List<double>.from(response['face_embedding']);
      } else if (response['face_embedding_json'] != null) {
        final List<dynamic> jsonList = jsonDecode(response['face_embedding_json']);
        storedEmbedding = jsonList.map((item) => item as double).toList();
      }
      
      if (storedEmbedding == null) return false;
      
      double similarity = await compareFaceEmbeddings(capturedEmbedding, storedEmbedding);
      
      return similarity > threshold;
    } catch (e) {
      print('Error verifying face: $e');
      return false;
    }
  }

  // Class management functions (เหมือนเดิม)
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
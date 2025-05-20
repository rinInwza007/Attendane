import 'dart:math';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthServer {
  final SupabaseClient _supabase = Supabase.instance.client;

  // เพิ่มเพื่อให้เข้าถึง _supabase ได้จากภายนอก (สำหรับใช้ใน profile.dart)
  SupabaseClient get supabase => _supabase;

  // Authentication functions
  Future<AuthResponse> siginWithEmailPassword(
      String email, String password) async {
    try {
      return await _supabase.auth
          .signInWithPassword(password: password, email: email);
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  Future<AuthResponse> sigUpWithEmailPassword(
      String email, String password) async {
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
  if (email == null) return null;

  try {
    final response =
        await _supabase.from('users').select().eq('email', email).single();
    
    // เพิ่มข้อมูล hasFaceData เข้าไปใน response
    if (response != null) {
      final hasFace = await hasFaceEmbedding();
      final userData = {...response, 'has_face_data': hasFace};
      return userData;
    }
    
    return response;
  } catch (e) {
    print('Error getting user profile: $e');
    return null;
  }
}

  Future<bool> checkUserProfileExists() async {
    final email = getCurrentUserEmail();
    if (email == null) return false;

    try {
      final response =
          await _supabase.from('users').select().eq('email', email).single();
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
        'userType': response?['user_type'],
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

    await _supabase.from('users').upsert({
      'email': email,
      'full_name': fullName,
      'school_id': schoolId,
      'user_type': userType,
    });
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

  // Face recognition functions
  Future<bool> hasFaceEmbedding() async {
    try {
      final userProfile = await getUserProfile();
      if (userProfile == null) return false;
      
      final schoolId = userProfile['school_id'];
      if (schoolId == null || schoolId.isEmpty) return false;

      try {
        final response = await _supabase
            .from('student_face_embeddings')
            .select('id, face_quality')
            .eq('student_id', schoolId)
            .eq('is_active', true)
            .single();
        
        // มีข้อมูลใบหน้าและคุณภาพเพียงพอ (ถ้ามีการเก็บ face_quality)
        if (response != null) {
          // ถ้ามีการตั้งค่าขีดจำกัดคุณภาพขั้นต่ำ
          // ตัวอย่าง: ถ้าคุณภาพต่ำกว่า 0.7 ให้ถือว่ายังไม่มีข้อมูลใบหน้าที่มีคุณภาพเพียงพอ
          double? quality = response['face_quality'];
          if (quality != null && quality < 0.7) {
            return false;
          }
          return true;
        }
        return false;
      } catch (e) {
        print('Error checking face embedding: $e');
        return false;
      }
    } catch (e) {
      print('Error in hasFaceEmbedding: $e');
      return false;
    }
  }

  Future<void> saveFaceEmbedding(List<double> embedding) async {
    try {
      final email = getCurrentUserEmail();
      if (email == null) throw Exception('No authenticated user');

      // ดึงข้อมูลโปรไฟล์ของผู้ใช้เพื่อรับ school_id
      final userProfile = await getUserProfile();
      if (userProfile == null) throw Exception('User profile not found');
      
      final schoolId = userProfile['school_id'];
      if (schoolId == null || schoolId.isEmpty) {
        throw Exception('School ID not found in user profile');
      }

      // คำนวณคุณภาพของใบหน้า (ตัวอย่าง - ค่าสมมติ)
      double quality = 0.95;
      
      // แปลง embedding เป็น JSON ในกรณีที่เกิดปัญหากับประเภทข้อมูล vector
      final String embeddingJson = jsonEncode(embedding);
      
      // ตรวจสอบว่ามีข้อมูลเดิมหรือไม่
      bool hasExisting = false;
      try {
        final existing = await _supabase
            .from('student_face_embeddings')
            .select('id')
            .eq('student_id', schoolId)
            .single();
        hasExisting = existing != null;
      } catch (e) {
        // ไม่พบข้อมูลเดิม - ดำเนินการต่อ
        hasExisting = false;
      }
      
      try {
        if (hasExisting) {
          // อัปเดตข้อมูลเดิม
          await _supabase.from('student_face_embeddings')
              .update({
                'face_embedding': embedding,
                'face_embedding_json': embeddingJson,
                'face_quality': quality,
                'is_active': true,
                'updated_at': DateTime.now().toIso8601String()
              })
              .eq('student_id', schoolId);
          
          print('Successfully updated face embedding');
        } else {
          // เพิ่มข้อมูลใหม่
          await _supabase.from('student_face_embeddings')
              .insert({
                'student_id': schoolId,
                'face_embedding': embedding,
                'face_embedding_json': embeddingJson,
                'face_quality': quality,
                'is_active': true
              });
          
          print('Successfully inserted face embedding');
        }
      } catch (e) {
        print('Error storing face embedding directly: $e');
        
        // ลองวิธีสำรองด้วยการใช้เฉพาะ JSON
        if (hasExisting) {
          await _supabase.from('student_face_embeddings')
              .update({
                'face_embedding_json': embeddingJson,
                'face_quality': quality,
                'is_active': true,
                'updated_at': DateTime.now().toIso8601String()
              })
              .eq('student_id', schoolId);
        } else {
          await _supabase.from('student_face_embeddings')
              .insert({
                'student_id': schoolId,
                'face_embedding_json': embeddingJson,
                'face_quality': quality,
                'is_active': true
              });
        }
        
        print('Successfully saved face embedding using fallback method');
      }
    } catch (e) {
      print('Error saving face embedding: $e');
      throw Exception('ไม่สามารถบันทึกข้อมูลใบหน้าได้: $e');
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
      
      if (response == null) return null;
      
      // ลองดึงจาก face_embedding ก่อน
      if (response['face_embedding'] != null) {
        return List<double>.from(response['face_embedding']);
      }
      
      // ถ้าไม่มีให้ลองดึงจาก face_embedding_json
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

  // Class management functions
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  Future<List<Map<String, dynamic>>> getTeacherClasses() async {
    final email = getCurrentUserEmail();
    if (email == null) return [];

    try {
      final response =
          await _supabase.from('classes').select().eq('teacher_email', email);
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

      // แปลงข้อมูลให้อยู่ในรูปแบบที่ต้องการ
      return (response as List)
          .map((item) => {
                'id': item['classes']['class_id'],
                'name': item['classes']['class_name'],
                'teacher': item['classes']['teacher_email'],
                'code': item['classes']['invite_code'],
                'schedule': item['classes']['schedule'],
                'room': item['classes']['room'],
                'joinedDate': DateTime.parse(item['joined_at']),
                'isFavorite': false, // หรือเก็บ favorite ในฐานข้อมูล
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
      // ลบข้อมูลจากตาราง class_students
      await _supabase.from('class_students').delete().match({
        'class_id': classId,
        'student_email': studentEmail,
      });
    } catch (e) {
      print('Error leaving class: $e');
      throw Exception('Failed to leave class: ${e.toString()}');
    }
  }

  // Face comparison for attendance
  Future<double> compareFaceEmbeddings(List<double> embedding1, List<double> embedding2) async {
    try {
      // คำนวณความคล้ายคลึงกันระหว่าง embeddings โดยใช้ cosine similarity
      double dotProduct = 0.0;
      for (int i = 0; i < embedding1.length; i++) {
        dotProduct += embedding1[i] * embedding2[i];
      }
      
      // ค่าความคล้ายคลึงจะอยู่ระหว่าง -1 ถึง 1 (1 คือเหมือนกันมากที่สุด)
      return dotProduct;
    } catch (e) {
      print('Error comparing face embeddings: $e');
      return -2; // ค่าที่แสดงว่าเกิดข้อผิดพลาด
    }
  }

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
      
      if (storedEmbedding == null) return false;
      
      // เปรียบเทียบ embeddings
      double similarity = await compareFaceEmbeddings(capturedEmbedding, storedEmbedding);
      
      // ถ้าความคล้ายคลึงสูงกว่าค่า threshold ถือว่าเป็นคนเดียวกัน
      return similarity > threshold;
    } catch (e) {
      print('Error verifying face: $e');
      return false;
    }
  }
}
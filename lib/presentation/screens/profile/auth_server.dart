import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthServer {
  final SupabaseClient _supabase = Supabase.instance.client;

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

  // User profile functions
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

  Future<bool> hasFaceEmbedding() async {
    final email = getCurrentUserEmail();
    if (email == null) return false;

    try {
      final response = await _supabase
          .from('student_face_embeddings')
          .select()
          .eq('user_id', email)
          .single();
      return response != null;
    } catch (e) {
      return false;
    }
  }

// บันทึกข้อมูล embedding
  Future<void> saveFaceEmbedding(List<double> embedding) async {
    final email = getCurrentUserEmail();
    if (email == null) throw Exception('No authenticated user');

    await _supabase.from('student_face_embeddings').upsert({
      'user_id': email,
      'embedding': embedding,
      'is_active': true,
    });
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
  final email = getCurrentUserEmail();
  if (email == null) return null;

  try {
    final response =
        await _supabase.from('users').select().eq('email', email).single();
    return response;
  } catch (e) {
    print('Error getting user profile: $e');
    return null;
  }
}
}

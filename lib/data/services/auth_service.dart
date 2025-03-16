import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/class_model.dart';
import 'base_service.dart';

class AuthService extends BaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Authentication Methods
  Future<AuthResponse> signInWithEmailPassword(
      String email, String password) async {
    return await handleError(() async {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    });
  }

  Future<AuthResponse> signUpWithEmailPassword(
      String email, String password) async {
    return await handleError(() async {
      return await _supabase.auth.signUp(
        email: email,
        password: password,
      );
    });
  }

  Future<void> signOut() async {
    await handleError(() async {
      await _supabase.auth.signOut();
    });
  }

  String? getCurrentUserEmail() {
    return _supabase.auth.currentSession?.user.email;
  }

  String? getCurrentUserId() {
    return _supabase.auth.currentSession?.user.id;
  }

  // User Profile Methods
  Future<UserModel?> getUserProfile() async {
    return await handleError(() async {
      final email = getCurrentUserEmail();
      if (email == null) return null;

      final response =
          await _supabase.from('users').select().eq('email', email).single();

      if (response == null) return null;

      // Check if user has face embedding
      final hasFace = await hasFaceEmbedding();

      // Create user model with merged data
      final userData = {...response, 'has_face_data': hasFace};
      return UserModel.fromJson(userData);
    });
  }

  Future<bool> checkUserProfileExists() async {
    return await handleError(() async {
      final email = getCurrentUserEmail();
      if (email == null) return false;

      try {
        final response =
            await _supabase.from('users').select().eq('email', email).single();
        return response != null;
      } catch (e) {
        return false;
      }
    });
  }

  Future<Map<String, dynamic>> checkUserProfile() async {
    return await handleError(() async {
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
    });
  }

  Future<void> saveUserProfile({
    required String fullName,
    required String schoolId,
    required String userType,
  }) async {
    await handleError(() async {
      final email = getCurrentUserEmail();
      if (email == null) throw Exception('No authenticated user');

      await _supabase.from('users').upsert({
        'email': email,
        'full_name': fullName,
        'school_id': schoolId,
        'user_type': userType,
      });
    });
  }

  Future<String?> getUserType() async {
    return await handleError(() async {
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
    });
  }

  // Class Management Methods
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  Future<List<ClassModel>> getTeacherClasses() async {
    return await handleError(() async {
      final email = getCurrentUserEmail();
      if (email == null) return [];

      try {
        final response =
            await _supabase.from('classes').select().eq('teacher_email', email);

        return List<Map<String, dynamic>>.from(response)
            .map((data) => ClassModel.fromJson(data))
            .toList();
      } catch (e) {
        print('Error fetching classes: $e');
        return [];
      }
    });
  }

  Future<void> createClass({
    required String classId,
    required String className,
    required String schedule,
    required String room,
  }) async {
    await handleError(() async {
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
        throw Exception('Failed to create class: ${e.toString()}');
      }
    });
  }

  Future<bool> checkClassExists(String classId) async {
    return await handleError(() async {
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
    });
  }

  Future<void> updateClass({
    required String classId,
    required String className,
    required String schedule,
    required String room,
  }) async {
    await handleError(() async {
      final email = getCurrentUserEmail();
      if (email == null) throw Exception('No authenticated user');

      await _supabase.from('classes').update({
        'class_name': className,
        'schedule': schedule,
        'room': room,
      }).match({'class_id': classId, 'teacher_email': email});
    });
  }

  Future<void> deleteClass(String classId) async {
    await handleError(() async {
      final email = getCurrentUserEmail();
      if (email == null) throw Exception('No authenticated user');

      await _supabase
          .from('classes')
          .delete()
          .match({'class_id': classId, 'teacher_email': email});
    });
  }

  Future<ClassModel?> getClassDetail(String classId) async {
    return await handleError(() async {
      try {
        final response = await _supabase
            .from('classes')
            .select()
            .eq('class_id', classId)
            .single();

        if (response == null) return null;
        return ClassModel.fromJson(response);
      } catch (e) {
        print('Error fetching class detail: $e');
        return null;
      }
    });
  }

  Future<List<Map<String, dynamic>>> getClassStudents(String classId) async {
    return await handleError(() async {
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
    });
  }

  Future<ClassModel?> getClassByInviteCode(String inviteCode) async {
    return await handleError(() async {
      try {
        final response = await _supabase
            .from('classes')
            .select()
            .eq('invite_code', inviteCode)
            .single();

        if (response == null) return null;
        return ClassModel.fromJson(response);
      } catch (e) {
        print('Error fetching class by invite code: $e');
        return null;
      }
    });
  }

  Future<void> joinClass({
    required String classId,
    required String studentEmail,
  }) async {
    await handleError(() async {
      try {
        await _supabase.from('class_students').insert({
          'class_id': classId,
          'student_email': studentEmail,
        });
      } catch (e) {
        throw Exception('Failed to join class: ${e.toString()}');
      }
    });
  }

  Future<List<ClassModel>> getStudentClasses() async {
    return await handleError(() async {
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
            .map((item) => ClassModel.fromJson({
                  'class_id': item['classes']['class_id'],
                  'class_name': item['classes']['class_name'],
                  'teacher_email': item['classes']['teacher_email'],
                  'invite_code': item['classes']['invite_code'],
                  'schedule': item['classes']['schedule'],
                  'room': item['classes']['room'],
                  'created_at': item['joined_at'],
                  'is_favorite':
                      false, // You could store this in the database instead
                }))
            .toList();
      } catch (e) {
        print('Error fetching student classes: $e');
        return [];
      }
    });
  }

  Future<void> leaveClass({
    required String classId,
    required String studentEmail,
  }) async {
    await handleError(() async {
      try {
        await _supabase.from('class_students').delete().match({
          'class_id': classId,
          'student_email': studentEmail,
        });
      } catch (e) {
        throw Exception('Failed to leave class: ${e.toString()}');
      }
    });
  }

  // Face Recognition Methods
  Future<bool> hasFaceEmbedding() async {
    return await handleError(() async {
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
    });
  }

  Future<void> saveFaceEmbedding(List<double> embedding) async {
    await handleError(() async {
      final email = getCurrentUserEmail();
      if (email == null) throw Exception('No authenticated user');

      await _supabase.from('student_face_embeddings').upsert({
        'user_id': email,
        'embedding': embedding,
        'is_active': true,
      });
    });
  }
}

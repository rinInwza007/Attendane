// lib/data/services/auth_service.dart
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:myproject2/data/models/attendance_record_model.dart';
import 'package:myproject2/data/models/attendance_session_model.dart';
import 'package:myproject2/data/models/webcam_config_model.dart';
import 'dart:math' as Math;

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==================== Authentication ====================
  
  Future<void> signUpWithEmailPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      
      if (response.user == null) {
        throw Exception('Failed to create account');
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  Future<void> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user == null) {
        throw Exception('Login failed');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  String? getCurrentUserEmail() {
    return _supabase.auth.currentUser?.email;
  }

  // ==================== User Profile ====================
  
  Future<Map<String, dynamic>> checkUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {'exists': false, 'userType': null};
      }

      final response = await _supabase
          .from('users')
          .select('user_type')
          .eq('email', user.email!)
          .maybeSingle();

      if (response == null) {
        return {'exists': false, 'userType': null};
      }

      return {'exists': true, 'userType': response['user_type']};
    } catch (e) {
      throw Exception('Error checking user profile: $e');
    }
  }

  Future<void> saveUserProfile({
    required String fullName,
    required String schoolId,
    required String userType,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      await _supabase.from('users').upsert({
        'email': user.email,
        'full_name': fullName,
        'school_id': schoolId,
        'user_type': userType,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to save user profile: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('users')
          .select()
          .eq('email', user.email!)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Error getting user profile: $e');
    }
  }

  // ==================== Class Management ====================
  
  Future<List<Map<String, dynamic>>> getTeacherClasses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final response = await _supabase
          .from('classes')
          .select()
          .eq('teacher_email', user.email!)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error getting teacher classes: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getStudentClasses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final response = await _supabase
          .from('class_students')
          .select('''
            class_id,
            joined_at,
            classes!inner(
              class_id,
              class_name,
              teacher_email,
              schedule,
              room
            )
          ''')
          .eq('student_email', user.email!)
          .order('joined_at', ascending: false);

      return response.map<Map<String, dynamic>>((item) {
        final classInfo = item['classes'];
        return {
          'id': classInfo['class_id'],
          'name': classInfo['class_name'],
          'teacher': classInfo['teacher_email'],
          'schedule': classInfo['schedule'],
          'room': classInfo['room'],
          'joinedDate': DateTime.parse(item['joined_at']),
          'isFavorite': false,
        };
      }).toList();
    } catch (e) {
      throw Exception('Error getting student classes: $e');
    }
  }

  Future<bool> checkClassExists(String classId) async {
    try {
      final response = await _supabase
          .from('classes')
          .select('class_id')
          .eq('class_id', classId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> createClass({
    required String classId,
    required String className,
    required String schedule,
    required String room,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Generate random invite code
      final inviteCode = _generateInviteCode();

      await _supabase.from('classes').insert({
        'class_id': classId,
        'class_name': className,
        'teacher_email': user.email,
        'schedule': schedule,
        'room': room,
        'invite_code': inviteCode,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to create class: $e');
    }
  }

  Future<void> updateClass({
    required String classId,
    required String className,
    required String schedule,
    required String room,
  }) async {
    try {
      await _supabase
          .from('classes')
          .update({
            'class_name': className,
            'schedule': schedule,
            'room': room,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('class_id', classId);
    } catch (e) {
      throw Exception('Failed to update class: $e');
    }
  }

  Future<void> deleteClass(String classId) async {
    try {
      await _supabase
          .from('classes')
          .delete()
          .eq('class_id', classId);
    } catch (e) {
      throw Exception('Failed to delete class: $e');
    }
  }

  Future<Map<String, dynamic>> getClassDetail(String classId) async {
    try {
      final response = await _supabase
          .from('classes')
          .select()
          .eq('class_id', classId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Error getting class detail: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getClassStudents(String classId) async {
    try {
      final response = await _supabase
          .from('class_students')
          .select('''
            student_email,
            joined_at,
            users!inner(
              email,
              full_name,
              school_id
            )
          ''')
          .eq('class_id', classId)
          .order('joined_at');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error getting class students: $e');
    }
  }

  Future<Map<String, dynamic>?> getClassByInviteCode(String inviteCode) async {
    try {
      final response = await _supabase
          .from('classes')
          .select()
          .eq('invite_code', inviteCode)
          .maybeSingle();

      return response;
    } catch (e) {
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
        'joined_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to join class: $e');
    }
  }

  Future<void> leaveClass({
    required String classId,
    required String studentEmail,
  }) async {
    try {
      await _supabase
          .from('class_students')
          .delete()
          .eq('class_id', classId)
          .eq('student_email', studentEmail);
    } catch (e) {
      throw Exception('Failed to leave class: $e');
    }
  }

  // ==================== Face Recognition ====================
  
  Future<bool> hasFaceEmbedding() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final userProfile = await getUserProfile();
      if (userProfile == null) return false;

      final schoolId = userProfile['school_id'];
      if (schoolId == null) return false;

      final response = await _supabase
          .from('student_face_embeddings')
          .select('id')
          .eq('student_id', schoolId)
          .eq('is_active', true)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> saveFaceEmbedding(List<double> embedding) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final userProfile = await getUserProfile();
      if (userProfile == null) throw Exception('User profile not found');

      final schoolId = userProfile['school_id'];
      if (schoolId == null) throw Exception('School ID not found');

      final embeddingJson = jsonEncode(embedding);
      final quality = _calculateEmbeddingQuality(embedding);

      await _supabase.from('student_face_embeddings').upsert({
        'student_id': schoolId,
        'face_embedding_json': embeddingJson,
        'face_quality': quality,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to save face embedding: $e');
    }
  }

  Future<void> deactivateFaceEmbedding() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final userProfile = await getUserProfile();
      if (userProfile == null) throw Exception('User profile not found');

      final schoolId = userProfile['school_id'];
      if (schoolId == null) throw Exception('School ID not found');

      await _supabase
          .from('student_face_embeddings')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('student_id', schoolId);
    } catch (e) {
      throw Exception('Failed to deactivate face embedding: $e');
    }
  }

  Future<bool> verifyFace(String studentId, List<double> capturedEmbedding) async {
    try {
      final response = await _supabase
          .from('student_face_embeddings')
          .select('face_embedding_json')
          .eq('student_id', studentId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return false;

      final storedEmbeddingJson = response['face_embedding_json'];
      final storedEmbedding = List<double>.from(jsonDecode(storedEmbeddingJson));

      final similarity = _calculateCosineSimilarity(capturedEmbedding, storedEmbedding);
      return similarity > 0.7; // Threshold for face verification
    } catch (e) {
      return false;
    }
  }

  // ==================== Helper Methods ====================
  
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    
    for (int i = 0; i < 6; i++) {
      code += chars[(random + i) % chars.length];
    }
    
    return code;
  }

  double _calculateEmbeddingQuality(List<double> embedding) {
    // Simple quality calculation based on variance
    double sum = embedding.reduce((a, b) => a + b);
    double mean = sum / embedding.length;
    
    double variance = 0;
    for (double value in embedding) {
      variance += (value - mean) * (value - mean);
    }
    variance /= embedding.length;
    
    return (variance * 10).clamp(0.0, 1.0);
  }

  double _calculateCosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    if (normA == 0.0 || normB == 0.0) return 0.0;
    
    return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
  }
}

// Import math library for sqrt function


// ==================== Simple Attendance Service ====================

class SimpleAttendanceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==================== Session Management ====================
  
  Future<AttendanceSessionModel> createAttendanceSession({
    required String classId,
    required int durationHours,
    required int onTimeLimitMinutes,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Teacher not authenticated');
      }

      final now = DateTime.now();
      final sessionData = {
        'class_id': classId,
        'teacher_email': user.email,
        'start_time': now.toIso8601String(),
        'end_time': now.add(Duration(hours: durationHours)).toIso8601String(),
        'on_time_limit_minutes': onTimeLimitMinutes,
        'status': 'active',
        'created_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('attendance_sessions')
          .insert(sessionData)
          .select()
          .single();

      return AttendanceSessionModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create session: $e');
    }
  }

  Future<AttendanceSessionModel?> getActiveSessionForClass(String classId) async {
    try {
      final response = await _supabase
          .from('attendance_sessions')
          .select()
          .eq('class_id', classId)
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return null;
      
      final session = AttendanceSessionModel.fromJson(response);
      
      // Auto-end expired sessions
      if (session.isEnded && session.status == 'active') {
        await endAttendanceSession(session.id);
        return null;
      }
      
      return session;
    } catch (e) {
      throw Exception('Failed to get active session: $e');
    }
  }

  Future<void> endAttendanceSession(String sessionId) async {
    try {
      await _supabase
          .from('attendance_sessions')
          .update({
            'status': 'ended',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);
    } catch (e) {
      throw Exception('Failed to end session: $e');
    }
  }

  Future<List<AttendanceRecordModel>> getAttendanceRecords(String sessionId) async {
    try {
      final response = await _supabase
          .from('attendance_records')
          .select('''
            *,
            users!attendance_records_student_email_fkey(full_name, school_id)
          ''')
          .eq('session_id', sessionId)
          .order('check_in_time');

      return response.map((record) => AttendanceRecordModel.fromJson(record)).toList();
    } catch (e) {
      throw Exception('Failed to get attendance records: $e');
    }
  }

  Future<List<AttendanceSessionModel>> getClassAttendanceSessions(String classId) async {
    try {
      final response = await _supabase
          .from('attendance_sessions')
          .select()
          .eq('class_id', classId)
          .order('start_time', ascending: false);

      return response.map((session) => AttendanceSessionModel.fromJson(session)).toList();
    } catch (e) {
      throw Exception('Failed to get attendance sessions: $e');
    }
  }

  Future<List<AttendanceRecordModel>> getStudentAttendanceHistory(String studentEmail) async {
    try {
      final response = await _supabase
          .from('attendance_records')
          .select('''
            *,
            attendance_sessions!inner(
              class_id,
              start_time,
              end_time,
              classes!inner(class_name)
            )
          ''')
          .eq('student_email', studentEmail)
          .order('check_in_time', ascending: false);

      return response.map((record) => AttendanceRecordModel.fromJson(record)).toList();
    } catch (e) {
      throw Exception('Failed to get attendance history: $e');
    }
  }

  Future<bool> testWebcamConnection(WebcamConfigModel config) async {
    try {
      final response = await http.get(
        Uri.parse(config.captureUrl),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<AttendanceRecordModel> simpleCheckIn({
    required String sessionId,
    required WebcamConfigModel webcamConfig,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Validate session
      final sessionResponse = await _supabase
          .from('attendance_sessions')
          .select()
          .eq('id', sessionId)
          .single();
      
      final session = AttendanceSessionModel.fromJson(sessionResponse);
      if (!session.isActive) {
        throw Exception('Attendance session is not active');
      }

      // Check for existing record
      final existingRecord = await _supabase
          .from('attendance_records')
          .select()
          .eq('session_id', sessionId)
          .eq('student_email', user.email!)
          .maybeSingle();

      if (existingRecord != null) {
        throw Exception('Already checked in for this session');
      }

      // Get user profile
      final userProfile = await _supabase
          .from('users')
          .select()
          .eq('email', user.email!)
          .single();
      
      // Determine status
      final checkInTime = DateTime.now();
      final status = session.isOnTime(checkInTime) ? 'present' : 'late';

      // Save record
      final recordData = {
        'session_id': sessionId,
        'student_email': user.email,
        'student_id': userProfile['school_id'],
        'check_in_time': checkInTime.toIso8601String(),
        'status': status,
        'created_at': checkInTime.toIso8601String(),
      };

      final recordResponse = await _supabase
          .from('attendance_records')
          .insert(recordData)
          .select()
          .single();

      return AttendanceRecordModel.fromJson(recordResponse);
    } catch (e) {
      throw Exception('Check-in failed: $e');
    }
  }
}
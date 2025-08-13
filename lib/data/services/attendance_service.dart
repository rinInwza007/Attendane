// lib/data/services/attendance_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myproject2/data/models/attendance_record_model.dart';
import 'package:myproject2/data/models/attendance_session_model.dart';
import 'package:myproject2/data/models/webcam_config_model.dart';
import 'package:myproject2/data/services/auth_service.dart';

class AttendanceService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // ==================== Session Management ====================
  
  Future<AttendanceSessionModel> createAttendanceSession({
    required String classId,
    required int durationHours,
    required int onTimeLimitMinutes,
  }) async {
    try {
      final teacherEmail = _authService.getCurrentUserEmail();
      if (teacherEmail == null) {
        throw AttendanceException('Teacher not authenticated');
      }

      // Check for existing active session
      final existingSession = await getActiveSessionForClass(classId);
      if (existingSession != null) {
        throw AttendanceException('Active session already exists for this class');
      }

      final now = DateTime.now();
      final sessionData = _buildSessionData(
        classId: classId,
        teacherEmail: teacherEmail,
        startTime: now,
        durationHours: durationHours,
        onTimeLimitMinutes: onTimeLimitMinutes,
      );

      final response = await _supabase
          .from('attendance_sessions')
          .insert(sessionData)
          .select()
          .single();

      return AttendanceSessionModel.fromJson(response);
    } catch (e) {
      throw AttendanceException('Failed to create session: $e');
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
      throw AttendanceException('Failed to get active session: $e');
    }
  }

  Future<void> endAttendanceSession(String sessionId) async {
    try {
      // Update session status
      await _supabase
          .from('attendance_sessions')
          .update({
            'status': 'ended',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);

      // Mark absent students
      await _markAbsentStudents(sessionId);
    } catch (e) {
      throw AttendanceException('Failed to end session: $e');
    }
  }

  // ==================== Check-in Management ====================
  
  Future<AttendanceRecordModel> simpleCheckIn({
    required String sessionId,
    required WebcamConfigModel webcamConfig,
  }) async {
    try {
      final userEmail = _authService.getCurrentUserEmail();
      if (userEmail == null) {
        throw AttendanceException('User not authenticated');
      }

      // Validate session
      final session = await _validateSession(sessionId);
      
      // Check for existing record
      await _checkDuplicateRecord(sessionId, userEmail);
      
      // Get user profile
      final userProfile = await _getUserProfile(userEmail);
      
      // Capture image
      final webcamImage = await _captureWebcamImage(webcamConfig);
      
      // Determine status
      final checkInTime = DateTime.now();
      final status = session.isOnTime(checkInTime) ? 'present' : 'late';

      // Save record
      return await _saveAttendanceRecord(
        sessionId: sessionId,
        userEmail: userEmail,
        studentId: userProfile['school_id'],
        checkInTime: checkInTime,
        status: status,
      );
    } catch (e) {
      throw AttendanceException('Check-in failed: $e');
    }
  }

  // ==================== Reports ====================
  
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
      throw AttendanceException('Failed to get attendance records: $e');
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
      throw AttendanceException('Failed to get attendance sessions: $e');
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
      throw AttendanceException('Failed to get attendance history: $e');
    }
  }

  // ==================== Webcam Management ====================
  
  Future<bool> testWebcamConnection(WebcamConfigModel config) async {
    try {
      final response = await http.get(
        Uri.parse(config.captureUrl),
        headers: _getAuthHeaders(config),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Uint8List> captureImageFromWebcam(WebcamConfigModel config) async {
    try {
      final response = await http.get(
        Uri.parse(config.captureUrl),
        headers: _getAuthHeaders(config),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw AttendanceException('Failed to capture image: HTTP ${response.statusCode}');
      }

      return response.bodyBytes;
    } catch (e) {
      throw AttendanceException('Failed to capture webcam image: $e');
    }
  }

  // ==================== Private Helper Methods ====================
  
  Map<String, dynamic> _buildSessionData({
    required String classId,
    required String teacherEmail,
    required DateTime startTime,
    required int durationHours,
    required int onTimeLimitMinutes,
  }) {
    return {
      'class_id': classId,
      'teacher_email': teacherEmail,
      'start_time': startTime.toIso8601String(),
      'end_time': startTime.add(Duration(hours: durationHours)).toIso8601String(),
      'on_time_limit_minutes': onTimeLimitMinutes,
      'status': 'active',
      'created_at': startTime.toIso8601String(),
    };
  }

  Future<AttendanceSessionModel> _validateSession(String sessionId) async {
    final sessionResponse = await _supabase
        .from('attendance_sessions')
        .select()
        .eq('id', sessionId)
        .single();
    
    final session = AttendanceSessionModel.fromJson(sessionResponse);
    if (!session.isActive) {
      throw AttendanceException('Attendance session is not active');
    }
    
    return session;
  }

  Future<void> _checkDuplicateRecord(String sessionId, String userEmail) async {
    final existingRecord = await _supabase
        .from('attendance_records')
        .select()
        .eq('session_id', sessionId)
        .eq('student_email', userEmail)
        .maybeSingle();

    if (existingRecord != null) {
      throw AttendanceException('Already checked in for this session');
    }
  }

  Future<Map<String, dynamic>> _getUserProfile(String userEmail) async {
    final userProfile = await _authService.getUserProfile();
    if (userProfile == null) {
      throw AttendanceException('User profile not found');
    }
    return userProfile;
  }

  Future<Uint8List> _captureWebcamImage(WebcamConfigModel webcamConfig) async {
    return await captureImageFromWebcam(webcamConfig);
  }

  Future<AttendanceRecordModel> _saveAttendanceRecord({
    required String sessionId,
    required String userEmail,
    required String studentId,
    required DateTime checkInTime,
    required String status,
  }) async {
    final recordData = {
      'session_id': sessionId,
      'student_email': userEmail,
      'student_id': studentId,
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
  }

  Future<void> _markAbsentStudents(String sessionId) async {
    try {
      final sessionResponse = await _supabase
          .from('attendance_sessions')
          .select('class_id')
          .eq('id', sessionId)
          .single();

      final classId = sessionResponse['class_id'];

      // Get all students in class
      final studentsResponse = await _supabase
          .from('class_students')
          .select('student_email, users!inner(school_id)')
          .eq('class_id', classId);

      // Get students who already checked in
      final attendedResponse = await _supabase
          .from('attendance_records')
          .select('student_email')
          .eq('session_id', sessionId);

      final attendedEmails = attendedResponse.map((record) => record['student_email']).toSet();

      // Create absent records
      final absentRecords = <Map<String, dynamic>>[];
      for (final student in studentsResponse) {
        final studentEmail = student['student_email'];
        if (!attendedEmails.contains(studentEmail)) {
          absentRecords.add({
            'session_id': sessionId,
            'student_email': studentEmail,
            'student_id': student['users']['school_id'],
            'check_in_time': DateTime.now().toIso8601String(),
            'status': 'absent',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      if (absentRecords.isNotEmpty) {
        await _supabase.from('attendance_records').insert(absentRecords);
      }
    } catch (e) {
      // Log error but don't throw - marking absent is not critical
      print('Warning: Failed to mark absent students: $e');
    }
  }

  Map<String, String> _getAuthHeaders(WebcamConfigModel config) {
    final headers = <String, String>{};
    
    if (config.username.isNotEmpty && config.password.isNotEmpty) {
      final credentials = base64Encode(utf8.encode('${config.username}:${config.password}'));
      headers['Authorization'] = 'Basic $credentials';
    }
    
    return headers;
  }
}

// ==================== Custom Exceptions ====================

class AttendanceException implements Exception {
  final String message;
  
  AttendanceException(this.message);
  
  @override
  String toString() => 'AttendanceException: $message';
}
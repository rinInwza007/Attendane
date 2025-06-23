// lib/data/services/simple_attendance_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:myproject2/data/models/attendance_record_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_session_model.dart';
import '../models/webcam_config_model.dart';
import 'auth_service.dart';
import '';

class SimpleAttendanceService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // ==================== Attendance Session Management ====================
  
  /// สร้าง session การเช็คชื่อใหม่
  Future<AttendanceSessionModel> createAttendanceSession({
    required String classId,
    required int durationHours,
    required int onTimeLimitMinutes,
  }) async {
    try {
      final teacherEmail = _authService.getCurrentUserEmail();
      if (teacherEmail == null) {
        throw Exception('Teacher not authenticated');
      }

      // ตรวจสอบว่ามี session ที่ active อยู่แล้วหรือไม่
      final existingSession = await getActiveSessionForClass(classId);
      if (existingSession != null) {
        throw Exception('There is already an active attendance session for this class');
      }

      final now = DateTime.now();
      final sessionData = {
        'class_id': classId,
        'teacher_email': teacherEmail,
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

      print('✅ Attendance session created: ${response['id']}');
      return AttendanceSessionModel.fromJson(response);
    } catch (e) {
      print('❌ Error creating attendance session: $e');
      throw Exception('Failed to create attendance session: $e');
    }
  }

  /// ดึงข้อมูล session ที่ active สำหรับ class
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
      
      // ตรวจสอบว่า session หมดเวลาแล้วหรือไม่
      if (session.isEnded && session.status == 'active') {
        await endAttendanceSession(session.id);
        return null;
      }
      
      return session;
    } catch (e) {
      print('❌ Error getting active session: $e');
      return null;
    }
  }

  /// จบ session การเช็คชื่อ
  Future<void> endAttendanceSession(String sessionId) async {
    try {
      // อัปเดตสถานะ session
      await _supabase
          .from('attendance_sessions')
          .update({
            'status': 'ended',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);

      // ทำการอัปเดตสถานะนักเรียนที่ไม่ได้เช็คชื่อให้เป็น absent
      await _markAbsentStudents(sessionId);
      
      print('✅ Attendance session ended: $sessionId');
    } catch (e) {
      print('❌ Error ending attendance session: $e');
      throw Exception('Failed to end attendance session: $e');
    }
  }

  /// อัปเดตสถานะนักเรียนที่ไม่ได้เช็คชื่อให้เป็น absent
  Future<void> _markAbsentStudents(String sessionId) async {
    try {
      // ดึงข้อมูล session และรายชื่อนักเรียนในคลาส
      final sessionResponse = await _supabase
          .from('attendance_sessions')
          .select('class_id')
          .eq('id', sessionId)
          .single();

      final classId = sessionResponse['class_id'];

      // ดึงรายชื่อนักเรียนทั้งหมดในคลาส
      final studentsResponse = await _supabase
          .from('class_students')
          .select('student_email, users!inner(school_id)')
          .eq('class_id', classId);

      // ดึงรายชื่อนักเรียนที่เช็คชื่อแล้ว
      final attendedResponse = await _supabase
          .from('attendance_records')
          .select('student_email')
          .eq('session_id', sessionId);

      final attendedEmails = attendedResponse.map((record) => record['student_email']).toSet();

      // สร้างรายการ absent records
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
        print('✅ Marked ${absentRecords.length} students as absent');
      }
    } catch (e) {
      print('❌ Error marking absent students: $e');
    }
  }

  // ==================== Webcam Management ====================
  
  /// ทดสอบการเชื่อมต่อ webcam
  Future<bool> testWebcamConnection(WebcamConfigModel config) async {
    try {
      print('🔍 Testing webcam connection: ${config.streamUrl}');
      
      final response = await http.get(
        Uri.parse(config.captureUrl),
        headers: _getAuthHeaders(config),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Webcam connection test failed: $e');
      return false;
    }
  }

  /// จับภาพจาก webcam
  Future<Uint8List> captureImageFromWebcam(WebcamConfigModel config) async {
    try {
      print('📸 Capturing image from webcam: ${config.captureUrl}');
      
      final response = await http.get(
        Uri.parse(config.captureUrl),
        headers: _getAuthHeaders(config),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Failed to capture image: HTTP ${response.statusCode}');
      }

      return response.bodyBytes;
    } catch (e) {
      print('❌ Error capturing webcam image: $e');
      throw Exception('Failed to capture image from webcam: $e');
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

  // ==================== Simple Check-in (Without Face Recognition) ====================
  
  /// เช็คชื่อแบบง่าย โดยถ่ายรูปจาก webcam แต่ไม่ทำ face recognition
  Future<AttendanceRecordModel> simpleCheckIn({
    required String sessionId,
    required WebcamConfigModel webcamConfig,
  }) async {
    try {
      final userEmail = _authService.getCurrentUserEmail();
      if (userEmail == null) {
        throw Exception('User not authenticated');
      }

      print('🔄 Starting simple check-in...');

      // 1. ตรวจสอบ session
      final sessionResponse = await _supabase
          .from('attendance_sessions')
          .select()
          .eq('id', sessionId)
          .single();
      
      final session = AttendanceSessionModel.fromJson(sessionResponse);
      if (!session.isActive) {
        throw Exception('Attendance session is not active');
      }

      // 2. ตรวจสอบว่าเช็คชื่อแล้วหรือยัง
      final existingRecord = await _supabase
          .from('attendance_records')
          .select()
          .eq('session_id', sessionId)
          .eq('student_email', userEmail)
          .maybeSingle();

      if (existingRecord != null) {
        throw Exception('You have already checked in for this session');
      }

      // 3. ดึงข้อมูลผู้ใช้
      final userProfile = await _authService.getUserProfile();
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      // 4. จับภาพจาก webcam
      final webcamImage = await captureImageFromWebcam(webcamConfig);
      
      print('✅ Image captured successfully (${webcamImage.length} bytes)');

      // 5. กำหนดสถานะการเข้าเรียน
      final checkInTime = DateTime.now();
      final status = session.isOnTime(checkInTime) ? 'present' : 'late';

      // 6. บันทึก attendance record (ไม่มี face_match_score)
      final recordData = {
        'session_id': sessionId,
        'student_email': userEmail,
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

      print('✅ Attendance recorded successfully');
      return AttendanceRecordModel.fromJson(recordResponse);

    } catch (e) {
      print('❌ Error in simple check-in: $e');
      throw Exception('Check-in failed: $e');
    }
  }

  // ==================== Attendance Reports ====================
  
  /// ดึงรายงานการเข้าเรียนสำหรับ session
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
      print('❌ Error getting attendance records: $e');
      throw Exception('Failed to get attendance records: $e');
    }
  }

  /// ดึงรายชื่อ session ทั้งหมดสำหรับ class
  Future<List<AttendanceSessionModel>> getClassAttendanceSessions(String classId) async {
    try {
      final response = await _supabase
          .from('attendance_sessions')
          .select()
          .eq('class_id', classId)
          .order('start_time', ascending: false);

      return response.map((session) => AttendanceSessionModel.fromJson(session)).toList();
    } catch (e) {
      print('❌ Error getting class attendance sessions: $e');
      throw Exception('Failed to get attendance sessions: $e');
    }
  }

  /// ดึงประวัติการเข้าเรียนของนักเรียน
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
      print('❌ Error getting student attendance history: $e');
      throw Exception('Failed to get attendance history: $e');
    }
  }
}
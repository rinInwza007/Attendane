// lib/presentation/screens/attendance/simple_student_attendance_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:myproject2/data/models/attendance_record_model.dart';
import 'package:myproject2/data/models/attendance_session_model.dart';
import 'package:myproject2/data/models/webcam_config_model.dart';
import 'package:myproject2/data/services/attendance_service.dart';
import 'package:myproject2/data/services/auth_service.dart';


class SimpleStudentAttendanceScreen extends StatefulWidget {
  final String classId;
  final String className;

  const SimpleStudentAttendanceScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<SimpleStudentAttendanceScreen> createState() => _SimpleStudentAttendanceScreenState();
}

class _SimpleStudentAttendanceScreenState extends State<SimpleStudentAttendanceScreen> {
  final SimpleAttendanceService _attendanceService = SimpleAttendanceService();
  final AuthService _authService = AuthService();
  
  AttendanceSessionModel? _currentSession;
  AttendanceRecordModel? _myAttendanceRecord;
  List<AttendanceRecordModel> _myAttendanceHistory = [];
  Timer? _sessionCheckTimer;
  
  bool _isLoading = false;
  bool _isCheckingIn = false;
  Uint8List? _capturedImage;

  @override
  void initState() {
    super.initState();
    _loadCurrentSession();
    _loadAttendanceHistory();
    _startSessionMonitoring();
  }

  @override
  void dispose() {
    _sessionCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentSession() async {
    setState(() => _isLoading = true);
    
    try {
      final session = await _attendanceService.getActiveSessionForClass(widget.classId);
      
      if (mounted) {
        setState(() => _currentSession = session);
        
        if (session != null) {
          await _checkMyAttendanceRecord();
        }
      }
    } catch (e) {
      print('Error loading session: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkMyAttendanceRecord() async {
    if (_currentSession == null) return;

    try {
      final userEmail = _authService.getCurrentUserEmail();
      if (userEmail == null) return;

      final records = await _attendanceService.getAttendanceRecords(_currentSession!.id);
      final myRecord = records.where((r) => r.studentEmail == userEmail).firstOrNull;
      
      if (mounted) {
        setState(() => _myAttendanceRecord = myRecord);
      }
    } catch (e) {
      print('Error checking attendance record: $e');
    }
  }

  Future<void> _loadAttendanceHistory() async {
    try {
      final userEmail = _authService.getCurrentUserEmail();
      if (userEmail == null) return;

      final history = await _attendanceService.getStudentAttendanceHistory(userEmail);
      
      if (mounted) {
        setState(() => _myAttendanceHistory = history);
      }
    } catch (e) {
      print('Error loading attendance history: $e');
    }
  }

  void _startSessionMonitoring() {
    _sessionCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _loadCurrentSession();
    });
  }

  Future<void> _checkInWithPhoto() async {
    if (_currentSession == null || _myAttendanceRecord != null) return;

    // ขอการตั้งค่า webcam จากผู้ใช้
    final webcamConfig = await _showWebcamConfigDialog();
    if (webcamConfig == null) return;

    setState(() => _isCheckingIn = true);

    try {
      // ทดสอบการเชื่อมต่อ webcam ก่อน
      final connectionOk = await _attendanceService.testWebcamConnection(webcamConfig);
      if (!connectionOk) {
        throw Exception('Cannot connect to webcam. Please check IP address and port.');
      }

      // จับภาพจาก webcam
      final imageBytes = await _attendanceService.captureImageFromWebcam(webcamConfig);
      
      setState(() => _capturedImage = imageBytes);
      
      // แสดงภาพที่ถ่ายและขอยืนยัน
      final confirmed = await _showCapturedImageDialog(imageBytes);
      if (!confirmed) {
        setState(() => _capturedImage = null);
        return;
      }

      // ทำการเช็คชื่อ
      final record = await _attendanceService.simpleCheckIn(
        sessionId: _currentSession!.id,
        webcamConfig: webcamConfig,
      );

      if (mounted) {
        setState(() => _myAttendanceRecord = record);
        
        String message = 'Check-in successful!';
        Color backgroundColor = Colors.green;
        
        if (record.status == 'late') {
          message = 'Check-in successful, but you are marked as LATE.';
          backgroundColor = Colors.orange;
        }
        
        _showSnackBar(message, backgroundColor);
        _loadAttendanceHistory(); // รีเฟรชประวัติ
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Check-in Failed', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
          _capturedImage = null;
        });
      }
    }
  }

  Future<bool> _showCapturedImageDialog(Uint8List imageBytes) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Is this photo clear and shows your face properly?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Retake'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<WebcamConfigModel?> _showWebcamConfigDialog() async {
    final ipController = TextEditingController(text: '192.168.1.100');
    final portController = TextEditingController(text: '8080');
    bool isTestingConnection = false;
    bool connectionSuccess = false;

    return await showDialog<WebcamConfigModel>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Connect to Webcam'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, 
                               color: Colors.blue.shade700, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Instructions:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Ask your teacher for the webcam IP address\n'
                        '2. Enter the IP address below\n'
                        '3. Test connection before taking photo',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: ipController,
                  decoration: const InputDecoration(
                    labelText: 'IP Address',
                    hintText: '192.168.1.100',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.wifi),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '8080',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.settings_ethernet),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isTestingConnection ? null : () async {
                      setDialogState(() => isTestingConnection = true);
                      
                      try {
                        final config = WebcamConfigModel(
                          ipAddress: ipController.text.trim(),
                          port: int.tryParse(portController.text) ?? 8080,
                        );
                        
                        final success = await _attendanceService.testWebcamConnection(config);
                        
                        setDialogState(() {
                          connectionSuccess = success;
                          isTestingConnection = false;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Connection successful!' : 'Connection failed'),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isTestingConnection = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: isTestingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            connectionSuccess ? Icons.check_circle : Icons.wifi_find,
                            color: connectionSuccess ? Colors.green : null,
                          ),
                    label: Text(
                      isTestingConnection 
                          ? 'Testing...' 
                          : connectionSuccess 
                              ? 'Connected' 
                              : 'Test Connection',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: connectionSuccess ? () {
                final config = WebcamConfigModel(
                  ipAddress: ipController.text.trim(),
                  port: int.tryParse(portController.text) ?? 8080,
                  isConnected: true,
                );
                Navigator.of(context).pop(config);
              } : null,
              child: const Text('Take Photo'),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance - ${widget.className}'),
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCurrentSessionCard(),
                  const SizedBox(height: 16),
                  if (_capturedImage != null) _buildCapturedImageCard(),
                  if (_capturedImage != null) const SizedBox(height: 16),
                  _buildAttendanceHistoryCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentSessionCard() {
    if (_currentSession == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.schedule,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'No Active Attendance Session',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Wait for your teacher to start an attendance session.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final session = _currentSession!;
    final timeRemaining = session.endTime.difference(DateTime.now());
    final onTimeDeadline = session.onTimeDeadline;
    final isOnTimePeriod = DateTime.now().isBefore(onTimeDeadline);
    final hasCheckedIn = _myAttendanceRecord != null;

    return Card(
      color: hasCheckedIn 
          ? Colors.green.shade50 
          : isOnTimePeriod 
              ? Colors.blue.shade50 
              : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasCheckedIn 
                      ? Icons.check_circle 
                      : Icons.access_time,
                  color: hasCheckedIn 
                      ? Colors.green 
                      : isOnTimePeriod 
                          ? Colors.blue 
                          : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasCheckedIn 
                            ? 'Attendance Recorded' 
                            : 'Attendance Session Active',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Started: ${_formatTime(session.startTime)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (hasCheckedIn) ...[
              _buildAttendanceStatusCard(_myAttendanceRecord!),
            ] else ...[
              // Time info for students who haven't checked in
              Row(
                children: [
                  Expanded(
                    child: _buildTimeInfoChip(
                      'Time Remaining',
                      timeRemaining.isNegative 
                          ? 'Session Ended' 
                          : '${timeRemaining.inHours}h ${timeRemaining.inMinutes % 60}m',
                      timeRemaining.isNegative ? Colors.red : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTimeInfoChip(
                      isOnTimePeriod ? 'On-time Until' : 'Late Since',
                      _formatTime(onTimeDeadline),
                      isOnTimePeriod ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Check-in button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCheckingIn || !session.isActive 
                      ? null 
                      : _checkInWithPhoto,
                  icon: _isCheckingIn 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(
                    _isCheckingIn 
                        ? 'Taking Photo...' 
                        : session.isActive 
                            ? 'Check In with Photo' 
                            : 'Session Ended',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: session.isActive 
                        ? (isOnTimePeriod ? Colors.green : Colors.orange)
                        : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              
              if (!isOnTimePeriod && session.isActive)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '⚠️ You will be marked as LATE if you check in now',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCapturedImageCard() {
    if (_capturedImage == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Last Captured Photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _capturedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceStatusCard(AttendanceRecordModel record) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (record.status) {
      case 'present':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'PRESENT';
        break;
      case 'late':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        statusText = 'LATE';
        break;
      default:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'ABSENT';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: statusColor, size: 32),
              const SizedBox(width: 12),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Checked in at: ${_formatDateTime(record.checkInTime)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_myAttendanceHistory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No attendance history yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _myAttendanceHistory.length > 5 ? 5 : _myAttendanceHistory.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final record = _myAttendanceHistory[index];
                  return _buildHistoryTile(record);
                },
              ),
            
            if (_myAttendanceHistory.length > 5)
              TextButton(
                onPressed: () {
                  // TODO: Navigate to full history page
                },
                child: const Text('View All History'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTile(AttendanceRecordModel record) {
    Color statusColor;
    IconData statusIcon;
    
    switch (record.status) {
      case 'present':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'late':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
      case 'absent':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Icon(statusIcon, color: statusColor),
      title: Text(
        _formatDate(record.checkInTime),
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(_formatTime(record.checkInTime)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          record.status.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${_formatTime(dateTime)}';
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
// lib/screens/attendance/attendance_check_in_screen.dart
import 'package:flutter/material.dart';
import 'package:myproject2/data/services/api_service.dart';
import 'package:myproject2/data/models/webcam_config_model.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';




class AttendanceCheckInScreen extends StatefulWidget {
  final String sessionId;
  final String studentEmail;

  const AttendanceCheckInScreen({
    Key? key,
    required this.sessionId,
    required this.studentEmail,
  }) : super(key: key);

  @override
  State<AttendanceCheckInScreen> createState() => _AttendanceCheckInScreenState();
}

class _AttendanceCheckInScreenState extends State<AttendanceCheckInScreen> {
  final ApiService _apiService = ApiService();
  final _ipController = TextEditingController(text: '192.168.1.10');
  final _portController = TextEditingController(text: '8080');
  
  bool _isLoading = false;
  String? _statusMessage;
  File? _capturedImage;

  // ตัวอย่างการลงทะเบียนใบหน้า
  Future<void> _registerFace() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      
      if (pickedFile == null) return;
      
      setState(() => _isLoading = true);
      
      final result = await _apiService.registerFace(
        imagePath: pickedFile.path,
        studentId: 'STD001', // ดึงจาก user profile
        studentEmail: widget.studentEmail,
      );
      
      setState(() {
        _statusMessage = 'Face registered successfully!';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Face registered with quality score: ${result['quality_score']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // เช็คชื่อด้วย IP Webcam
  Future<void> _checkInWithWebcam() async {
    try {
      setState(() => _isLoading = true);
      
      final webcamConfig = WebcamConfigModel(
        ipAddress: _ipController.text,
        port: int.parse(_portController.text),
      );
      
      // เช็คชื่อพร้อม face recognition
      final result = await _apiService.checkInWithFaceRecognition(
        sessionId: widget.sessionId,
        studentEmail: widget.studentEmail,
        webcamConfig: webcamConfig,
      );
      
      setState(() {
        _statusMessage = result['message'];
      });
      
      // แสดงผลลัพธ์
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            result['status'] == 'present' ? 'Check-in Successful' : 'Late Check-in',
            style: TextStyle(
              color: result['status'] == 'present' ? Colors.green : Colors.orange,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                result['status'] == 'present' ? Icons.check_circle : Icons.warning,
                size: 64,
                color: result['status'] == 'present' ? Colors.green : Colors.orange,
              ),
              SizedBox(height: 16),
              Text('Status: ${result['status']}'),
              Text('Time: ${DateTime.parse(result['check_in_time']).toLocal()}'),
              if (result['face_match_score'] != null)
                Text('Face Match: ${(result['face_match_score'] * 100).toStringAsFixed(1)}%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Check-in failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ทดสอบจับภาพจาก Webcam
  Future<void> _testCaptureWebcam() async {
    try {
      setState(() => _isLoading = true);
      
      final webcamConfig = WebcamConfigModel(
        ipAddress: _ipController.text,
        port: int.parse(_portController.text),
      );
      
      final imageBytes = await _apiService.captureFromWebcam(webcamConfig);
      
      // บันทึกภาพชั่วคราว
      final tempDir = await Directory.systemTemp.createTemp();
      final file = File('${tempDir.path}/capture.jpg');
      await file.writeAsBytes(imageBytes);
      
      setState(() {
        _capturedImage = file;
        _statusMessage = 'Image captured successfully';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Capture failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Recognition Check-in'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // IP Webcam Configuration
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IP Webcam Configuration',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _ipController,
                      decoration: InputDecoration(
                        labelText: 'IP Address',
                        hintText: '192.168.1.10',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _portController,
                      decoration: InputDecoration(
                        labelText: 'Port',
                        hintText: '8080',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Action Buttons
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testCaptureWebcam,
              icon: Icon(Icons.camera_alt),
              label: Text('Test Capture'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _checkInWithWebcam,
              icon: Icon(Icons.check_circle),
              label: Text('Check In with Face Recognition'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
            ),
            
            SizedBox(height: 8),
            
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _registerFace,
              icon: Icon(Icons.face),
              label: Text('Register Face'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            // Status Display
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            
            // Captured Image Preview
            if (_capturedImage != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Card(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _capturedImage!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            
            // Loading Indicator
            if (_isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _apiService.dispose();
    super.dispose();
  }
}
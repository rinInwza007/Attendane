// lib/presentation/common_widgets/image_picker_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImagePickerScreen extends StatefulWidget {
  final Function(String imagePath)? onImageCaptured;
  final String? instructionText;

  const ImagePickerScreen({
    super.key,
    this.onImageCaptured,
    this.instructionText,
  });

  @override
  ImagePickerScreenState createState() => ImagePickerScreenState();
}

class ImagePickerScreenState extends State<ImagePickerScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _imagePath;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกรูปภาพใบหน้า'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // คำแนะนำ
            if (widget.instructionText != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(child: Text(widget.instructionText!)),
                      ],
                    ),
                  ),
                ),
              ),

            // แสดงรูปภาพที่เลือก หรือข้อความแนะนำถ้ายังไม่ได้เลือก
            Expanded(
              child: _imagePath == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'ยังไม่ได้เลือกรูปภาพ',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 24),
                         ElevatedButton.icon(
  onPressed: _isProcessing
      ? null
      : () {
          if (_imagePath != null) {
            final imagePath = _imagePath; // เก็บค่าไว้ในตัวแปรชั่วคราว
            // ออกจากหน้าจอก่อนที่จะเรียก callback
            Navigator.of(context).pop(imagePath);
            // เรียก callback หลังจาก pop แล้ว
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onImageCaptured?.call(imagePath!);
            });
          }
        },
  icon: const Icon(Icons.check),
  label: const Text('ยืนยัน'),
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 16,
    ),
    backgroundColor: Colors.green,
  ),
)
                        ],
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        // แสดงรูปภาพที่เลือก
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_imagePath!),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        
                        // ปุ่มลบรูปภาพ
                        Positioned(
                          top: 24,
                          right: 24,
                          child: CircleAvatar(
                            backgroundColor: Colors.red.withOpacity(0.7),
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _imagePath = null;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            // ปุ่มควบคุม
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_imagePath == null)
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _pickImageFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('เลือกรูปภาพ'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isProcessing ? null : _pickImageFromGallery,
                          icon: const Icon(Icons.refresh),
                          label: const Text('เลือกใหม่'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () {
                                  if (_imagePath != null) {
                                    widget.onImageCaptured?.call(_imagePath!);
                                    Navigator.of(context).pop(_imagePath);
                                  }
                                },
                          icon: const Icon(Icons.check),
                          label: const Text('ยืนยัน'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            
            // แสดง loading ถ้ากำลังประมวลผล
            if (_isProcessing)
              Container(
                padding: const EdgeInsets.only(bottom: 20),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ฟังก์ชันเลือกรูปภาพจากคลัง
  Future<void> _pickImageFromGallery() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // คัดลอกรูปภาพไปยังไดเรกทอรีแอป
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imageName = 'face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(appDir.path, imageName);
      
      // คัดลอกไฟล์
      final File originalFile = File(image.path);
      await originalFile.copy(filePath);

      setState(() {
        _imagePath = filePath;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e')),
        );
      }
    }
  }
}
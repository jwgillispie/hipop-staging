import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart'; // Disabled for now

class PhotoUploadWidget extends StatefulWidget {
  final Function(File) onPhotoSelected;
  final String? initialImagePath;

  const PhotoUploadWidget({
    super.key,
    required this.onPhotoSelected,
    this.initialImagePath,
  });

  @override
  State<PhotoUploadWidget> createState() => _PhotoUploadWidgetState();
}

class _PhotoUploadWidgetState extends State<PhotoUploadWidget> {
  File? _selectedImage;
  // final ImagePicker _picker = ImagePicker(); // Disabled for now

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      _selectedImage = File(widget.initialImagePath!);
    }
  }

  void _showDisabledDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Photo Upload Disabled'),
          content: const Text('Photo upload functionality is temporarily disabled and will be available in a future update.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: _selectedImage != null
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _showDisabledDialog,
                    ),
                  ),
                ),
              ],
            )
          : InkWell(
              onTap: _showDisabledDialog,
              borderRadius: BorderRadius.circular(12),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Photo Upload Disabled',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Photo upload feature temporarily disabled',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}
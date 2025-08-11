import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../premium/models/user_subscription.dart';
import '../../../premium/services/subscription_service.dart';
import '../../../premium/widgets/upgrade_prompt_widget.dart';

class PhotoUploadWidget extends StatefulWidget {
  final Function(List<File>) onPhotosSelected;
  final List<String>? initialImagePaths;
  final String? userId;
  final String? userType;

  const PhotoUploadWidget({
    super.key,
    required this.onPhotosSelected,
    this.initialImagePaths,
    this.userId,
    this.userType,
  });

  @override
  State<PhotoUploadWidget> createState() => _PhotoUploadWidgetState();
}

class _PhotoUploadWidgetState extends State<PhotoUploadWidget> {
  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  UserSubscription? _subscription;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePaths != null) {
      _selectedImages = widget.initialImagePaths!
          .map((path) => File(path))
          .toList();
    }
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    if (widget.userId != null) {
      try {
        final subscription = await SubscriptionService.getUserSubscription(widget.userId!);
        setState(() {
          _subscription = subscription;
        });
      } catch (e) {
        debugPrint('Error loading subscription: $e');
      }
    }
  }

  Future<void> _handleAddPhoto() async {
    if (_isLoading) return;

    final currentCount = _selectedImages.length;
    final limit = _getPhotoLimit();
    final isUnlimited = limit == -1;

    // Check limit for free users
    if (!isUnlimited && currentCount >= limit) {
      _showUpgradePrompt();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        setState(() {
          _selectedImages.add(file);
        });
        widget.onPhotosSelected(_selectedImages);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    widget.onPhotosSelected(_selectedImages);
  }

  int _getPhotoLimit() {
    if (_subscription?.isVendorPro == true) {
      return -1; // Unlimited for Vendor Pro
    }
    return _subscription?.getLimit('photo_uploads_per_post') ?? 3;
  }

  void _showUpgradePrompt() {
    ContextualUpgradePrompts.showLimitReachedPrompt(
      context,
      userId: widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
      userType: widget.userType ?? 'vendor',
      limitName: 'photos per post',
      currentUsage: _selectedImages.length,
      limit: 3,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        if (_selectedImages.isNotEmpty) _buildPhotoGrid(),
        _buildAddPhotoSection(),
      ],
    );
  }

  Widget _buildHeader() {
    final limit = _getPhotoLimit();
    final isUnlimited = limit == -1;
    final count = _selectedImages.length;

    return Row(
      children: [
        Text(
          'Photos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        if (_subscription?.isVendorPro == true)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star,
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                const Text(
                  'UNLIMITED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        Text(
          isUnlimited ? '$count photos' : '$count/$limit photos',
          style: TextStyle(
            fontSize: 14,
            color: isUnlimited 
                ? Colors.green[600]
                : count >= limit 
                    ? Colors.red[600] 
                    : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoGrid() {
    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImages[index],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () => _removePhoto(index),
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddPhotoSection() {
    final limit = _getPhotoLimit();
    final isUnlimited = limit == -1;
    final count = _selectedImages.length;
    final canAddMore = isUnlimited || count < limit;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: _isLoading ? null : (canAddMore ? _handleAddPhoto : _showUpgradePrompt),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(
              color: canAddMore ? Colors.blue.shade300 : Colors.grey.shade300,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(12),
            color: canAddMore ? Colors.blue.shade50 : Colors.grey.shade50,
          ),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      canAddMore ? Icons.add_photo_alternate : Icons.lock,
                      size: 32,
                      color: canAddMore ? Colors.blue[600] : Colors.grey[600],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canAddMore 
                          ? 'Add Photo' 
                          : 'Upgrade for unlimited photos',
                      style: TextStyle(
                        fontSize: 14,
                        color: canAddMore ? Colors.blue[600] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!canAddMore) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Vendor Pro: \$29/month',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Legacy single photo upload widget for backward compatibility
class SinglePhotoUploadWidget extends StatefulWidget {
  final Function(File) onPhotoSelected;
  final String? initialImagePath;

  const SinglePhotoUploadWidget({
    super.key,
    required this.onPhotoSelected,
    this.initialImagePath,
  });

  @override
  State<SinglePhotoUploadWidget> createState() => _SinglePhotoUploadWidgetState();
}

class _SinglePhotoUploadWidgetState extends State<SinglePhotoUploadWidget> {
  @override
  Widget build(BuildContext context) {
    return PhotoUploadWidget(
      onPhotosSelected: (photos) {
        if (photos.isNotEmpty) {
          widget.onPhotoSelected(photos.first);
        }
      },
      initialImagePaths: widget.initialImagePath != null ? [widget.initialImagePath!] : null,
    );
  }
}
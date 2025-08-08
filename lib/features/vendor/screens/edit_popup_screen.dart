import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../repositories/vendor_posts_repository.dart';
import '../models/vendor_post.dart';
import '../../shared/screens/create_popup_screen.dart';

/// A dedicated screen for editing existing popup posts.
/// This screen provides a seamless editing experience for vendors
/// to modify their existing popup details.
class EditPopupScreen extends StatelessWidget {
  final VendorPost vendorPost;

  const EditPopupScreen({
    super.key,
    required this.vendorPost,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Edit popup screen for ${vendorPost.description}',
      child: CreatePopUpScreen(
        postsRepository: context.read<IVendorPostsRepository>(),
        editingPost: vendorPost,
      ),
    );
  }
}
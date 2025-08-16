import 'package:flutter/material.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/vendor/widgets/vendor/central_popup_creation_widget.dart';

class VendorPopupCreationScreen extends StatelessWidget {
  const VendorPopupCreationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Pop-Up'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HiPopColors.secondarySoftSage,
                HiPopColors.accentMauve,
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: CentralPopupCreationWidget(),
      ),
    );
  }
}
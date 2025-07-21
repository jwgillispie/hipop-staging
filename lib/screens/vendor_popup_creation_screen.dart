import 'package:flutter/material.dart';
import '../widgets/vendor/central_popup_creation_widget.dart';

class VendorPopupCreationScreen extends StatelessWidget {
  const VendorPopupCreationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Pop-Up'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: CentralPopupCreationWidget(),
      ),
    );
  }
}
import 'package:flutter/material.dart';

class RecipeManagementScreen extends StatelessWidget {
  const RecipeManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Management'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Recipe Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Create and manage recipes featuring your market vendors.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
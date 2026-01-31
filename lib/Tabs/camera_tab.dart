import 'package:flutter/material.dart';
import '../Pages/camera/editing/camera_menu_page.dart';

class CameraTab extends StatelessWidget {
  const CameraTab({super.key});

  @override
  Widget build(BuildContext context) {
    return CameraMenuPage(title: 'Camera');
  }
}
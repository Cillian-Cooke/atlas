import 'package:flutter/material.dart';
import '../Pages/camera_page.dart';

class CameraTab extends StatelessWidget {
  const CameraTab({super.key});

  @override
  Widget build(BuildContext context) {
    return CameraPage(title: 'Camera');
  }
}
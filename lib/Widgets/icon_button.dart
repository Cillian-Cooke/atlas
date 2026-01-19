import 'package:flutter/material.dart';

class IconButtonWidget extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double iconSize;
  final double buttonSize;
  final double elevation;
  final double borderRadius;

  const IconButtonWidget({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconSize = 40,
    this.buttonSize = 70,
    this.elevation = 10,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? const Color.fromARGB(255, 30, 30, 30) : Colors.white,
        padding: const EdgeInsets.all(1),
        elevation: elevation,
        maximumSize: Size(buttonSize, buttonSize),
        minimumSize: Size(buttonSize, buttonSize),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      onPressed: onPressed,
      child: Icon(
        icon,
        size: iconSize,
        color:  isDark ? Colors.white : Colors.black,
      ),
    );
  }
}
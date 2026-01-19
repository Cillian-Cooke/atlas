import 'package:flutter/material.dart';

class LabeledBox extends StatelessWidget {

  final String title;
  final String value;
  final Color backgroundColor;

  const LabeledBox({
    super.key,
    required this.title,
    required this.value,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color.fromARGB(255, 100, 100, 100) : Colors.black;
    final finalBgColor = backgroundColor == Colors.white && isDark
        ? const Color.fromARGB(255, 40, 40, 40)
        : backgroundColor;
    final textColor = isDark && backgroundColor == Colors.white ? Colors.white : Colors.black;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // OUTER container (no border radius curve issue)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(1.2),  // thickness of border
          decoration: BoxDecoration(
            color: borderColor,               // border color
            borderRadius: BorderRadius.circular(8),
          ),

          child: Container(
            decoration: BoxDecoration(
              color: finalBgColor,          // inside box color
              borderRadius: BorderRadius.circular(7), // slightly smaller radius
            ),

            padding: const EdgeInsets.only(
              left: 12,
              right: 10,
              top: 10,
              bottom: 10,
            ),

            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                value,
                style: TextStyle(fontSize: 14, color: textColor),
              ),
            ),
          ),
        ),

        // FLOATING LABEL
        Positioned(
          left: 20,
          top: -10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: finalBgColor, // matches inner box
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

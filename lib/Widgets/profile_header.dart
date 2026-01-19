import 'package:flutter/material.dart';

class ProfileHeaderWidget extends StatelessWidget {
  final String header;
  final String subheading;
  final VoidCallback onTap;
  final Color circleColor;
  final Color shadowColor;
  final double height;
  final double width;
  final double borderRadius;
  final double circleSize;
  final double headerFontSize;
  final double subheadingFontSize;

  const ProfileHeaderWidget({
    super.key,
    required this.header,
    required this.subheading,
    required this.onTap,
    this.circleColor = Colors.blue,
    this.shadowColor = const Color.fromARGB(255, 87, 87, 87),
    this.height = 50,
    this.width = 180,
    this.borderRadius = 30,
    this.circleSize = 40,
    this.headerFontSize = 15,
    this.subheadingFontSize = 10,
  });

  @override
  Widget build(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: isDark ? const Color.fromARGB(255, 30, 30, 30)  : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.all(5),
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  header,
                  style: TextStyle(
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subheading,
                  style: TextStyle(
                    fontSize: subheadingFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
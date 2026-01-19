import 'package:flutter/material.dart';

class PopupContainer extends StatelessWidget {
  final Widget child;

  const PopupContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dark theme colors
    const darkBgColor = Color.fromARGB(255, 30, 30, 30);
    const darkTextColor = Colors.white;
    const darkBorderColor = Color.fromARGB(255, 50, 50, 50);
    const darkShadowColor = Color.fromARGB(100, 0, 0, 0);

    // Light theme colors
    const lightBgColor = Color.fromARGB(255, 255, 255, 255);
    const lightTextColor = Colors.black;
    const lightBorderColor = Color.fromARGB(255, 220, 220, 220);
    const lightShadowColor = Color.fromARGB(50, 0, 0, 0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The reusable popup shell
          Container(
            height: size.height * 0.9,
            width: size.width * 0.9,
            decoration: BoxDecoration(
              color: isDark ? darkBgColor : lightBgColor,
              border: Border.all(
                color: isDark ? darkBorderColor : lightBorderColor,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDark ? darkShadowColor : lightShadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),

          // Close button
          Positioned(
            top: -15,
            right: -15,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(1),
                elevation: 20,
                shadowColor: isDark ? darkShadowColor : lightShadowColor,
                backgroundColor: isDark ? darkBgColor : lightBgColor,
                maximumSize: const Size(70, 70),
                minimumSize: const Size(70, 70),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isDark ? darkBorderColor : lightBorderColor,
                    width: 1,
                  ),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Icon(
                Icons.close,
                size: 40,
                color: isDark ? darkTextColor : lightTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

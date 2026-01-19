import 'package:flutter/material.dart';

class TitleHeaderWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color circleColor;
  final Color shadowColor;
  final double height;
  final double width;
  final double borderRadius;
  final double circleSize;
  final double headerFontSize;
  final double subheadingFontSize;

  const TitleHeaderWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.backgroundColor = Colors.white,
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
    final finalBgColor = backgroundColor == Colors.white && isDark
        ? const Color.fromARGB(255, 40, 40, 40)
        : backgroundColor;
    final textColor = isDark && backgroundColor == Colors.white ? Colors.white : Colors.black;
    final iconColor = isDark && backgroundColor == Colors.white ? Colors.white : Colors.black;
    
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: finalBgColor,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black45 : shadowColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// 🔙 Back Button
            InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_back,
                  size: 22,
                  color: iconColor,
                ),
              ),
            ),

            /// Divider
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: isDark ? Colors.white.withOpacity(0.2) : const Color.fromARGB(255, 59, 59, 59).withOpacity(0.3),
            ),

            /// 📝 Text Area (Tappable)
            Flexible(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: headerFontSize,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: subheadingFontSize,
                          color: isDark ? Colors.grey[400] : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
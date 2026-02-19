import 'package:flutter/material.dart';

class LabeledBox extends StatefulWidget {
  final String title;
  final String value;
  final Color backgroundColor;
  final int maxLength;
  const LabeledBox({
    super.key,
    required this.title,
    required this.value,
    this.backgroundColor = Colors.white,
    this.maxLength = 80,
  });

  @override
  State<LabeledBox> createState() => _LabeledBoxState();
}

class _LabeledBoxState extends State<LabeledBox> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color.fromARGB(255, 100, 100, 100) : Colors.black;
    final finalBgColor = widget.backgroundColor == Colors.white && isDark
        ? const Color.fromARGB(255, 40, 40, 40)
        : widget.backgroundColor;
    final textColor = isDark && widget.backgroundColor == Colors.white ? Colors.white : Colors.black;
    
    // Check if text exceeds max length
    final bool needsExpansion = widget.value.length > widget.maxLength;
    
    // Get the text to display
    String displayText;
    if (needsExpansion && !_isExpanded) {
      // Truncate at maxLength and find the last space to avoid cutting words
      String truncated = widget.value.substring(0, widget.maxLength);
      int lastSpace = truncated.lastIndexOf(' ');
      if (lastSpace > 0 && lastSpace > widget.maxLength - 20) {
        truncated = truncated.substring(0, lastSpace);
      }
      displayText = '$truncated...';
    } else {
      displayText = widget.value;
    }
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // OUTER container (no border radius curve issue)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(1.2), // thickness of border
          decoration: BoxDecoration(
            color: borderColor, // border color
            borderRadius: BorderRadius.circular(8),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: finalBgColor,
              borderRadius: BorderRadius.circular(7),
            ),
            padding: const EdgeInsets.only(
              left: 12,
              right: 10,
              top: 10,
              bottom: 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main text
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    displayText,
                    style: TextStyle(fontSize: 14, color: textColor),
                  ),
                ),
                
                // "Read more" / "Show less" button
                if (needsExpansion)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Text(
                        _isExpanded ? 'Show less' : 'Read more',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.blue[300] : Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
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
              widget.title,
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
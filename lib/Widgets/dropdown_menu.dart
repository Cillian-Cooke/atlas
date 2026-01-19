import 'package:flutter/material.dart';

/// A menu item for the dropdown
class DropdownMenuItemData {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  DropdownMenuItemData({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

/// A reusable dropdown menu that positions itself below a trigger widget
class DropdownMenuController {
  OverlayEntry? _overlayEntry;
  final GlobalKey triggerKey;
  final List<DropdownMenuItemData> items;
  final double width;
  final Color backgroundColor;
  final double borderRadius;
  final BuildContext context;

  DropdownMenuController({
    required this.triggerKey,
    required this.items,
    required this.context,
    this.width = 250,
    this.backgroundColor = Colors.white,
    this.borderRadius = 12,
  });

  bool get isOpen => _overlayEntry != null;

  void toggle() {
    if (isOpen) {
      close();
    } else {
      show();
    }
  }

  /// Static helper method to quickly show a dropdown menu
  static void showDropdown({
    required BuildContext context,
    required GlobalKey triggerKey,
    required List<DropdownMenuItemData> items,
    double width = 250,
    Color backgroundColor = Colors.white,
    double borderRadius = 12,
  }) {
    final controller = DropdownMenuController(
      triggerKey: triggerKey,
      context: context,
      width: width,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      items: items,
    );
    controller.show();
  }

  void show() {
    if (_overlayEntry != null) return;

    final RenderBox? renderBox = triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finalBgColor = backgroundColor == Colors.white && isDark
        ? const Color.fromARGB(255, 40, 40, 40)
        : backgroundColor;

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: close,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 5,
              width: width,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(borderRadius),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: finalBgColor,
                    borderRadius: BorderRadius.circular(borderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black45 : Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      children: items.map((item) => _buildMenuItem(item)).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildMenuItem(DropdownMenuItemData item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        close();
        item.onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void dispose() {
    close();
  }
}
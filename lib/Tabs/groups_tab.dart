import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Pages/groups_page.dart';
import '../PopUps/map_menu_popup.dart';
import '../Widgets/profile_header.dart';
import '../Widgets/dropdown_menu.dart';
import '../Widgets/icon_button.dart';
import '../PopUps/dropdown_popups/edit_profile.dart';
import '../PopUps/dropdown_popups/settings.dart';
import '../Map_And_Bubbles/user_map_page.dart';
import '../PopUps/edit/filter_groups_popup.dart';

class GroupsTab extends StatefulWidget {
  final void Function(List<String>)? onCaptureBubbles;

  const GroupsTab({super.key, this.onCaptureBubbles});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  String? _username;
  String? _usersID;
  bool _isLoading = true;
  final GlobalKey _profileHeaderKey = GlobalKey();
  DropdownMenuController? _dropdownController;
  
  static const String userId = "I8PwtNA3QTEt44rxH8jN";

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  @override
  void dispose() {
    _dropdownController?.dispose();
    super.dispose();
  }

  void _showDropdownMenu(List<DropdownMenuItemData> items) {
    _dropdownController?.dispose();
    
    _dropdownController = DropdownMenuController(
      triggerKey: _profileHeaderKey,
      context: context,
      width: 250,
      backgroundColor: Colors.white,
      borderRadius: 12,
      items: items,
    );
    
    _dropdownController?.toggle();
  }

  Future<void> _loadUsername() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .get(GetOptions(source: Source.server));

      if (mounted) {
        setState(() {
          final data = doc.data();
          String username = 'Unknown User';
          String userIdFromFirestore = 'Unknown User';

          if (data is Map<String, dynamic>) {
            final usernameFromFirestore = data['username'] ?? data['name'] ?? data['displayName'];
            if (usernameFromFirestore is String && usernameFromFirestore.isNotEmpty) {
              username = usernameFromFirestore;
            }

            final usersID = data['userID'] ?? data['ID'] ?? data['UserID'];
            if (usersID is String && usersID.isNotEmpty) {
              userIdFromFirestore = usersID;
            }
          }

          _username = username;
          _usersID = userIdFromFirestore;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _username = "Error loading";
          _usersID = "Error loading";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleProfileMapTap() async {
    final result = await showMapMenuPopUp(context, userId);

    if (result != null && result is Map && result['action'] == 'openMap') {
      final capturedPostIds = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (context) => UserMapPage(
            userId: result['userId'],
            userName: result['userName'],
          ),
        ),
      );

      if (capturedPostIds != null && capturedPostIds.isNotEmpty && mounted) {
        widget.onCaptureBubbles?.call(capturedPostIds);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Captured ${capturedPostIds.length} posts from ${result['userName']}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
          GroupsPage(
            title: 'Groups',
            onCaptureBubbles: widget.onCaptureBubbles,
          ),

        // Name plate
        Positioned(
          top: 10,
          left: 8,
          child: ProfileHeaderWidget(
            key: _profileHeaderKey,
            header: _isLoading ? "Loading..." : (_username ?? "No username"),
            subheading: _isLoading ? "Loading..." : (_usersID ?? "No ID"),
            onTap: () => _showDropdownMenu([
              DropdownMenuItemData(
                label: 'Profile Map',
                icon: Icons.map,
                onTap: _handleProfileMapTap,
              ),
              DropdownMenuItemData(
                label: 'Settings',
                icon: Icons.settings,
                onTap: () {
                  showSettingsPopUp(context);
                },
              ),
              DropdownMenuItemData(
                label: 'Edit Profile',
                icon: Icons.edit,
                onTap: () {
                  showEditProfilePopUp(context);
                },
              ),
              DropdownMenuItemData(
                label: 'Logout',
                icon: Icons.logout,
                onTap: () => showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: const Text('Log out'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: const Text('OK'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'Cancel'),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
        Positioned(
          top: 10,
          right: 8,
          child: IconButtonWidget(
            icon: Icons.menu,
            onPressed: () {
              showFilterGroupsPopUp(context);
            },
            buttonSize: 70,
          ),
        )
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../Pages/groups_page.dart';
import '../Pages/login_page.dart';
import '../PopUps/map_menu_popup.dart';
import '../Widgets/profile_header.dart';
import '../Widgets/dropdown_menu.dart';
import '../Widgets/icon_button.dart';
import '../PopUps/dropdown_popups/edit_profile.dart';
import '../PopUps/dropdown_popups/settings.dart';
import '../Map_And_Bubbles/user_map_page.dart';
import '../PopUps/edit/filter_groups_popup.dart';
import '../Services/auth_provider.dart' as auth_provider;

class GroupsTab extends StatefulWidget {
  final void Function(List<String>)? onCaptureBubbles;

  const GroupsTab({super.key, this.onCaptureBubbles});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  String? _username;
  String? _profileSubheading;
  String? _profileImageUrl;
  bool _isLoading = true;
  final GlobalKey _profileHeaderKey = GlobalKey();
  DropdownMenuController? _dropdownController;

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

  static void _emptyCallback() {
    // Empty callback for LoginScreen navigation
  }

  Future<void> _loadUsername() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }
      final userId = user.uid;
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .get(GetOptions(source: Source.server));

      if (mounted) {
        setState(() {
          final data = doc.data();
          String username = 'Unknown User';
          String profileSubheading = 'Complete your profile';
          String? profileImageUrl;

          if (data is Map<String, dynamic>) {
            final usernameFromFirestore = data['username'];
            if (usernameFromFirestore is String && usernameFromFirestore.isNotEmpty) {
              username = usernameFromFirestore;
            }

            final subheading = data['profileSubheading'];
            if (subheading is String && subheading.isNotEmpty) {
              profileSubheading = subheading;
            }

            final imageUrl = data['profileImageUrl'];
            if (imageUrl is String && imageUrl.isNotEmpty) {
              profileImageUrl = imageUrl;
            }
          }

          _username = username;
          _profileSubheading = profileSubheading;
          _profileImageUrl = profileImageUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _username = "Error loading";
          _profileSubheading = "Error loading";
          _profileImageUrl = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleProfileMapTap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final userId = user.uid;
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
          top: 50,
          left: 8,
          child: ProfileHeaderWidget(
            key: _profileHeaderKey,
            header: _isLoading ? "Loading..." : (_username ?? "No username"),
            subheading: _isLoading ? "Loading..." : (_profileSubheading ?? "Complete your profile"),
            profileImageUrl: _profileImageUrl,
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
                onTap: () async {
                  final result = await showDialog<String>(
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
                  );
                  
                  if (result == 'OK' && mounted) {
                    await context.read<auth_provider.AuthProvider>().signOut();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen(onLoginSuccess: _emptyCallback)),
                        (route) => false,
                      );
                    }
                  }
                },
              ),
            ]),
          ),
        ),
        Positioned(
          top: 50,
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
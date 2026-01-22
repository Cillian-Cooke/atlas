import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Pages/home_page.dart';
import '../PopUps/edit/filter_map_popup.dart';
import '../PopUps/map_menu_popup.dart';
import '../Widgets/icon_button.dart';
import '../Widgets/profile_header.dart';
import '../Widgets/dropdown_menu.dart';
import '../Widgets/zoom_slider.dart';
import '../PopUps/dropdown_popups/edit_profile.dart';
import '../PopUps/dropdown_popups/settings.dart';
import '../PopUps/edit/edit_map.dart';
import '../Map_And_Bubbles/user_map_page.dart';

class HomeTab extends StatefulWidget {
  final void Function(List<String>)? onCaptureBubbles;
  final void Function(List<String>)? onCapturePostIds;

  const HomeTab({
    super.key, 
    this.onCaptureBubbles,
    this.onCapturePostIds,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _username;
  String? _usersID;
  bool _isLoading = true;
  final GlobalKey<HomePageState> _homePageKey = GlobalKey<HomePageState>();
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
      borderRadius: 12,
      items: items,
    );
    
    _dropdownController?.toggle();
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

          print("Fetched user data: $data");
          print("Username: $username, UserID: $userIdFromFirestore");

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

  void _handleCapturePostIds(List<String> postIds) {
    print('Captured ${postIds.length} post IDs in HomeTab: $postIds');
    if (widget.onCapturePostIds != null) {
      widget.onCapturePostIds!(postIds);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Captured ${postIds.length} posts'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleProfileMapTap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final userId = user.uid;
    // Show the popup
    final result = await showMapMenuPopUp(context, userId);

    // Check if user wants to open the map
    if (result != null && result is Map && result['action'] == 'openMap') {
      print('📍 Opening UserMapPage for user: ${result['userName']}');
      
      // Navigate to the map from the parent context
      final capturedPostIds = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (context) => UserMapPage(
            userId: result['userId'],
            userName: result['userName'],
          ),
        ),
      );

      print('📍 Returned from UserMapPage with: $capturedPostIds');

      if (capturedPostIds != null && capturedPostIds.isNotEmpty && mounted) {
        print('✅ Processing ${capturedPostIds.length} captured posts: $capturedPostIds');
        
        // Call both callbacks if provided
        widget.onCaptureBubbles?.call(capturedPostIds);
        widget.onCapturePostIds?.call(capturedPostIds);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Captured ${capturedPostIds.length} posts from ${result['userName']}'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View Feed',
              onPressed: () {
                print('🚀 Navigate to feed with: $capturedPostIds');
              },
            ),
          ),
        );
      } else {
        print('❌ No post IDs received or list was empty');
      }
    }
  }
  

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';
    
    return Stack(
      children: [
        HomePage(
          key: _homePageKey,
          title: 'Home',
          userId: userId,
          onCaptureBubbles: widget.onCaptureBubbles,
          onCapturePostIds: _handleCapturePostIds,
          onZoomChanged: (_) {
            setState(() {});
          },
        ),

        // Filter button
        Positioned(
          top: 50,
          right: 8,
          child: IconButtonWidget(
            icon: Icons.filter_alt,
            onPressed: () {
              showFilterMapPopUp(context, 'description');
            },
            buttonSize: 70,
          ),
        ),

        // Home Page Editor
        Positioned(
          top: 120,
          right: 8,
          child: IconButtonWidget(
            icon: Icons.edit,
            onPressed: () async {
              final current = _homePageKey.currentState?.getLabelNames() ?? ['One', 'Two', 'Three'];
              final updated = await showEditMapPagePopUp(
                context, 
                'Edit Home',
                'Edit labels', 
                current,
              );
              if (updated != null && updated.isNotEmpty) {
                // This will now save to Firestore automatically
                _homePageKey.currentState?.updateLabelNames(updated);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Labels updated and saved: ${updated.join(", ")}')),
                  );
                }
              }
            },
            buttonSize: 70,
          ),
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
                onTap: ()  => showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: const Text('Log out'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: <Widget>[
                      TextButton(onPressed: () => Navigator.pop(context, 'OK'), child: const Text('OK')),
                      TextButton(onPressed: () => Navigator.pop(context, 'Cancel'), child: const Text('Cancel')),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),

        // Zoom Slider
        Positioned(
          top: 200,
          right: 8,
          child: ZoomSliderWidget(
            currentZoom: _homePageKey.currentState?.getCurrentZoom() ?? 1.0,
            onZoomChanged: (newZoom) {
              _homePageKey.currentState?.setZoom(newZoom);
              setState(() {}); // Trigger rebuild to update slider display
            },
          ),
        ),
      ],
    );
  }
}
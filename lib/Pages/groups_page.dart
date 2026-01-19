import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Map_And_Bubbles/map_logic.dart';
import '../Map_And_Bubbles/group_map_page.dart';
import '../Widgets/icon_button.dart';
import '../PopUps/edit/create_group_popup.dart';


class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key, required this.title, this.onCaptureBubbles});
  final String title;
  final void Function(List<String>)? onCaptureBubbles;

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  // Hardcoded user ID
  static const String currentUserId = "I8PwtNA3QTEt44rxH8jN";
  
  List<Map<String, dynamic>> userGroups = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserGroups();
  }

  Future<void> _loadUserGroups() async {
    try {
      // Query all groups where the current user is in the members array
      final querySnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: currentUserId)
          .get();

      if (mounted) {
        setState(() {
          userGroups = querySnapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'data': doc.data(),
            };
          }).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user groups: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          TiledMapViewer(
            backgroundAsset: Theme.of(context).brightness == Brightness.dark
                ? 'assets/background_dark.png' 
                : 'assets/background_light.png',
          ),
          const Spacer(),
          Center(
            child: SizedBox(
              width: size.width * 0.8,
              height: size.height * 0.8,
              child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                  ),
                )
              : userGroups.isEmpty
                  ? Center(
                      child: Text(
                        'No groups found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: userGroups.length + 1, // +1 for "New Map" button
                      itemBuilder: (context, index) {
                        // Last item is the "New Map" button
                        if (index == userGroups.length) {
                          return Padding(
                            padding: const EdgeInsets.all(30),
                            child: IconButtonWidget(
                              icon: Icons.add,
                              onPressed: () async {
                                final result = await showCreateGroupPopup(context, currentUserId);
                                if (result == true) {
                                  // Refresh the groups list after creating a new group
                                  _loadUserGroups();
                                }
                              },
                              buttonSize: 70,
                            ),
                          );
                        }
                        // Regular group tiles
                        final group = userGroups[index];
                        return _buildGroupTile(group['id'], group['data']);
                      },
                    ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGroupTile(String groupId, Map<String, dynamic> groupData) {
    final groupName = groupData['name'] ?? 'Unnamed Group';
    final memberCount = (groupData['members'] as List?)?.length ?? 0;
    final postCount = (groupData['posts'] as List?)?.length ?? 0;
    final createdBy = groupData['createdBy'] ?? 'Unknown';

    // Generate a color based on group name hash
    final colorIndex = groupName.hashCode % 6;
    final lightColors = [
      Colors.teal[300],
      Colors.blue[300],
      Colors.purple[300],
      Colors.orange[300],
      Colors.pink[300],
      Colors.green[300],
    ];
    final darkColors = [
      Colors.teal[700],
      Colors.blue[700],
      Colors.purple[700],
      Colors.orange[700],
      Colors.pink[700],
      Colors.green[700],
    ];

    final colors = Theme.of(context).brightness == Brightness.dark ? darkColors : lightColors;

    return GestureDetector(
      onTap: () async {
        print('📍 Opening GroupMapPage for group: $groupName');
        // Navigate to the group map page and wait for captured post IDs
        final capturedPostIds = await Navigator.push<List<String>>(
          context,
          MaterialPageRoute(
            builder: (context) => GroupMapPage(
              groupId: groupId,
              groupName: groupName,
            ),
          ),
        );

        print('📍 Returned from GroupMapPage with: $capturedPostIds');

        // Fix: Only use isNotEmpty if not null
        if (capturedPostIds != null && capturedPostIds.isNotEmpty && mounted) {
          print('✅ Processing ${capturedPostIds.length} captured posts: $capturedPostIds');
          // Call the callback to switch to feed
          print('Calling onCaptureBubbles with: $capturedPostIds');
          widget.onCaptureBubbles?.call(capturedPostIds);
          // Show feedback that posts are ready
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ready to view ${capturedPostIds.length} posts in feed'),
              duration: const Duration(seconds: 4),
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
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors[colorIndex],
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.5)
                  : const Color.fromARGB(255, 87, 87, 87),
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              groupName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 16,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                ),
                const SizedBox(width: 4),
                Text(
                  '$memberCount members',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.article,
                  size: 16,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                ),
                const SizedBox(width: 4),
                Text(
                  '$postCount posts',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              'By: $createdBy',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
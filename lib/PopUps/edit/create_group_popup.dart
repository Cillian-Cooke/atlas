import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../popup_container.dart';

class CreateGroupPopup extends StatefulWidget {
  final String currentUserId;

  const CreateGroupPopup({
    super.key,
    required this.currentUserId,
  });

  @override
  _CreateGroupPopupState createState() => _CreateGroupPopupState();
}

class _CreateGroupPopupState extends State<CreateGroupPopup> {
  final TextEditingController _groupNameController = TextEditingController();
  List<String> labels = [];
  List<String> members = [];
  List<String> posts = [];
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Add the current user as the first member
    members.add(widget.currentUserId);
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  void _showEditLabelsDialog() {
    List<String> editableLabels = List.from(labels);
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Edit Labels'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: editableLabels.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(editableLabels[index]),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setStateDialog(() {
                                editableLabels.removeAt(index);
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Add label',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final text = controller.text.trim();
                          if (text.isNotEmpty) {
                            setStateDialog(() {
                              editableLabels.add(text);
                              controller.clear();
                            });
                          }
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    labels = editableLabels;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showEditMembersDialog() {
    List<String> editableMembers = List.from(members);
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Edit Members'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: editableMembers.length,
                      itemBuilder: (context, index) {
                        final isCurrentUser = editableMembers[index] == widget.currentUserId;
                        return ListTile(
                          title: Text(
                            editableMembers[index] + (isCurrentUser ? ' (You)' : ''),
                          ),
                          trailing: isCurrentUser
                              ? const Icon(Icons.person, color: Colors.blue)
                              : IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setStateDialog(() {
                                      editableMembers.removeAt(index);
                                    });
                                  },
                                ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Add member (User ID)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final text = controller.text.trim();
                          if (text.isNotEmpty && !editableMembers.contains(text)) {
                            setStateDialog(() {
                              editableMembers.add(text);
                              controller.clear();
                            });
                          }
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    members = editableMembers;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showEditPostsDialog() {
    List<String> editablePosts = List.from(posts);
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Edit Posts'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: editablePosts.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(editablePosts[index]),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setStateDialog(() {
                                editablePosts.removeAt(index);
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Add post (Post ID)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final text = controller.text.trim();
                          if (text.isNotEmpty && !editablePosts.contains(text)) {
                            setStateDialog(() {
                              editablePosts.add(text);
                              controller.clear();
                            });
                          }
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    posts = editablePosts;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (labels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one label')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // Create the group document in Firestore
      final groupData = {
        'name': groupName,
        'labels': labels,
        'members': members,
        'posts': posts,
        'createdBy': widget.currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('groups').add(groupData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully!')),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('Error creating group: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    return SizedBox(
      height: screen.height * 0.8,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: Text(
              'Create New Group',
              style: TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Group Name Input
          TextField(
            controller: _groupNameController,
            decoration: const InputDecoration(
              labelText: 'Group Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.group),
            ),
          ),
          const SizedBox(height: 20),

          // Labels Section
          _buildSection(
            title: 'Labels (${labels.length})',
            icon: Icons.label,
            items: labels,
            onEdit: _showEditLabelsDialog,
          ),
          const SizedBox(height: 15),

          // Members Section
          _buildSection(
            title: 'Members (${members.length})',
            icon: Icons.people,
            items: members,
            onEdit: _showEditMembersDialog,
          ),
          const SizedBox(height: 15),

          // Posts Section
          _buildSection(
            title: 'Posts (${posts.length})',
            icon: Icons.article,
            items: posts,
            onEdit: _showEditPostsDialog,
          ),
          const SizedBox(height: 30),

          // Create Button
          ElevatedButton(
            onPressed: _isCreating ? null : _createGroup,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isCreating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Create Group',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<String> items,
    required VoidCallback onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text(
              'No items added',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.take(5).map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList()
                ..addAll([
                  if (items.length > 5)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+${items.length - 5} more',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ]),
            ),
        ],
      ),
    );
  }
}

// POPUP OPEN FUNCTION
Future<bool?> showCreateGroupPopup(
  BuildContext context,
  String currentUserId,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      return PopupContainer(
        child: CreateGroupPopup(
          currentUserId: currentUserId,
        ),
      );
    },
  );
}

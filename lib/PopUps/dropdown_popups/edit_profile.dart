import 'package:flutter/material.dart';
import '../popup_container.dart';
import '../../Services/post_service.dart';

class EditProfilePopUp extends StatefulWidget {

  const EditProfilePopUp({
    super.key,
  });

  @override
  State<EditProfilePopUp> createState() => _EditProfilePopUpState();
}

class _EditProfilePopUpState extends State<EditProfilePopUp> {
  late PostService _postService;
  bool _unseenPostsOnly = false;
  bool _roguePostsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _postService = PostService();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final unseenStatus = await _postService.getUnseenPostsOnlyFlag();
    final rogueStatus = await _postService.getRoguePostsEnabledFlag();
    if (mounted) {
      setState(() {
        _unseenPostsOnly = unseenStatus;
        _roguePostsEnabled = rogueStatus;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleUnseenPostsOnly(bool value) async {
    setState(() {
      _unseenPostsOnly = value;
    });
    await _postService.setUnseenPostsOnly(value);
  }

  Future<void> _toggleRoguePostsEnabled(bool value) async {
    setState(() {
      _roguePostsEnabled = value;
    });
    await _postService.setRoguePostsEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Feed Preferences',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Unseen Posts Only Toggle
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300] ?? Colors.grey,
                      ),
                    ),
                    child: ListTile(
                      title: Text(_unseenPostsOnly ? 'Show Unseen Posts Only' : 'Show All Posts'),
                      subtitle: Text(
                        _unseenPostsOnly
                            ? 'Viewing only posts you haven\'t seen yet'
                            : 'Viewing all posts',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Switch(
                        value: _unseenPostsOnly,
                        onChanged: _toggleUnseenPostsOnly,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Rogue Posts Toggle
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300] ?? Colors.grey,
                      ),
                    ),
                    child: ListTile(
                      title: Text(_roguePostsEnabled ? 'Rogue Posts Enabled' : 'Rogue Posts Disabled'),
                      subtitle: Text(
                        _roguePostsEnabled
                            ? 'Fill empty map space with random floating posts'
                            : 'Only show posts matching your labels',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Switch(
                        value: _roguePostsEnabled,
                        onChanged: _toggleRoguePostsEnabled,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

Future<void> showEditProfilePopUp(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      return PopupContainer(
        child: EditProfilePopUp(),
      );
    },
  );
}
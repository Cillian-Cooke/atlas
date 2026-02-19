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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _postService = PostService();
    _loadUnseenPostsOnlyStatus();
  }

  Future<void> _loadUnseenPostsOnlyStatus() async {
    final status = await _postService.getUnseenPostsOnlyFlag();
    if (mounted) {
      setState(() {
        _unseenPostsOnly = status;
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
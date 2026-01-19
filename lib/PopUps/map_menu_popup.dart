import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'popup_container.dart';
import '../Widgets/description_box.dart';

class MapMenuPopUpContent extends StatefulWidget {
  final String userId;

  const MapMenuPopUpContent({
    super.key, 
    required this.userId,
  });

  @override
  State<MapMenuPopUpContent> createState() => _MapMenuPopUpContentState();
}

class _MapMenuPopUpContentState extends State<MapMenuPopUpContent> {
  bool _isLoading = true;
  String _username = '';
  String _userID = '';
  String _bio = '';
  int _followers = 0;
  int _following = 0;
  int _posts = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.userId)
          .get(GetOptions(source: Source.server));

      if (mounted && doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        setState(() {
          if (data != null) {
            // Get username
            _username = data['username'] ?? data['name'] ?? data['displayName'] ?? 'Unknown User';
            
            // Get userID
            _userID = data['userID'] ?? data['ID'] ?? data['UserID'] ?? 'No ID';
            
            // Get bio
            _bio = data['bio'] ?? data['description'] ?? 'No bio available';
            
            // Get followers, following, posts
            _followers = data['followersCount'] ?? 0;
            _following = data['followingCount'] ?? 0;
            _posts = data['postsCount'] ?? data['postCount'] ?? 0;
          }
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _username = 'User not found';
            _userID = 'N/A';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _username = 'Error loading';
          _userID = 'Error';
          _isLoading = false;
        });
      }
      print("Error loading user data: $e");
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(50.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 5),
          Container(
            margin: EdgeInsets.all(5),
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            '@$_username',
            style: TextStyle(
              fontSize: 35,
              fontWeight: FontWeight.bold
            )
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$_userID',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold
                )
              ),
              IconButton(
                iconSize: 15,
                color: const Color.fromARGB(255, 133, 133, 133),
                icon: const Icon(Icons.copy),
                onPressed: () => _copyToClipboard(_userID),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                child: GestureDetector(
                  onTap: () {},
                  child: Column(
                    children: [
                      Text(
                        "Followers",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      Text(
                        _formatNumber(_followers),
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ],
                  )
                ),
              ),
              SizedBox(
                child: GestureDetector(
                  onTap: () {},
                  child: Column(
                    children: [
                      Text(
                        "Following",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      Text(
                        _formatNumber(_following),
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ],
                  )
                ),
              ),
              SizedBox(
                child: GestureDetector(
                  onTap: () {},
                  child: Column(
                    children: [
                      Text(
                        "Posts",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      Text(
                        _formatNumber(_posts),
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ],
                  )
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.all(10),
            child: LabeledBox(
              title: "Bio",
              value: _bio,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              print('📍 User wants to visit map for: $_username');
              // Close popup and signal parent to open map
              Navigator.pop(context, {
                'action': 'openMap',
                'userId': widget.userId,
                'userName': _username,
              });
            },
            style: ElevatedButton.styleFrom(
              elevation: 10,
              backgroundColor: const Color.fromARGB(255, 64, 255, 74),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              "Visit Map",
              style: TextStyle(
                color: const Color.fromARGB(255, 0, 0, 0),
                fontWeight: FontWeight.bold
              ),
            )
          )
        ],
      )
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

Future<dynamic> showMapMenuPopUp(BuildContext context, String userId) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      return PopupContainer(
        child: MapMenuPopUpContent(userId: userId),
      );
    },
  );
}
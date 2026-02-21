import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentSectionPopup extends StatefulWidget {
  final String postId;
  final String postOwnerId;

  const CommentSectionPopup({
    super.key,
    required this.postId,
    required this.postOwnerId,
  });

  @override
  State<CommentSectionPopup> createState() => _CommentSectionPopupState();
}

class _CommentSectionPopupState extends State<CommentSectionPopup> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  
  String? _replyingToCommentId;
  String? _replyingToUsername;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment')),
      );
      return;
    }

    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get current user's username from Firestore
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final username = userDoc.data()?['username'] ?? 'Anonymous';

      if (_replyingToCommentId != null) {
        // This is a reply to another comment
        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(_replyingToCommentId)
            .collection('replies')
            .add({
          'userId': currentUser.uid,
          'username': username,
          'text': commentText,
          'createdAt': FieldValue.serverTimestamp(),
          'likesCount': 0,
        });

        // Update reply count on parent comment
        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(_replyingToCommentId)
            .update({
          'repliesCount': FieldValue.increment(1),
        });
      } else {
        // This is a top-level comment
        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .add({
          'userId': currentUser.uid,
          'username': username,
          'text': commentText,
          'createdAt': FieldValue.serverTimestamp(),
          'likesCount': 0,
          'repliesCount': 0,
        });

        // Update comment count on post
        await _firestore.collection('posts').doc(widget.postId).update({
          'commentsCount': FieldValue.increment(1),
        });
      }

      _commentController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToUsername = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _toggleCommentLike(String commentId, bool isReply, String? parentCommentId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final userId = currentUser.uid;
    DocumentReference commentRef;
    DocumentReference likeDocRef;

    if (isReply && parentCommentId != null) {
      commentRef = _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(parentCommentId)
          .collection('replies')
          .doc(commentId);
      
      likeDocRef = commentRef.collection('likes').doc(userId);
    } else {
      commentRef = _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId);
      
      likeDocRef = commentRef.collection('likes').doc(userId);
    }

    try {
      final likeDoc = await likeDocRef.get();
      final currentlyLiked = likeDoc.exists;

      await _firestore.runTransaction((transaction) async {
        final commentSnapshot = await transaction.get(commentRef);
        if (!commentSnapshot.exists) return;

        final commentData = commentSnapshot.data() as Map<String, dynamic>?;
        final currentCount = commentData?['likesCount'] ?? 0;

        if (currentlyLiked) {
          transaction.delete(likeDocRef);
          transaction.update(commentRef, {
            'likesCount': currentCount > 0 ? currentCount - 1 : 0,
          });
        } else {
          transaction.set(likeDocRef, {
            'userId': userId,
            'likedAt': FieldValue.serverTimestamp(),
          });
          transaction.update(commentRef, {
            'likesCount': currentCount + 1,
          });
        }
      });
    } catch (e) {
      print('Error toggling comment like: $e');
    }
  }

  Stream<bool> _isCommentLikedStream(String commentId, bool isReply, String? parentCommentId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(false);
    }

    if (isReply && parentCommentId != null) {
      return _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(parentCommentId)
          .collection('replies')
          .doc(commentId)
          .collection('likes')
          .doc(currentUser.uid)
          .snapshots()
          .map((snapshot) => snapshot.exists);
    } else {
      return _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .collection('likes')
          .doc(currentUser.uid)
          .snapshots()
          .map((snapshot) => snapshot.exists);
    }
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
    });
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = MediaQuery.of(context).size.height - keyboardHeight;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: availableHeight * 0.9,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color.fromARGB(255, 30, 30, 30) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // Comments list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading comments',
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          size: 60,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No comments yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final commentDoc = snapshot.data!.docs[index];
                    final commentData = commentDoc.data() as Map<String, dynamic>;
                    
                    return _CommentItem(
                      commentId: commentDoc.id,
                      postId: widget.postId,
                      userId: commentData['userId'] ?? '',
                      username: commentData['username'] ?? 'Anonymous',
                      text: commentData['text'] ?? '',
                      likesCount: commentData['likesCount'] ?? 0,
                      repliesCount: commentData['repliesCount'] ?? 0,
                      createdAt: commentData['createdAt'],
                      isLikedStream: _isCommentLikedStream(commentDoc.id, false, null),
                      onLikeTap: () => _toggleCommentLike(commentDoc.id, false, null),
                      onReplyTap: () {
                        setState(() {
                          _replyingToCommentId = commentDoc.id;
                          _replyingToUsername = commentData['username'];
                        });
                        _commentFocusNode.requestFocus();
                      },
                      currentUserId: _auth.currentUser?.uid,
                      postOwnerId: widget.postOwnerId,
                    );
                  },
                );
              },
            ),
          ),

          // Reply indicator
          if (_replyingToUsername != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[200],
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to @$_replyingToUsername',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          // Comment input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color.fromARGB(255, 30, 30, 30) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // User avatar placeholder
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                  child: Icon(
                    Icons.person,
                    size: 20,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 12),
                // Text input
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    decoration: InputDecoration(
                      hintText: _replyingToUsername != null 
                          ? 'Reply to @$_replyingToUsername...' 
                          : 'Add a comment...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 14,
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                // Post button
                GestureDetector(
                  onTap: _isSubmitting ? null : _submitComment,
                  child: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        )
                      : Text(
                          'Post',
                          style: TextStyle(
                            color: _commentController.text.trim().isEmpty
                                ? (isDark ? Colors.grey[600] : Colors.grey[400])
                                : Colors.blue,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _CommentItem extends StatefulWidget {
  final String commentId;
  final String postId;
  final String userId;
  final String username;
  final String text;
  final int likesCount;
  final int repliesCount;
  final Timestamp? createdAt;
  final Stream<bool> isLikedStream;
  final VoidCallback onLikeTap;
  final VoidCallback onReplyTap;
  final String? currentUserId;
  final String postOwnerId;

  const _CommentItem({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.username,
    required this.text,
    required this.likesCount,
    required this.repliesCount,
    required this.createdAt,
    required this.isLikedStream,
    required this.onLikeTap,
    required this.onReplyTap,
    required this.currentUserId,
    required this.postOwnerId,
  });

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  bool _showReplies = false;

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7}w';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPostOwner = widget.userId == widget.postOwnerId;
    final isCurrentUser = widget.userId == widget.currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                child: Icon(
                  Icons.person,
                  size: 20,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 12),
              // Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username and text
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: widget.username,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 13,
                            ),
                          ),
                          if (isPostOwner)
                            TextSpan(
                              text: ' • Creator',
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: isDark ? Colors.grey[500] : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          TextSpan(
                            text: ' ${widget.text}',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Action buttons
                    Row(
                      children: [
                        Text(
                          widget.createdAt != null
                              ? _getTimeAgo(widget.createdAt!.toDate())
                              : 'now',
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        if (widget.likesCount > 0) ...[
                          const SizedBox(width: 12),
                          Text(
                            '${widget.likesCount} ${widget.likesCount == 1 ? 'like' : 'likes'}',
                            style: TextStyle(
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: widget.onReplyTap,
                          child: Text(
                            'Reply',
                            style: TextStyle(
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (widget.repliesCount > 0) ...[
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showReplies = !_showReplies;
                              });
                            },
                            child: Row(
                              children: [
                                Icon(
                                  _showReplies
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${widget.repliesCount} ${widget.repliesCount == 1 ? 'reply' : 'replies'}',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Like button
              StreamBuilder<bool>(
                stream: widget.isLikedStream,
                builder: (context, snapshot) {
                  final isLiked = snapshot.data ?? false;
                  return GestureDetector(
                    onTap: widget.onLikeTap,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 14,
                        color: isLiked
                            ? Colors.red
                            : (isDark ? Colors.grey[500] : Colors.grey[600]),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        // Replies section
        if (_showReplies && widget.repliesCount > 0)
          _RepliesSection(
            postId: widget.postId,
            parentCommentId: widget.commentId,
          ),
      ],
    );
  }
}

class _RepliesSection extends StatelessWidget {
  final String postId;
  final String parentCommentId;

  const _RepliesSection({
    required this.postId,
    required this.parentCommentId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(parentCommentId)
          .collection('replies')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(left: 46),
          child: Column(
            children: snapshot.data!.docs.map((replyDoc) {
              final replyData = replyDoc.data() as Map<String, dynamic>;
              
              return _ReplyItem(
                replyId: replyDoc.id,
                postId: postId,
                parentCommentId: parentCommentId,
                userId: replyData['userId'] ?? '',
                username: replyData['username'] ?? 'Anonymous',
                text: replyData['text'] ?? '',
                likesCount: replyData['likesCount'] ?? 0,
                createdAt: replyData['createdAt'],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _ReplyItem extends StatelessWidget {
  final String replyId;
  final String postId;
  final String parentCommentId;
  final String userId;
  final String username;
  final String text;
  final int likesCount;
  final Timestamp? createdAt;

  const _ReplyItem({
    required this.replyId,
    required this.postId,
    required this.parentCommentId,
    required this.userId,
    required this.username,
    required this.text,
    required this.likesCount,
    required this.createdAt,
  });

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7}w';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  Future<void> _toggleReplyLike(BuildContext context) async {
    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final replyRef = firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(parentCommentId)
        .collection('replies')
        .doc(replyId);
    
    final likeDocRef = replyRef.collection('likes').doc(currentUser.uid);

    try {
      final likeDoc = await likeDocRef.get();
      final currentlyLiked = likeDoc.exists;

      await firestore.runTransaction((transaction) async {
        final replySnapshot = await transaction.get(replyRef);
        if (!replySnapshot.exists) return;

        final replyData = replySnapshot.data();
        final currentCount = replyData?['likesCount'] ?? 0;

        if (currentlyLiked) {
          transaction.delete(likeDocRef);
          transaction.update(replyRef, {
            'likesCount': currentCount > 0 ? currentCount - 1 : 0,
          });
        } else {
          transaction.set(likeDocRef, {
            'userId': currentUser.uid,
            'likedAt': FieldValue.serverTimestamp(),
          });
          transaction.update(replyRef, {
            'likesCount': currentCount + 1,
          });
        }
      });
    } catch (e) {
      print('Error toggling reply like: $e');
    }
  }

  Stream<bool> _isReplyLikedStream() {
    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    
    if (currentUser == null) {
      return Stream.value(false);
    }

    return firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(parentCommentId)
        .collection('replies')
        .doc(replyId)
        .collection('likes')
        .doc(currentUser.uid)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar (smaller for replies)
          CircleAvatar(
            radius: 14,
            backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
            child: Icon(
              Icons.person,
              size: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 12),
          // Reply content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and text
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: username,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                      ),
                      TextSpan(
                        text: ' $text',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Time and likes
                Row(
                  children: [
                    Text(
                      createdAt != null ? _getTimeAgo(createdAt!.toDate()) : 'now',
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    if (likesCount > 0) ...[
                      const SizedBox(width: 12),
                      Text(
                        '$likesCount ${likesCount == 1 ? 'like' : 'likes'}',
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Like button
          StreamBuilder<bool>(
            stream: _isReplyLikedStream(),
            builder: (context, snapshot) {
              final isLiked = snapshot.data ?? false;
              return GestureDetector(
                onTap: () => _toggleReplyLike(context),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 14,
                    color: isLiked
                        ? Colors.red
                        : (isDark ? Colors.grey[500] : Colors.grey[600]),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
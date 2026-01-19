import 'package:flutter/material.dart';
import 'post_feed.dart';

class FeedTab extends StatelessWidget {
  final ValueNotifier<List<String>>? capturedBubbles;

  const FeedTab({super.key, this.capturedBubbles});

  @override
  Widget build(BuildContext context) {
    return PostFeedPage(
      title: 'Content Feed',
      capturedBubbles: capturedBubbles,
    );
  }
}
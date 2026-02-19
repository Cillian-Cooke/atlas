import 'package:flutter/material.dart';
import 'post_feed.dart';

class FeedTab extends StatelessWidget {
  final ValueNotifier<List<String>>? capturedBubbles;

  const FeedTab({super.key, this.capturedBubbles});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [ 
        PostFeedPage(
        title: 'Content Feed',
        capturedBubbles: capturedBubbles,
        ),
        // Positioned(
        //   bottom: 65,
        //   right: 8,
        //     child: IconButtonWidget(
        //       icon: Icons.back_hand_sharp,
        //       onPressed: () {
        //       },
        //       buttonSize: 70,
        //     ),
        //   ),
      ]
    );
  }
}
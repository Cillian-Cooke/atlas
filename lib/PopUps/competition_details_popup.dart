import 'package:flutter/material.dart';
import '../Widgets/description_box.dart';
import 'popup_container.dart'; // 👈 use the shared popup shell

class CompetitionPopUpContent extends StatelessWidget {
  final String description;
  final String compTitle;
  final String autherName;
  final int size;
  final double prize;
  final String timeRemaining;

  const CompetitionPopUpContent({
    super.key,
    required this.compTitle,
    required this.autherName,
    required this.description,
    required this.size,
    required this.prize,
    required this.timeRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            compTitle,
            style: const TextStyle(
              fontSize: 35,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Container(
            height: screen.height * 0.4,
            width: screen.height * 0.4,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'By: @$autherName',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _InfoColumn(
                icon: Icons.people,
                label: "$size people",
              ),
              _InfoColumn(
                icon: Icons.diamond,
                label: "\$$prize",
              ),
              _InfoColumn(
                icon: Icons.alarm,
                label: timeRemaining,
              ),
            ],
          ),

          const SizedBox(height: 10),

          LabeledBox(
            title: "Description",
            value: description,
          ),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              elevation: 10,
              backgroundColor: const Color.fromARGB(255, 233, 82, 82),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              "Join Competition!",
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoColumn({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          iconSize: 40,
          color: Colors.black,
          icon: Icon(icon),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const AlertDialog(
                title: Text('Info'),
                content: Text('More details here'),
              ),
            );
          },
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// 🔹 Public function to call the popup
Future<void> showCompetitionPopUp(
  BuildContext context,
  String title,
  String autherName,
  String description,
  int size,
  double prize,
  String timeRemaining
) {
  return showDialog(
    barrierDismissible: true,
    barrierColor: Colors.black54,
    context: context,
    builder: (context) {
      return PopupContainer(
        child: CompetitionPopUpContent(
          compTitle: title,
          autherName: autherName,
          description: description,
          size: size,
          prize: prize,
          timeRemaining: timeRemaining,
        ),
      );
    },
  );
}

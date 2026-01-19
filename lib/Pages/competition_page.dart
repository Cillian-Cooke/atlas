import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../PopUps/competition_details_popup.dart';

class CompetitionPage extends StatefulWidget {
  const CompetitionPage({super.key, required this.title, required this.visibility});

  final String title;
  final bool visibility;

  @override
  State<CompetitionPage> createState() => _CompetitionPageState();
}

class _CompetitionPageState extends State<CompetitionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _calculateTimeRemaining(Timestamp? endTime) {
    if (endTime == null) return 'N/A';
    
    final now = DateTime.now();
    final end = endTime.toDate();
    final difference = end.difference(now);
    
    if (difference.isNegative) {
      return 'Ended';
    }
    
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    
    if (days > 0) {
      return '${days}D ${hours}Hrs';
    } else if (hours > 0) {
      return '${hours}Hrs ${minutes}Min';
    } else {
      return '${minutes}Min';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('competitions').snapshots(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        // No data state
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No competitions available'),
          );
        }

        final competitions = snapshot.data!.docs;

        return MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 0,
              mainAxisSpacing: 0,
            ),
            itemCount: competitions.length,
            itemBuilder: (BuildContext context, int index) {
              final compDoc = competitions[index];
              final data = compDoc.data() as Map<String, dynamic>;

              // Extract data from Firestore document
              final title = data['title'] ?? 'Untitled';
              final username = data['username'] ?? 'Unknown';
              final description = data['description'] ?? '';
              final size = data['size'] ?? 0;
              final prize = (data['prize'] ?? 0).toDouble();
              final endTime = data['endTime'] as Timestamp?;

              // Calculate time remaining
              final timeRemaining = _calculateTimeRemaining(endTime);

              return GestureDetector(
                onTap: () async {
                  await showCompetitionPopUp(
                    context,
                    title,
                    username,
                    description,
                    size,
                    prize,
                    timeRemaining,
                  );
                },
                child: widget.visibility
                    ? _buildImageCard(title, username)
                    : _buildDetailsCard(title, username, size, prize, timeRemaining),
              );
            },
          ),
        );
      },
    );
  }

  // Competition Card (images view)
  Widget _buildImageCard(String title, String username) {
    return Card(
      margin: const EdgeInsets.all(1.5),
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      color: Colors.amber,
      child: Center(
        child: Column(
          children: [
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(125, 255, 255, 255),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    constraints: const BoxConstraints(
                      minHeight: 20,
                      maxHeight: 50,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('@$username'),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  // Competition Card (details view)
  Widget _buildDetailsCard(
    String title,
    String username,
    int size,
    double prize,
    String timeRemaining,
  ) {
    return Card(
      margin: const EdgeInsets.all(1.5),
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      color: const Color.fromARGB(255, 255, 0, 0),
      child: Center(
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: 400,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  borderRadius: BorderRadius.circular(20),
                ),
                margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Icon(Icons.people)),
                        const Text('  |  '),
                        Expanded(
                          child: Text(
                            size.toString(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ],
                    ),
                    Row(
                      children: [
                        const Expanded(child: Icon(Icons.diamond)),
                        const Text('  |  '),
                        Expanded(
                          child: Text(
                            '£${prize.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ],
                    ),
                    Row(
                      children: [
                        const Expanded(child: Icon(Icons.alarm)),
                        const Text('  |  '),
                        Expanded(
                          child: Text(
                            timeRemaining,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(125, 255, 255, 255),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    constraints: const BoxConstraints(
                      minHeight: 20,
                      maxHeight: 50,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('@$username'),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../popup_container.dart';

class FilterCompPopUpContent extends StatefulWidget {
  final String description;

  const FilterCompPopUpContent({
    super.key,
    required this.description,
  });

  @override
  State<FilterCompPopUpContent> createState() => _FilterCompPopUpContentState();
}

class _FilterCompPopUpContentState extends State<FilterCompPopUpContent> {
  // Index-based range values (0–6)
  RangeValues priceRange = const RangeValues(0, 6);
  RangeValues sizeRange = const RangeValues(0, 6);
  RangeValues timeRange = const RangeValues(0, 6);

  final List<String> priceLabels = [
    "Free",
    "€5",
    "€10",
    "€20",
    "€50",
    "€100",
    "€1000+",
  ];
  final List<String> sizeLabels = [
    "5",
    "10",
    "20",
    "30",
    "50",
    "100",
    "1000+",
  ];
  final List<String> timeLabels = [
    "1 hour",
    "3 hours",
    "12 hours",
    "1 day",
    "3 days",
    "1 week",
    "1 month",
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            "Prize Range",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          // Display selected labels
          Text(
            "${priceLabels[priceRange.start.round()]}  →  ${priceLabels[priceRange.end.round()]}",
            style: const TextStyle(fontSize: 18),
          ),

          const SizedBox(height: 5),

          // ACTUAL RANGE SLIDER
          RangeSlider(
            values: priceRange,
            min: 0,
            max: 6,
            divisions: 6,
            labels: RangeLabels(
              priceLabels[priceRange.start.round()],
              priceLabels[priceRange.end.round()],
            ),
            onChanged: (newRange) {
              setState(() {
                priceRange = newRange;
              });
            },
          ),

          const SizedBox(height: 5),

          Text("Size Range",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),
          // Display selected labels
          Text(
            "${sizeLabels[sizeRange.start.round()]}  →  ${sizeLabels[sizeRange.end.round()]} people",
            style: const TextStyle(fontSize: 18),
          ),

          const SizedBox(height: 5),

          // ACTUAL RANGE SLIDER
          RangeSlider(
            values: sizeRange,
            min: 0,
            max: 6,
            divisions: 6,
            labels: RangeLabels(
              sizeLabels[sizeRange.start.round()],
              sizeLabels[sizeRange.end.round()],
            ),
            onChanged: (newRange) {
              setState(() {
                sizeRange = newRange;
              });
            },
          ),

          const SizedBox(height: 5),

          const Text(
            "Time Range",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          // Display selected labels
          Text(
            "${timeLabels[timeRange.start.round()]}  →  ${timeLabels[timeRange.end.round()]}",
            style: const TextStyle(fontSize: 18),
          ),

          const SizedBox(height: 5),

          // ACTUAL RANGE SLIDER
          RangeSlider(
            values: timeRange,
            min: 0,
            max: 6,
            divisions: 6,
            labels: RangeLabels(
              timeLabels[timeRange.start.round()],
              timeLabels[timeRange.end.round()],
            ),
            onChanged: (newRange) {
              setState(() {
                timeRange = newRange;
              });
            },
          ),

          const SizedBox(height: 20),

          // Optionally: show buttons, apply FilterComps, etc.
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, priceRange);
            },
            child: const Text("Apply"),
          )
        ],
      ),
    );
  }
}

Future<void> showFilterCompPopUp(BuildContext context, String description) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      return PopupContainer(
        child: FilterCompPopUpContent(description: description),
      );
    },
  );
}

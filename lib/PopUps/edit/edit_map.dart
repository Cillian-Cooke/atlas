import 'package:flutter/material.dart';
import '../popup_container.dart';

class EditMapPopUpContent extends StatefulWidget {
  final String title;
  final String description;
  final List<String> items;
  final void Function(List<String>) onListUpdated;

  const EditMapPopUpContent({
    super.key,
    required this.title,
    required this.description,
    required this.items,
    required this.onListUpdated,
  });

  @override
  _EditMapPopUpContentState createState() => _EditMapPopUpContentState();
}

class _EditMapPopUpContentState extends State<EditMapPopUpContent> {
  bool isUnseen = true;
  bool isRogue = true;
  late List<String> items;
  
  final List<Color> labelColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    items = List.from(widget.items);
  }

  void _showEditMapListDialog() {
    List<String> editableItems = List.from(items);
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Edit List'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: editableItems.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text('${index + 1}: ${editableItems[index]}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setStateDialog(() {
                                editableItems.removeAt(index);
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
                            labelText: 'Add item',
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
                              editableItems.add(text);
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
                    items = editableItems;
                  });
                  // Close the inner edit dialog first, then notify the outer popup
                  Navigator.pop(context);
                  widget.onListUpdated(items);
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    return SizedBox(
      height: screen.height * 0.7,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center( 
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),

          Center(
            child: Container(
              height: screen.height*0.20,
              width: screen.height*0.20, 
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: const Color.fromARGB(255, 116, 116, 116),
                  width: 3,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  'assets/edit_previews/${items.length}_labels.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image doesn't exist
                    return Container(
                      color: const Color.fromARGB(255, 255, 255, 255),
                      child: Center(
                        child: Text(
                          '${items.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // List of items with index
          ...items.asMap().entries.map((entry) {
            int index = entry.key;
            String item = entry.value;
            Color circleColor = labelColors[index % labelColors.length];

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.black12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      child: Row( 
                        children: [
                          Container(
                            margin: const EdgeInsets.all(5),
                            width: 25,
                            height: 25,
                            decoration: const BoxDecoration(
                              color: Color.fromARGB(255, 233, 245, 255),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child:Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          ),
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ]
                      )
                    ),
                    Container(
                      margin: const EdgeInsets.all(5),
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: circleColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          TextButton.icon(
            onPressed: _showEditMapListDialog,
            icon: const Icon(Icons.edit),
            label: const Text('Edit List'),
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 25,
                color: Colors.blue,
                icon: const Icon(Icons.info_outline),
                onPressed: () => showDialog(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: const Text('Unseen Posts Description'),
                    content: Text('These are posts that have appeared in your feed before, preventing you from seeing the same content more than once.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Only Unseen Posts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Switch(
                value: isUnseen,
                activeThumbColor: const Color.fromARGB(255, 54, 200, 244),
                onChanged: (bool value) {
                  setState(() {
                    isUnseen = value;
                  });
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 25,
                color: Colors.blue,
                icon: const Icon(Icons.info_outline),
                onPressed: () => showDialog(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: const Text('Rogue Posts Description'),
                    content: Text('These are randomized posts with a monochrome color scheme to add visual interest and excitement to your feed.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Rogue Posts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Switch(
                value: isRogue,
                activeThumbColor: const Color.fromARGB(255, 54, 200, 244),
                onChanged: (bool value) {
                  setState(() {
                    isRogue = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// POPUP OPEN FUNCTION
Future<List<String>?> showEditMapPagePopUp(
  BuildContext context,
  String title,
  String description,
  List<String> items,
) {
  return showDialog<List<String>>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      return PopupContainer(
        child: EditMapPopUpContent(
          title: title,
          description: description,
          items: items,
          onListUpdated: (updatedItems) {
            Navigator.pop(context, updatedItems);
          },
        ),
      );
    },
  );
}
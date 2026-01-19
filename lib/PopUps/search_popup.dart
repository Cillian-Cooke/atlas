import 'package:flutter/material.dart';
import 'popup_container.dart';

class searchPopUpContent extends StatefulWidget {
  final String description;

  const searchPopUpContent({
    super.key,
    required this.description,
  });

  @override
  State<searchPopUpContent> createState() => _SearchPopUpContentState();
}

class _SearchPopUpContentState extends State<searchPopUpContent> {


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          height: 300,
          width: 300,
          padding: EdgeInsets.all(20),
          margin: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 255, 255, 255),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Search Bar",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                    ),
                  ),
                  SizedBox(width: 4,),
                  IconButton(
                    iconSize: 25,
                    color: Colors.blue,
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => showDialog<String>(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        title: const Text('Search Definition'),
                        content: const Text('This search algorthim is almost non-existant and therefore not biased towards a particular creator, buisness or tag.'),
                        actions: <Widget>[
                          TextButton(onPressed: () => Navigator.pop(context, 'OK'), child: const Text('OK')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),
              SearchBar(
                hintText: "#tags, @users and ?other....",
                onChanged: (value) {},
              ),
            ],
          ),
        ),
      )
    );
  }
}

Future<void> showSearchPopUp(BuildContext context, String description) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      return PopupContainer(
        child: searchPopUpContent(description: description),
      );
    },
  );
}

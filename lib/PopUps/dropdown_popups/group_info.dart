import 'package:flutter/material.dart';
import '../popup_container.dart';

class GroupInfoPopUp extends StatefulWidget {

  const GroupInfoPopUp({
    super.key,
  });

  @override
  State<GroupInfoPopUp> createState() => _GroupInfoPopUpState();
}

class _GroupInfoPopUpState extends State<GroupInfoPopUp> {


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text('Comming Soon',)
      )
    );
  }
}

Future<void> showGroupInfoPopUp(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      return PopupContainer(
        child: GroupInfoPopUp(),
      );
    },
  );
}

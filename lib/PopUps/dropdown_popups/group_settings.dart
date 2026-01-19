import 'package:flutter/material.dart';
import '../popup_container.dart';

class GroupSettingsPopUp extends StatefulWidget {

  const GroupSettingsPopUp({
    super.key,
  });

  @override
  State<GroupSettingsPopUp> createState() => _GroupSettingsPopUpState();
}

class _GroupSettingsPopUpState extends State<GroupSettingsPopUp> {


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

Future<void> showGroupSettingsPopUp(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      return PopupContainer(
        child: GroupSettingsPopUp(),
      );
    },
  );
}

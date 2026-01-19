import 'package:flutter/material.dart';
import '../popup_container.dart';

class EditProfilePopUp extends StatefulWidget {

  const EditProfilePopUp({
    super.key,
  });

  @override
  State<EditProfilePopUp> createState() => _EditProfilePopUpState();
}

class _EditProfilePopUpState extends State<EditProfilePopUp> {


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

Future<void> showEditProfilePopUp(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      return PopupContainer(
        child: EditProfilePopUp(),
      );
    },
  );
}
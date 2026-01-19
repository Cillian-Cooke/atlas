import 'package:flutter/material.dart';
import '../popup_container.dart';

class FilterGroupsPopUp extends StatefulWidget {

  const FilterGroupsPopUp({
    super.key,
  });

  @override
  State<FilterGroupsPopUp> createState() => _FilterGroupsPopUpState();
}

class _FilterGroupsPopUpState extends State<FilterGroupsPopUp> {


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

Future<void> showFilterGroupsPopUp(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      return PopupContainer(
        child: FilterGroupsPopUp(),
      );
    },
  );
}
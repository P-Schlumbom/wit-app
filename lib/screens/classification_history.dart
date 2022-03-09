import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';

import 'package:wit_app/classes/classification_result.dart';

import 'package:wit_app/screens/classification.dart';

class ClassificationHistory extends StatefulWidget {
  const ClassificationHistory({Key? key}) : super(key: key);

  @override
  _ClassificationHistory createState() => _ClassificationHistory();

}


class _ClassificationHistory extends State<ClassificationHistory> {
  late final Box box;

  List<Container> _buildClassificationResults(){
    // note that this may possibly be a slightly questionable method currently
    int index = 0;
    int numItems = box.values.length;
    return box.values.toList().reversed.map((result){
      int boxIndex = numItems - 1 - index;
      var container = Container(
        child: ListTile(
          leading: ClipOval(
            child: Image.file(File(result.imagePath),
            width: 64,
            height: 64,
            fit: BoxFit.cover),
          ),
          title: Text(result.prediction),
          subtitle: Text(DateFormat('yyyy-MM-dd - kk:mm').format(result.timestamp)),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Classification(classificationID: boxIndex,))
            );
          },
        )
      );
      index++;
      return container;
    }).toList();
    /*return results.map((result){
      var container = Container(
        child: ListTile(
          leading: ClipOval(
            child: Image.file(File(result.imagePath),
                width: 64,
                height: 64,
                fit: BoxFit.cover),
          ),
          title: Text(result.prediction),
          subtitle: Text(DateFormat('yyyy-MM-dd - kk:mm').format(result.timestamp)),
        ),
      );
      return container;
    }).toList();*/
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Classification History"),
      ),
      body: Scrollbar(
          child: ListView(
            //restorationId: 'list_demo_list_view',
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: _buildClassificationResults(),
          )
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    box = Hive.box('resultsBox');
  }
}
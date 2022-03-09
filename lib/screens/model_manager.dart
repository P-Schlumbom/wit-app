import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';

class ModelManager extends StatefulWidget {
  const ModelManager({Key? key}) : super(key: key);

  @override
  _ModelManager createState() => _ModelManager();

}

class _ModelManager extends State<ModelManager> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Model Manager"),
      ),
      body: Scrollbar(
          child: ListView(
            //restorationId: 'list_demo_list_view',
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: const [
               ListTile(
                leading: Icon(Icons.lightbulb_outline),
                title: Text("Model Name"),
                subtitle: Text("model size, and possibly estimated inference times"),
              ),
            ],
          )
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }
}
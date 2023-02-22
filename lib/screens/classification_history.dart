import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'package:wit_app/classes/classification_result.dart';

import 'package:wit_app/screens/classification.dart';

class ClassificationHistory extends StatefulWidget {
  const ClassificationHistory({Key? key}) : super(key: key);

  @override
  _ClassificationHistory createState() => _ClassificationHistory();

}


class _ClassificationHistory extends State<ClassificationHistory> {
  late final Box box;
  late final Future<Directory> dir = getApplicationDocumentsDirectory();

  Future<void> dummyFunction(int index) async {
    debugPrint("delete command for $index");
  }

  Future<void> deleteEntry(int index) async {
    // given a specific result ID, delete the image referenced by it and delete
    // the entry from the Hive box
    debugPrint(index.toString());
    debugPrint((box.values.length).toString());
    ClassificationResult? item = box.getAt(index);
    String imagePath = item!.imagePath;
    debugPrint(imagePath);
    // delete image
    // must check if source image is stored locally or a reference to an on-device image
    if (imagePath.startsWith('$dir.Path${Platform.pathSeparator}files${Platform.pathSeparator}') == true) {
      File? sourceImage = File(imagePath);
      await sourceImage.delete(); // to complete (?)
    }
    // delete Hive entry
    box.deleteAt(index);
    setState(() {
      // refresh the page
    });
  }

  Future<Image?> _getImage(String imagePath) async {
    /*
    * In new versions (1.1.0+), images are stored in {dir}/files/
    * However, in previous versions, this wasn't always the case, so try to
    * retrieve images using their file name only, and return a missing image
    * icon otherwise.
    * */
    Directory dir = await getApplicationDocumentsDirectory();
    final String dirPath = dir.path;

    File standardFile = File(imagePath);
    /*if (await standardFile.exists()) {
      return Image.file(
        standardFile,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
      );
    } else {
      File legacyFile = File('$dirPath${Platform.pathSeparator}files${Platform.pathSeparator}' + path.basename(imagePath));
      if (await legacyFile.exists()) {
        return Image.file(
          legacyFile,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
        );
      } else {
        return null;
      }
    }*/
    if (await standardFile.exists()) {
      return Image.file(standardFile,
        width: 64,
        height: 64,
        fit: BoxFit.cover,);
    }
    File legacyFile = File('$dirPath${Platform.pathSeparator}files${Platform.pathSeparator}' + path.basename(imagePath));
    if (await legacyFile.exists()) {
      return Image.file(legacyFile,
        width: 64,
        height: 64,
        fit: BoxFit.cover,);
    }
    if (Platform.isIOS) {
      final cacheDirectory = await getTemporaryDirectory();
      final cachePath = cacheDirectory.path;
      File iosFile = File(cachePath + Platform.pathSeparator + path.basename(imagePath));
      if (await iosFile.exists()) {
        return Image.file(iosFile,
          width: 64,
          height: 64,
          fit: BoxFit.cover,);
      } else {
        return null;
      }
    }
    return null;
  }

  List<Container> _buildClassificationResults(){
    // note that this may possibly be a slightly questionable method currently
    int index = 0;
    int numItems = box.values.length;
    return box.values.toList().reversed.map((result){
      int boxIndex = numItems - 1 - index;
      var container = Container(
        child: ListTile(
          leading: ClipOval(
            child: FutureBuilder<Image?>(
              future: _getImage(result.imagePath),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return snapshot.data ?? const Icon(Icons.image_not_supported_outlined);
                } else {
                  return const Icon(Icons.image_not_supported_outlined);
                }
              },
            ),
          ),
          title: Text("${(result.topFivePredictions[0].probability >= 0.5 ? result.prediction : "Unknown")} (${((result.topFivePredictions[0].probability).toStringAsPrecision(3))})"),
          subtitle: Text(DateFormat('yyyy-MM-dd - kk:mm').format(result.timestamp)),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Classification(classificationID: boxIndex,))
            );
          },
          trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => deleteEntry(boxIndex),
              ),
        ),
      );
      index++;
      return container;
    }).toList();
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
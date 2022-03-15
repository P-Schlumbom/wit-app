import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pytorch_mobile/pytorch_mobile.dart';
import 'package:pytorch_mobile/model.dart';
import 'package:pytorch_mobile/enums/dtype.dart';

import 'package:flutter/foundation.dart';  // for debugPrint

import 'classes/classification_result.dart';
//import 'classes/custom_models.dart';  // potential alternative to pytorch_mobile/model.dart
import 'classes/prediction.dart';
import 'classes/name_data.dart';
import 'screens/classification_history.dart';
import 'screens/classification.dart';
import 'screens/model_manager.dart';

void main() async {
  // Initialize hive database and prepare it
  await Hive.initFlutter();
  Hive.registerAdapter(ClassificationResultAdapter());  // register the adapter
  Hive.registerAdapter(PredictionAdapter());
  Hive.registerAdapter(NameDataAdapter());
  await Hive.openBox('resultsBox');
  await Hive.openBox('namesBox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Color(0xFFeff6e0),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = false;
  List<double> mean = [0.5, 0.5, 0.5];
  List<double> std = [0.5, 0.5, 0.5];

  File? image;// = File("assets/logos/TAIAO.png");
  Model? imageModel;
  //PostProcessingModel? imageModel;
  String? imagePrediction;
  late final Box box;
  late final Box speciesNamesBox;
  late final Map<String, dynamic> speciesNamesMap;

  Future<List<String>> _getLabels(String labelPath) async {
    String labelsData = await rootBundle.loadString(labelPath);
    return labelsData.split(",");
  }

  int _comparePredictions(Prediction a, Prediction b) {
    // comparator function allows sorting of Prediction class instances
    if (a.probability < b.probability){
      return -1;
    } else if (a.probability == b.probability) {
      return 0;
    } else {
      return 1;
    }
  }

  List? applySoftmax(List? prediction) {
    double exponentSum = 0;
    for (int i=0; i<prediction!.length; i++){
      exponentSum = exponentSum + exp(prediction[i]);
    }
    return prediction.map((x) {return exp(x) / exponentSum;}).toList();
  }

  NameData _getNameData(int ID) {
    String stringID = ID.toString();
    NameData idNameData = NameData(
        ID,
        speciesNamesMap[stringID]["scientific_name"],
        List<String>.from(speciesNamesMap[stringID]["mri"]),
        List<String>.from(speciesNamesMap[stringID]["eng"])
    );
    return idNameData;
  }

  Future<List<Prediction>> _getTopFivePredictions(List? prediction, String labelPath) async {
    List<String> labels = await _getLabels(labelPath);
    List<Prediction> predictions = prediction!.asMap().entries.map((entry) {
      int i = entry.key;
      NameData nameData = speciesNamesBox.get(i);
      Prediction pred = Prediction(i, labels[i], entry.value, nameData);
      return pred;
    }).toList();

    predictions.sort((a, b) => _comparePredictions(a, b));
    predictions = predictions.reversed.toList();

    return predictions.sublist(0, 5);
  }

  Future loadNamesData() async {
    if (speciesNamesBox.values.length != 11047) {
      debugPrint("Updating speciesNamesBox because it currently contains ${speciesNamesBox.values.length} items instead of 11047");
      String namesDataString = await rootBundle.loadString("assets/labels/class_metadata.json");
      speciesNamesMap = jsonDecode(namesDataString);

      for (int i = 0; i < 11047; i++) {
        speciesNamesBox.put(i, _getNameData(i));
      }
    }
  }

  Future loadModel() async {
    String pathModel = "assets/models/species_model_s.pt";

    try {
      imageModel = await PyTorchMobile.loadModel(pathModel);
    } on PlatformException {
      debugPrint("only supported for android and ios for now");
    }
  }

  Future _pickImage(BuildContext context, ImageSource source) async {
    try {
      final XFile? predImage = await ImagePicker().pickImage(
          source: source,
          maxHeight: 768,
          maxWidth: 768
      );
      if (predImage == null) return;

      // store image locally
      Directory dir = await getApplicationDocumentsDirectory();
      final String dirPath = dir.path;
      // copy image to the new path
      String savePath = '$dirPath${Platform.pathSeparator}files${Platform.pathSeparator}${DateFormat('yyyyMMddkkmmss').format(DateTime.now())}.png';
      debugPrint(savePath);
      //final XFile storedImage = await predImage.copy(newPath);
      predImage.saveTo(savePath);

      setState(() {
        _isLoading = true;
      });

      List? prediction = await imageModel!.getImagePredictionList(
        File(predImage.path),
        768,
        768,
        mean: mean,
        std: std,
      );
      prediction = applySoftmax(prediction);
      List<Prediction> topFivePredictions = await _getTopFivePredictions(prediction, "assets/labels/species_names.csv");
      box.add(ClassificationResult(topFivePredictions[0].species, predImage.path, DateTime.now(), topFivePredictions));

      setState(() => this.image = File(predImage.path));
      setState(() {
        _isLoading = false;
      });

      int boxIndex = box.values.length - 1;
      Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => Classification(classificationID: boxIndex,))
      );
    } on PlatformException catch (e) {
      debugPrint('Failed in picking image: $e');
    }
  }

  Widget _buildButton({
    required String title,
    required IconData icon,
    required VoidCallback onClicked,
  }) => ElevatedButton(
    style: ElevatedButton.styleFrom(
        minimumSize: Size.fromHeight(56),
        primary: Colors.amber,
        onPrimary: Colors.white,
        textStyle: TextStyle(fontSize: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0))
    ),
    child: Row(
      children: [
        Icon(icon, size: 28,),
        const SizedBox(width: 16),
        Text(title),
      ],
    ),
    onPressed: onClicked,
  );

  @override
  void initState(){
    // during initialisation, get reference to opened box
    super.initState();
    box = Hive.box('resultsBox');
    speciesNamesBox = Hive.box('namesBox');
    loadNamesData();
    loadModel();
  }

  @override
  void dispose() {
    // close the hive box properly when closing the app
    Hive.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),  // when an image is being
        // processed, should display the loading wheel.
      )
          : Container(
        padding: EdgeInsets.all(32),
        child: Column(
          children: <Widget>[
            Spacer(),
            image != null ? ClipOval(
                child: Image.file(
                  image!,
                  width: 255,
                  height: 255,
                  fit: BoxFit.cover,)
            )
                : Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: const Image(image: AssetImage('assets/logos/TAIAO.png')),
            ),
            const SizedBox(height: 48),
            _buildButton(title: 'Pick Camera',
                icon: Icons.camera_alt_outlined,
                onClicked: () => _pickImage(context, ImageSource.camera)),
            const SizedBox(height: 12),
            _buildButton(title: 'Pick Gallery',
                icon: Icons.image_outlined,
                onClicked: () => _pickImage(context, ImageSource.gallery)),
            const SizedBox(height: 12),
            _buildButton(title: 'Classification History',
                icon: Icons.history_outlined,
                onClicked: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ClassificationHistory())
                  );
                }),
            const SizedBox(height: 12),
            _buildButton(title: 'Model Manager',
                icon: Icons.manage_search_outlined,
                onClicked: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ModelManager())
                  );
                }),
            Spacer(),
          ],
        ),
      ),
    );
  }
}



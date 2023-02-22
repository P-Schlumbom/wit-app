//import 'dart:html';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'package:wit_app/classes/classification_result.dart';
import 'package:wit_app/utils/custom_expansion_tile.dart';

import 'package:wit_app/globals.dart';

const double PROB_THRESHOLD = 0.5;

class Classification extends StatefulWidget {
  final int classificationID;
  const Classification({Key? key, required this.classificationID}) : super(key: key);

  @override
  _Classification createState() => _Classification();
}

class _Classification extends State<Classification>{
  late final Box box;
  late final ClassificationResult classificationResult;
  late final String stringID;
  late final String speciesName;
  late final List<String> engNames;
  late final List<String> mriNames;
  late final bool isPlantOriented;  // whether or not the prediction seems likely to revolve around plants
  late final bool isUnwanted;
  late final int notifiableStatus; // -1 for not notifiable, 0 for both, 1 for notifiable
  //Image? image;

  String probability2String(double probability){
    if (probability <= 0.001) {
      return "monstrously infinitesimal confidence";
    } else if (probability > 0.001 && probability <= 0.022) {
      return "abysmally low confidence";
    } else if (probability > 0.022 && probability <= 0.158) {
      return "very low confidence";
    } else if (probability > 0.158 && probability <= 0.50) {
      return "low confidence";
    } else if (probability > 0.50 && probability <= 0.841) {
      return "reasonable confidence";
    } else if (probability > 0.841 && probability <= 0.977) {
      return "very high confidence";
    } else if (probability > 0.977 && probability <= 0.998) {
      return "extremely high confidence";
    } else {
      return "positively overwhelming confidence";
    }
  }

  List<String> createNamesList(List<String> engNames, List<String> mriNames){
    List<String> commonNames = <String>[];
    if (engNames.isEmpty) {
      commonNames = mriNames;
    } else if (mriNames.isEmpty) {
      commonNames = engNames;
    } else {
      commonNames = List.from(engNames)..addAll(mriNames);
      commonNames = commonNames.toSet().toList();  // remove repeated names
    }
    return commonNames;
  }

  String createCommonNamesString(List<String> engNames, List<String> mriNames) {
    if (engNames.isEmpty && mriNames.isEmpty){
      return "There are no common names for this species.";
    }
    List<String> commonNames = <String>[];
    if (engNames.isEmpty) {
      commonNames = mriNames;
    } else if (mriNames.isEmpty) {
      commonNames = engNames;
    } else {
      commonNames = List.from(engNames)..addAll(mriNames);
      commonNames = commonNames.toSet().toList();  // remove repeated names
    }
    String commonName = commonNames[0];
    return "";
  }

  String getCommonName(String latinName, List<String> engNames, List<String> mriNames) {
    if (engNames.isEmpty && mriNames.isEmpty || (engNames[0] == "" && mriNames[0] == "")) { return latinName;}
    String topEngName = engNames.isEmpty ? "" : engNames[0];
    String topMriName = mriNames.isEmpty ? "" : mriNames[0];
    String returnName = (topEngName != "" && topMriName != "") ?
    ((topEngName == topMriName) ?
    topEngName :
    "${topEngName} / ${topMriName}") :
    ((topEngName != "") ?
    topEngName :
    topMriName);
    return returnName;
  }

  RichText createNameDetailsText(String prediction, List<String> engNames, List<String> mriNames, double probability) {
    String confidenceText = "I have ${probability2String(probability)} that this is a ";

    // if probability is < threshold, return an "I don't know" message instead.
    if (probability < PROB_THRESHOLD){
      return RichText(
        text: TextSpan(
          children: <TextSpan>[
            const TextSpan(text: "I am not confident enough to say what this might be. "),
            TextSpan(text: probability > 0.1 ? "My best guess would be ${(prediction)}, but I'm really not sure." : "")
          ],
          style: const TextStyle(color: Colors.black),
        )
      );
    }

    if (engNames.isEmpty && mriNames.isEmpty || (engNames[0] == "" && mriNames[0] == "")){
      return RichText(
          text: TextSpan(
            children: <TextSpan>[
              TextSpan(text: confidenceText),
              TextSpan(text: prediction, style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: ". I don't know of any common names for this species.")
            ],
            style: const TextStyle(color: Colors.black),
          ),
      );
    }

    String topEngName = engNames.isEmpty ? "" : engNames[0];
    String topMriName = mriNames.isEmpty ? "" : mriNames[0];
    /*IF neither the top eng nor top mri names are empty,
    * THEN
    *   IF top eng == top mri
    *   THEN use top eng
    *   ELSE say "top eng, or top mri"
    * ELSE
    *   IF top eng isn't empty
    *   THEN use top eng
    *   ELSE use top mri*/
    String topName = (topEngName != "" && topMriName != "") ?
      ((topEngName == topMriName) ?
        topEngName :
        "$topMriName, or $topEngName") :
      ((topEngName != "") ?
        topEngName :
        topMriName);

    List<String> remainingNames = (topEngName != "" && topMriName != "") ?
      (List.from(engNames.sublist(1))..addAll(mriNames.sublist(1))) :
      ((topEngName != "") ?
        engNames.sublist(1) :
        mriNames.sublist(1));
    remainingNames = remainingNames.toSet().toList();

    if (remainingNames.isEmpty){
      //return "This species is commonly known as a ${topName}.";
      return RichText(text: TextSpan(
        children: <TextSpan>[
          TextSpan(text: confidenceText),
          TextSpan(text: topName, style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: ".")
        ],
        style: const TextStyle(color: Colors.black),
      )
      );
    } else {
      //return "This species is commonly known as a ${topName}. \n\n"
      //    "It is also known by a number of other names, such as: ${remainingNames.join(", ")}";
      return RichText(text: TextSpan(
        children: <TextSpan>[
          TextSpan(text: confidenceText),
          TextSpan(text: topName, style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: "."),
          const TextSpan(text: "\n\nIt is also known by a number of other names, such as: \n"),
          TextSpan(text: remainingNames.join(", ")),
          const TextSpan(text: ".")
        ],
        style: const TextStyle(color: Colors.black),
      )
      );
    }
  }

  Card createDetailsCard(List<TextSpan> details, String detailType){
    Color tileColor = const Color(0xFFeff6e0);
    Color textColor = Colors.teal;
    switch (detailType) {
      case "helper":
        tileColor = const Color(0xFFeff6e0);
        textColor = Colors.teal;
        break;
      case "warning":
        tileColor = Colors.teal;
        textColor = const Color(0xFFeff6e0);
        break;
      case "alert":
        tileColor = Colors.deepOrange;
        textColor = const Color(0xFFeff6e0);
        break;
    }

    if (detailType == "helper"){
      return Card(
        elevation: 0,
        color: tileColor,
        child: Container(
            padding: const EdgeInsets.all(8),
            child: RichText(
              text: TextSpan(
                  children: details,
                  style: TextStyle(color: textColor)
              ),
            )
        ),
        shape: const RoundedRectangleBorder(
          side: BorderSide(
            color: Colors.teal,
          ),
          borderRadius: BorderRadius.all(Radius.circular(12))
        ),
      );
    }

    return Card(
        elevation: 2,
        color: tileColor,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: RichText(
            text: TextSpan(
              children: details,
              style: TextStyle(color: textColor)
            ),
          )
        ),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))
        )
    );
  }


  ListTile createTopFiveListTile(int index){
    String numberString = "${index + 1}. ";
    return ListTile(
      leading: Text(numberString),
      title: SelectableText(classificationResult.topFivePredictions[index].species),
      trailing: Text((classificationResult.topFivePredictions[index].probability).toStringAsPrecision(3)),
      textColor: const Color(0xFFeff6e0).withOpacity(classificationResult.topFivePredictions[index].probability / 4 + 0.75),
    );
  }

  Future loadSpeciesData() async {
    stringID = classificationResult.topFivePredictions[0].index.toString();
    engNames = List<String>.from(speciesNamesMap[stringID]["eng"]);
    mriNames = List<String>.from(speciesNamesMap[stringID]["mri"]);
    bool acceptPred = classificationResult.topFivePredictions[0].probability >= PROB_THRESHOLD;  // no need to display notifications if confidence is too low
    // set plant status
    List<String> topFiveIndices = [
      classificationResult.topFivePredictions[0].index.toString(),
      classificationResult.topFivePredictions[1].index.toString(),
      classificationResult.topFivePredictions[2].index.toString(),
      classificationResult.topFivePredictions[3].index.toString(),
      classificationResult.topFivePredictions[4].index.toString(),
    ];
    int plantCount = 0;
    int nonEmptyCount = 0;
    for (int i = 0; i<5; i++){
      nonEmptyCount += speciesNamesMap[topFiveIndices[i]]["kingdom"] == "" ? 0 : 1;  // if the kingdom string is empty, add nothing to the count, else 1
      plantCount += speciesNamesMap[topFiveIndices[i]]["kingdom"] == "Plantae" ? 1 : 0;
    }
    if (plantCount > nonEmptyCount ~/2 || speciesNamesMap[stringID]["kingdom"] == "Plantae"){  // if most top 5 species are plants or the top prediction is a plant, the prediction is plant oriented
      isPlantOriented = true;  // needs to be redone
    } else {
      isPlantOriented = false;
    }
    // set notifiable status
    if (speciesNamesMap[stringID]["notifiable"] == "Yes" && acceptPred){
      notifiableStatus = 1;
    } else if (speciesNamesMap[stringID]["notifiable"] == "No,Yes" && acceptPred){
      notifiableStatus = 0;
    } else {
      notifiableStatus = -1;
    }
    // set unwanted status
    if (speciesNamesMap[stringID]["unwanted"] == "Yes" && notifiableStatus == -1 && acceptPred) {
      isUnwanted = true;
    } else {
      isUnwanted = false;
    }
  }

  Future<Text> _getSearchPath(String imagePath) async {
    /*
    * For debugging purposes, get the paths images are being searched for...
    * */
    Directory dir = await getApplicationDocumentsDirectory();
    final String dirPath = dir.path;

    File standardFile = File(imagePath);
    if (await standardFile.exists()) {
      return Text(imagePath);
    }
    File legacyFile = File('$dirPath${Platform.pathSeparator}files${Platform.pathSeparator}' + path.basename(imagePath));
    if (await legacyFile.exists()) {
      return Text('$dirPath${Platform.pathSeparator}files${Platform.pathSeparator}' + path.basename(imagePath));
    }
    if (Platform.isIOS) {
      final cacheDirectory = await getTemporaryDirectory();
      final cachePath = cacheDirectory.path;
      File iosFile = File(cachePath + Platform.pathSeparator + path.basename(imagePath));
      if (await iosFile.exists()) {
        return Text(cachePath + Platform.pathSeparator + path.basename(imagePath));
      } else {
        return Text("Looked for " + cachePath + Platform.pathSeparator + path.basename(imagePath) + " but found nothing");
      }
    }
    return Text("Nothing at " + imagePath + "\nor at " + '$dirPath${Platform.pathSeparator}files${Platform.pathSeparator}' + path.basename(imagePath));
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
      return Image.file(standardFile);
    } else {
      File legacyFile = File('$dirPath${Platform.pathSeparator}files${Platform.pathSeparator}' + path.basename(imagePath));
      if (await legacyFile.exists()) {
        return Image.file(legacyFile);
      } else {
        return null;
      }
    }*/

    if (await standardFile.exists()) {
      return Image.file(standardFile);
    }
    File legacyFile = File('$dirPath${Platform.pathSeparator}files${Platform.pathSeparator}' + path.basename(imagePath));
    if (await legacyFile.exists()) {
      return Image.file(legacyFile);
    }
    if (Platform.isIOS) {
      final cacheDirectory = await getTemporaryDirectory();
      final cachePath = cacheDirectory.path;
      File iosFile = File(cachePath + Platform.pathSeparator + path.basename(imagePath));
      if (await iosFile.exists()) {
        return Image.file(iosFile);
      } else {
        return null;
      }
    }
    return null;
    }

  @override
  void initState() {
    super.initState();
    box = Hive.box('resultsBox');
    debugPrint("${widget.classificationID}");
    classificationResult = box.getAt(widget.classificationID);  // for demo purposes, select first(?) entry for now.
    loadSpeciesData();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
        appBar: AppBar(
          title: Text(classificationResult.topFivePredictions[0].probability >= PROB_THRESHOLD ? classificationResult.topFivePredictions[0].species : "Unknown"),
        ),
        body: Scrollbar(
            child: ListView(
              children: [
                FittedBox(
                  child: FutureBuilder<Image?>(  // wait for image to be found/loaded and display icon in the meantime
                    future: _getImage(classificationResult.imagePath),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return snapshot.data ?? const Icon(Icons.image_not_supported_outlined);
                      } else {
                        return const Icon(Icons.image_not_supported_outlined);
                      }
                    },
                  ),
                  fit: BoxFit.fill,
                ),
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SelectableText(
                              classificationResult.topFivePredictions[0].probability >= PROB_THRESHOLD ? classificationResult.prediction : "Unkown",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 32.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Prediction probability: ${(classificationResult.topFivePredictions[0].probability).toStringAsPrecision(3)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.0,
                            ),
                          ),
                          Visibility(
                            visible: isPlantOriented,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  createDetailsCard(<TextSpan>[
                                    const TextSpan(text: "Are you trying to classify plants?\t"),
                                    const TextSpan(text: "We recommend taking close-up photographs of individual leaves, rather than "
                                        "images of the whole plant - the model tends to perform better that way.")
                                  ], "helper")
                                ],
                              )
                          ),
                          const SizedBox(height: 12),
                          createNameDetailsText(
                              classificationResult.prediction,
                              engNames,
                              mriNames,
                              classificationResult.topFivePredictions[0].probability
                          ),
                          const SizedBox(height: 12),
                          Visibility(
                            visible: isUnwanted,
                              child: createDetailsCard(
                              <TextSpan>[
                              const TextSpan(text: "The Ministry of Primary Industries (MPI) considers this to be an "),
                              const TextSpan(text: "unwanted ", style: TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: "organism.")
                              ], "warning")
                          ),
                          Visibility(
                            visible: notifiableStatus == 0,
                            child: createDetailsCard(
                                <TextSpan>[
                                  const TextSpan(text: "There are multiple variants of this species, some of which are "
                                      "considered notifiable pests. Unfortunately, the classifier cannot distinguish between these variants."),
                                  const TextSpan(text: "\n\n"),
                                  const TextSpan(text: "A notifiable organism could seriously harm New Zealand's primary production or our "
                                      "trade and market access. If you suspect this is a notifiable variant, consider following the steps "
                                      "outlined by the "),
                                  const TextSpan(
                                    text: "Ministry of Primary Industries.",
                                    style: TextStyle(color: Colors.amber),
                                    //recognizer: TapGestureRecognizer()..onTap = () {launch} // link here, based on https://stackoverflow.com/questions/43583411/how-to-create-a-hyperlink-in-flutter-widget
                                  )
                                ], "warning"),
                          ),
                          Visibility(
                            visible: notifiableStatus == 1,
                            child: createDetailsCard(
                                <TextSpan>[
                                  const TextSpan(text: "Warning! This appears to be a "),
                                  const TextSpan(text: "notifiable organism!", style: TextStyle(fontWeight: FontWeight.bold)),
                                  const TextSpan(text: "\n\n"),
                                  const TextSpan(text: "Notifiable organisms could seriously harm New Zealand's primary production or our "
                                      "trade and market access."),
                                  const TextSpan(text: "\n\n"),
                                  const TextSpan(text: "If the model's assessment seems reasonable, we strongly recommend reporting this "
                                      "organism by following the steps outlined by the Ministry of Primary Industries (MPI) "),
                                  const TextSpan(
                                    text: "here.",
                                    style: TextStyle(color: Colors.amber),
                                    //recognizer: TapGestureRecognizer()..onTap = () {launch} // link here, based on https://stackoverflow.com/questions/43583411/how-to-create-a-hyperlink-in-flutter-widget
                                  ),
                                  const TextSpan(text: "\n\n"),
                                  const TextSpan(text: "Please note that if you spot a notifiable organism, you have a legal obligation to "
                                      "report it under the "),
                                  const TextSpan(
                                    text: "Biosecurity Act 1993",
                                    style: TextStyle(color: Colors.amber),
                                    //recognizer: TapGestureRecognizer()..onTap = () {launch} // link here, based on https://stackoverflow.com/questions/43583411/how-to-create-a-hyperlink-in-flutter-widget
                                  ),
                                  const TextSpan(text: " ("),
                                  const TextSpan(
                                    text: "Section 44",
                                    style: TextStyle(color: Colors.amber),
                                    //recognizer: TapGestureRecognizer()..onTap = () {launch} // link here, based on https://stackoverflow.com/questions/43583411/how-to-create-a-hyperlink-in-flutter-widget
                                  ),
                                  const TextSpan(text: " and "),
                                  const TextSpan(
                                    text: "46",
                                    style: TextStyle(color: Colors.amber),
                                    //recognizer: TapGestureRecognizer()..onTap = () {launch} // link here, based on https://stackoverflow.com/questions/43583411/how-to-create-a-hyperlink-in-flutter-widget
                                  ),
                                  const TextSpan(text: ").")
                                ], "alert"),
                          ),
                          const SizedBox(height: 12),
                          CustomExpansionTile(
                            title: const Text("Top Five Predictions", style: TextStyle(fontWeight: FontWeight.bold)),
                            children: [
                              createTopFiveListTile(0),
                              createTopFiveListTile(1),
                              createTopFiveListTile(2),
                              createTopFiveListTile(3),
                              createTopFiveListTile(4),
                            ],
                          ),const SizedBox(height: 12),
                          FutureBuilder<Text>(  // wait for image to be found/loaded and display icon in the meantime
                            future: _getSearchPath(classificationResult.imagePath),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return snapshot.data ?? const Text("error retrieving data.");
                              } else {
                                return const Text("retrieving search paths...");
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            classificationResult.imagePath,
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "This image was taken on ${DateFormat('yyyy-MM-dd - kk:mm').format(classificationResult.timestamp)}",
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          )
                        ],
                      ))
                    ],
                  ),
                ),
              ],
            )
        )
    );

  }
}


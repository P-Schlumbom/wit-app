//import 'dart:html';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';

import 'package:wit_app/classes/classification_result.dart';

import 'package:wit_app/globals.dart';

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

    if (engNames.isEmpty && mriNames.isEmpty || (engNames[0] == "" && mriNames[0] == "")){
      return RichText(
          text: TextSpan(
            children: <TextSpan>[
              TextSpan(text: confidenceText),
              TextSpan(text: prediction, style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: ". I don't know of any common names for this species.")
            ],
            style: TextStyle(color: Colors.black),
          ),
      );
    }

    String topEngName = engNames.isEmpty ? "" : engNames[0];
    String topMriName = mriNames.isEmpty ? "" : mriNames[0];
    String topName = (topEngName != "" && topMriName != "") ?
      ((topEngName == topMriName) ?
        topEngName :
        "${topEngName}, or ${topMriName}") :
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
    );
  }

  Future loadSpeciesData() async {
    stringID = classificationResult.topFivePredictions[0].index.toString();
    engNames = List<String>.from(speciesNamesMap[stringID]["eng"]);
    mriNames = List<String>.from(speciesNamesMap[stringID]["mri"]);
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
    if (speciesNamesMap[stringID]["notifiable"] == "Yes"){
      notifiableStatus = 1;
    } else if (speciesNamesMap[stringID]["notifiable"] == "No,Yes"){
      notifiableStatus = 0;
    } else {
      notifiableStatus = -1;
    }
    // set unwanted status
    if (speciesNamesMap[stringID]["unwanted"] == "Yes" && notifiableStatus == -1) {
      isUnwanted = true;
    } else {
      isUnwanted = false;
    }
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
          title: Text(classificationResult.topFivePredictions[0].species),
        ),
        body: Scrollbar(
            child: ListView(
              children: [
                FittedBox(
                  child: Image.file(File(classificationResult.imagePath)),
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
                              classificationResult.prediction,
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
                              child: createDetailsCard(<TextSpan>[
                            const TextSpan(text: "Are you trying to classify plants?\t"),
                            const TextSpan(text: "We recommend taking close-up photographs of individual leaves, rather than "
                            "images of the whole plant - the model tends to perform better that way.")
                            ], "helper")
                          ),
                          const SizedBox(height: 12),
                          /*Text(
                            //"Also known as: ${createNamesList(classificationResult.topFivePredictions[0].nameData.engNames, classificationResult.topFivePredictions[0].nameData.mriNames)}",
                            createNameDetailsText(classificationResult.topFivePredictions[0].nameData.engNames, classificationResult.topFivePredictions[0].nameData.mriNames),
                          ),*/
                          createNameDetailsText(
                              classificationResult.prediction,
                              engNames,
                              mriNames,
                              classificationResult.topFivePredictions[0].probability
                              /*speciesNamesMap[classificationResult.topFivePredictions[0].index.toString()]["eng"],
                              speciesNamesMap[classificationResult.topFivePredictions[0].index.toString()]["mri"],
                              classificationResult.topFivePredictions[0].probability*/
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
                          const Text(
                            "Top Five Predictions:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "1. ${classificationResult.topFivePredictions[0].species}, ${(classificationResult.topFivePredictions[0].probability).toStringAsPrecision(3)}\n"
                                "2. ${classificationResult.topFivePredictions[1].species}, ${(classificationResult.topFivePredictions[1].probability).toStringAsPrecision(3)}\n"
                                "3. ${classificationResult.topFivePredictions[2].species}, ${(classificationResult.topFivePredictions[2].probability).toStringAsPrecision(3)}\n"
                                "4. ${classificationResult.topFivePredictions[3].species}, ${(classificationResult.topFivePredictions[3].probability).toStringAsPrecision(3)}\n"
                                "5. ${classificationResult.topFivePredictions[4].species}, ${(classificationResult.topFivePredictions[4].probability).toStringAsPrecision(3)}\n"
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


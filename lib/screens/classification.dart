//import 'dart:html';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';

import 'package:wit_app/classes/classification_result.dart';

class Classification extends StatefulWidget {
  final int classificationID;
  const Classification({Key? key, required this.classificationID}) : super(key: key);

  @override
  _Classification createState() => _Classification();
}

class _Classification extends State<Classification>{
  late final Box box;
  late final ClassificationResult classificationResult;

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

  @override
  void initState() {
    super.initState();
    box = Hive.box('resultsBox');
    classificationResult = box.getAt(widget.classificationID);  // for demo purposes, select first(?) entry for now.
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
                            child: Text(
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
                          const SizedBox(height: 12),
                          /*Text(
                            //"Also known as: ${createNamesList(classificationResult.topFivePredictions[0].nameData.engNames, classificationResult.topFivePredictions[0].nameData.mriNames)}",
                            createNameDetailsText(classificationResult.topFivePredictions[0].nameData.engNames, classificationResult.topFivePredictions[0].nameData.mriNames),
                          ),*/
                          createNameDetailsText(
                              classificationResult.prediction,
                              classificationResult.topFivePredictions[0].nameData.engNames,
                              classificationResult.topFivePredictions[0].nameData.mriNames,
                              classificationResult.topFivePredictions[0].probability
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


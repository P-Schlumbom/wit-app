import 'classifier.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

class ClassifierEfficientNet extends Classifier {
  ClassifierEfficientNet({int numThreads: 1}) : super(numThreads: numThreads);

  @override
  String get modelName => 'models/species_model_squeezenet.tflite';

  @override
  NormalizeOp get preProcessNormalizeOp => NormalizeOp(0.5, 0.5);//NormalizeOp(0.5, 0.5);

  @override
  NormalizeOp get postProcessNormalizeOp => NormalizeOp(0, 1);
}


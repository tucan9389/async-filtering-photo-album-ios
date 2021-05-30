//
//  main.swift
//  ImageNetClassifier
//
//  Created by Doyoung Gwak on 2021/05/28.
//

import CreateML
import Foundation

/*
 * arg1: datasetPath(String)
 * arg2: iterations(Int)
 * arg3: modelName(String)
 */

var datasetPath = URL(string: "/Users/tucan9389/Downloads/atmosphere_sample_ds002_createml/train")
if CommandLine.arguments.count > 1 {
    datasetPath = URL(string: CommandLine.arguments[1])
}

var maxIterations = 50
if CommandLine.arguments.count > 3 {
    maxIterations = Int(CommandLine.arguments[3]) ?? maxIterations
}

guard let datasetPath = datasetPath else { exit(1) }

let augmentationOptions: MLImageClassifier.ImageAugmentationOptions = [] // [.exposure, .flip, .noise, .rotation]
let modelParams = MLImageClassifier.ModelParameters(validation: .split(strategy: .automatic), maxIterations: maxIterations, augmentation: augmentationOptions)
let model = try! MLImageClassifier(trainingData: .labeledDirectories(at: datasetPath), parameters: modelParams)


print("Hello, World!", model.validationMetrics)
let validMetricLog = "\(model.validationMetrics)"
print(validMetricLog)

/*
 Number of examples: 179
 Number of classes: 18
 Accuracy: 40.22%

 ******CONFUSION MATRIX******
 ----------------------------------
 True\Pred 01  02  03  04  05  06  07  08  09  10  11  12  13  14  15  17  18  19
 01        3   0   0   0   1   0   0   1   0   1   1   4   1   1   0   0   0   0
 02        1   5   0   0   0   1   0   0   1   0   0   0   0   1   0   0   0   0
 03        1   0   2   1   5   0   0   0   0   0   0   0   1   0   0   0   0   0
 04        1   0   0   0   1   0   0   0   0   0   0   0   1   0   0   0   0   0
 05        0   0   3   1   8   0   0   0   0   0   0   0   0   0   0   0   0   0
 06        1   1   0   1   0   3   0   1   2   2   1   0   0   4   0   1   1   0
 07        1   0   0   0   0   0   2   0   0   1   0   2   1   1   0   0   0   1
 08        0   2   0   0   0   2   0   1   0   1   0   0   1   0   1   0   0   0
 09        0   0   0   0   0   0   0   0   2   0   0   0   0   0   0   0   0   0
 10        0   1   1   1   0   1   0   0   0   4   0   0   0   0   0   0   0   0
 11        3   1   0   0   0   0   0   0   0   0   8   0   0   1   0   0   0   0
 12        1   0   1   1   0   1   0   1   0   0   1   5   2   0   0   0   0   1
 13        0   1   1   1   1   0   0   1   0   0   1   2   9   0   0   0   0   0
 14        0   1   0   0   0   0   0   3   2   4   0   0   0   10  1   0   1   0
 15        0   0   0   0   0   0   0   0   0   0   0   1   0   0   4   0   0   1
 17        0   0   1   0   0   0   0   0   0   0   1   0   0   0   0   0   0   0
 18        0   0   0   0   0   0   2   0   0   1   0   0   0   1   0   0   2   0
 19        2   0   0   0   0   0   0   0   0   0   0   0   0   0   1   0   0   4

 ******PRECISION RECALL******
 ----------------------------------
 Class Precision(%)   Recall(%)
 01    21.43          23.08
 02    41.67          55.56
 03    22.22          20.00
 04    0.00           0.00
 05    50.00          66.67
 06    37.50          16.67
 07    50.00          22.22
 08    12.50          12.50
 09    28.57          100.00
 10    28.57          50.00
 11    61.54          61.54
 12    35.71          35.71
 13    56.25          52.94
 14    52.63          45.45
 15    57.14          66.67
 17    0.00           0.00
 18    50.00          33.33
 19    57.14          57.14
 */

if CommandLine.arguments.count > 2 {
    let mlmodelPath = URL(fileURLWithPath: CommandLine.arguments[2])
    try! model.write(to: mlmodelPath)
}
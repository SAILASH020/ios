# iOS Face Recognition with FaceNet & Core ML

A real-time face recognition system for iOS utilizing **FaceNet** (InceptionResNetV1) and **Core ML**. This project provides a full pipeline for converting pre-trained weights into Apple’s native ML format and integrating them into a high-performance Swift application.

## 🚀 Key Features
*   **On-Device Inference:** Local processing using the Apple Neural Engine (ANE) for privacy and speed.
*   **Real-Time Detection:** Live face bounding boxes via the [Vision Framework](https://developer.apple.com/documentation/vision).
*   **Vector Embeddings:** Generates 128-dimensional (or 512) feature vectors to represent unique facial identities.
*   **Similarity Matching:** Optimized Euclidean Distance calculation to recognize faces against a local database.

---

## 🏗 Project Architecture
```text
├── ML_Conversion/
│   ├── convert_to_coreml.py    # Python script for .h5 to .mlpackage
│   └── requirements.txt        # coremltools, tensorflow
├── FaceNet-iOS/
│   ├── FaceNet.mlmodel         # Converted Core ML model
│   ├── FaceDetectionManager.swift  # Vision framework logic
│   └── RecognitionEngine.swift     # Vector comparison logic
└── README.md

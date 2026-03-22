import ssl
import os
import coremltools as ct
from keras_facenet import FaceNet
import tensorflow as tf

# Disable SSL verification for model downloading
ssl._create_default_https_context = ssl._create_unverified_context

# 1. Load FaceNet
print("Loading FaceNet model...")
embedder = FaceNet()
keras_model = embedder.model

# 2. Convert to Core ML
# We remove the name="input_1" to let CoreML find the correct layer automatically
print("Converting to Core ML...")
mlmodel = ct.convert(
    keras_model,
    inputs=[ct.ImageType(shape=(1, 160, 160, 3),
                         scale=1/127.5,
                         bias=[-1, -1, -1])]
)

# 3. Save for Xcode
mlmodel.save("FaceNet.mlpackage")
print("\n✅ Success! 'FaceNet.mlmodel' is now in your folder.")

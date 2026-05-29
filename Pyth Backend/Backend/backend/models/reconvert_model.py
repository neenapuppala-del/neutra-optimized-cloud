import tensorflow as tf

print("TensorFlow version:", tf.__version__)

model = tf.keras.models.load_model("food_model_final.h5")

converter = tf.lite.TFLiteConverter.from_keras_model(model)

# IMPORTANT: compatible ops
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS
]

converter.optimizations = [tf.lite.Optimize.DEFAULT]

tflite_model = converter.convert()

with open("food_model_render.tflite", "wb") as f:
    f.write(tflite_model)

print("Done. Generated food_model_render.tflite")
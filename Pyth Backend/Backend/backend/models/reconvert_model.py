import tensorflow as tf

print("TF:", tf.__version__)

model = tf.keras.models.load_model(
    "food_model_final.h5",
    compile=False
)

converter = tf.lite.TFLiteConverter.from_keras_model(model)

converter.optimizations = []
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS
]

tflite_model = converter.convert()

with open("food_model_render_v2.tflite", "wb") as f:
    f.write(tflite_model)

print("DONE")
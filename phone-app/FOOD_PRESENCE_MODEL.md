# Food Presence Model

The bundled model is `food_presence.tflite`, downloaded from:

https://huggingface.co/maia2000/mobilenet-food-binary/resolve/main/tflite_int8_io_float.tflite

## Contract

- Architecture: MobileNetV3Small with a three-class softmax head.
- Input tensor: `FLOAT32 [1, 224, 224, 3]`.
- Input values: RGB pixels in `0..255`. The model contains the `0..255 -> -1..1` rescaling layer.
- Output tensor: `FLOAT32 [1, 3]`.
- Output order: `[healthy, not_food, unhealthy]`.
- Application value: `foodProbability = output[0] + output[2]`.
- File size: 1,219,312 bytes.
- SHA-256: `F6141ED56F78CE3B5EDA6EC8D1726E877D885D46453305B44DE36FC6182A6D55`.

The source model is marked Apache-2.0 by its publisher. See the
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) for the license text.
The model was evaluated on
Food-101-derived data, not RV101 camera frames; its published metrics are not a
substitute for testing on the glasses input stream.

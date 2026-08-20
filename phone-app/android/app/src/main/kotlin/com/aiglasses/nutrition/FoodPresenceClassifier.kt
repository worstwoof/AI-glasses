package com.aiglasses.nutrition

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.roundToInt

class FoodPresenceClassifier(context: Context) : AutoCloseable {
    private val appContext = context.applicationContext
    private val interpreter = Interpreter(
        loadModelFile(),
        Interpreter.Options().setNumThreads(2),
    )

    init {
        validateModel()
    }

    @Synchronized
    fun predictFoodProbability(bytes: ByteArray): Double {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw IllegalArgumentException("JPEG 解码失败")
        val inputBitmap = try {
            letterbox(bitmap)
        } finally {
            bitmap.recycle()
        }

        return try {
            val input = Array(1) { Array(INPUT_SIZE) { Array(INPUT_SIZE) { FloatArray(3) } } }
            val pixels = IntArray(INPUT_SIZE * INPUT_SIZE)
            inputBitmap.getPixels(
                pixels,
                0,
                INPUT_SIZE,
                0,
                0,
                INPUT_SIZE,
                INPUT_SIZE,
            )
            var pixelIndex = 0
            for (row in 0 until INPUT_SIZE) {
                for (column in 0 until INPUT_SIZE) {
                    val pixel = pixels[pixelIndex++]
                    input[0][row][column][0] = Color.red(pixel).toFloat()
                    input[0][row][column][1] = Color.green(pixel).toFloat()
                    input[0][row][column][2] = Color.blue(pixel).toFloat()
                }
            }

            val output = Array(1) { FloatArray(CLASS_COUNT) }
            interpreter.run(input, output)
            val healthy = output[0][HEALTHY_INDEX].toDouble()
            val unhealthy = output[0][UNHEALTHY_INDEX].toDouble()
            val probability = healthy + unhealthy
            if (!probability.isFinite()) {
                throw IllegalStateException("模型返回了无效概率")
            }
            probability.coerceIn(0.0, 1.0)
        } finally {
            inputBitmap.recycle()
        }
    }

    override fun close() {
        interpreter.close()
    }

    private fun letterbox(bitmap: Bitmap): Bitmap {
        val result = Bitmap.createBitmap(
            INPUT_SIZE,
            INPUT_SIZE,
            Bitmap.Config.ARGB_8888,
        )
        val canvas = Canvas(result)
        canvas.drawColor(Color.BLACK)

        val scale = minOf(
            INPUT_SIZE.toFloat() / bitmap.width,
            INPUT_SIZE.toFloat() / bitmap.height,
        )
        val width = (bitmap.width * scale).roundToInt().coerceAtLeast(1)
        val height = (bitmap.height * scale).roundToInt().coerceAtLeast(1)
        val left = (INPUT_SIZE - width) / 2f
        val top = (INPUT_SIZE - height) / 2f
        canvas.drawBitmap(
            bitmap,
            null,
            RectF(left, top, left + width, top + height),
            Paint(Paint.FILTER_BITMAP_FLAG),
        )
        return result
    }

    private fun validateModel() {
        val input = interpreter.getInputTensor(0)
        val output = interpreter.getOutputTensor(0)
        check(input.dataType() == DataType.FLOAT32) {
            "食物模型输入必须是 FLOAT32，实际为 ${input.dataType()}"
        }
        check(input.shape().contentEquals(intArrayOf(1, INPUT_SIZE, INPUT_SIZE, 3))) {
            "食物模型输入形状不匹配：${input.shape().contentToString()}"
        }
        check(output.dataType() == DataType.FLOAT32) {
            "食物模型输出必须是 FLOAT32，实际为 ${output.dataType()}"
        }
        check(output.shape().contentEquals(intArrayOf(1, CLASS_COUNT))) {
            "食物模型输出形状不匹配：${output.shape().contentToString()}"
        }
    }

    private fun loadModelFile(): ByteBuffer {
        val bytes = appContext.assets.open(MODEL_ASSET).use { it.readBytes() }
        return ByteBuffer.allocateDirect(bytes.size).apply {
            order(ByteOrder.nativeOrder())
            put(bytes)
            rewind()
        }
    }

    private companion object {
        private const val MODEL_ASSET = "food_presence.tflite"
        private const val INPUT_SIZE = 224
        private const val CLASS_COUNT = 3

        // The model's confusion matrix confirms this order: healthy, not_food, unhealthy.
        private const val HEALTHY_INDEX = 0
        private const val UNHEALTHY_INDEX = 2
    }
}

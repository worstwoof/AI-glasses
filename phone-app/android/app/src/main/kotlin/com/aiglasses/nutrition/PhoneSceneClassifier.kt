package com.aiglasses.nutrition

import android.content.Context
import android.graphics.BitmapFactory
import com.google.mediapipe.framework.image.BitmapImageBuilder

import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker


class PhoneSceneClassifier(context: Context) {
    private val appContext = context.applicationContext
    private var landmarker: HandLandmarker? = null

    @Synchronized
    fun classifyJpeg(bytes: ByteArray): Map<String, Any> {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: return unknown("JPEG 解码失败", 0)
        return try {
            val result = detector().detect(BitmapImageBuilder(bitmap).build())
            val hands = result.landmarks()
            val gesture = hands.asSequence()
                .map { hand ->
                    when (GestureLandmarkClassifier.classify(hand.map {
                        GestureLandmark(it.x(), it.y(), it.z())
                    })) {
                        GestureKind.OK -> Gesture.OK
                        GestureKind.OPEN_PALM -> Gesture.OPEN_PALM
                        GestureKind.FIST -> Gesture.FIST
                        GestureKind.UNKNOWN -> Gesture.UNKNOWN
                    }
                }
                .firstOrNull { it != Gesture.UNKNOWN }
                ?: Gesture.UNKNOWN

            when (gesture) {
                Gesture.OK -> mapOf(
                    "scene" to "ingredient_label",
                    "label" to "配料表识别模式",
                    "gesture" to "ok",
                    "confidence" to 0.90,
                    "hands" to hands.size,
                    "message" to "手机端识别到 OK 手势，进入配料表 OCR 准备状态",
                    "model" to MODEL_NAME,
                )
                Gesture.OPEN_PALM -> mapOf(
                    "scene" to "eating",
                    "label" to "进餐环境",
                    "gesture" to "open_palm",
                    "confidence" to 0.82,
                    "hands" to hands.size,
                    "message" to "手机端识别到张开手掌，进入无感饮食记录准备状态",
                    "model" to MODEL_NAME,
                )
                Gesture.FIST -> mapOf(
                    "scene" to "unknown",
                    "label" to "结束进餐手势",
                    "gesture" to "fist",
                    "confidence" to 0.82,
                    "hands" to hands.size,
                    "message" to "手机端识别到握拳，准备结束进餐 Session",
                    "model" to MODEL_NAME,
                )
                Gesture.UNKNOWN -> unknown("未检测到 OK、张开手掌或握拳", hands.size)
            }
        } finally {
            bitmap.recycle()
        }
    }

    fun close() {
        landmarker?.close()
        landmarker = null
    }

    private fun detector(): HandLandmarker {
        landmarker?.let { return it }
        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(
                BaseOptions.builder()
                    .setDelegate(Delegate.CPU)
                    .setModelAssetPath(MODEL_NAME)
                    .build(),
            )
            .setRunningMode(RunningMode.IMAGE)
            .setNumHands(2)
            .setMinHandDetectionConfidence(0.55f)
            .setMinHandPresenceConfidence(0.55f)
            .setMinTrackingConfidence(0.50f)
            .build()
        return HandLandmarker.createFromOptions(appContext, options).also {
            landmarker = it
        }
    }

    private fun unknown(message: String, hands: Int): Map<String, Any> = mapOf(
        "scene" to "unknown",
        "label" to "等待场景手势",
        "gesture" to "unknown",
        "confidence" to 0.0,
        "hands" to hands,
        "message" to message,
        "model" to MODEL_NAME,
    )

    private enum class Gesture {
        OK,
        OPEN_PALM,
        FIST,
        UNKNOWN,
    }

    private companion object {
        private const val MODEL_NAME = "hand_landmarker.task"
    }
}

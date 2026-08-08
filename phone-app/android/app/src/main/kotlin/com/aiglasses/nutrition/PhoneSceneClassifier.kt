package com.aiglasses.nutrition

import android.content.Context
import android.graphics.BitmapFactory
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import kotlin.math.abs
import kotlin.math.sqrt

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
                    when {
                        isOkGesture(hand) -> Gesture.OK
                        isOpenPalm(hand) -> Gesture.OPEN_PALM
                        else -> Gesture.UNKNOWN
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
                Gesture.UNKNOWN -> unknown("未检测到 OK 或张开手掌", hands.size)
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
        UNKNOWN,
    }

    private companion object {
        private const val MODEL_NAME = "hand_landmarker.task"

        fun isOkGesture(hand: List<NormalizedLandmark>): Boolean {
            if (hand.size < 21) return false
            val wrist = hand[0]
            val palmScale = distance(wrist, hand[9]).coerceAtLeast(0.05f)
            val pinchRatio = distance(hand[4], hand[8]) / palmScale
            val middleExtended = distance(hand[12], wrist) > distance(hand[10], wrist) * 1.05f
            val ringExtended = distance(hand[16], wrist) > distance(hand[14], wrist) * 1.05f
            val pinkyExtended = distance(hand[20], wrist) > distance(hand[18], wrist) * 1.05f
            return pinchRatio < 0.4f && middleExtended && ringExtended && pinkyExtended
        }

        fun isOpenPalm(hand: List<NormalizedLandmark>): Boolean {
            if (hand.size < 21) return false
            val wrist = hand[0]
            val palmScale = distance(wrist, hand[9]).coerceAtLeast(0.05f)
            val indexExtended = fingerExtended(hand, wrist, 5, 6, 8)
            val middleExtended = fingerExtended(hand, wrist, 9, 10, 12)
            val ringExtended = fingerExtended(hand, wrist, 13, 14, 16)
            val pinkyExtended = fingerExtended(hand, wrist, 17, 18, 20)
            val fingersSpread =
                distance(hand[8], hand[12]) / palmScale > 0.22f &&
                    distance(hand[12], hand[16]) / palmScale > 0.18f &&
                    distance(hand[16], hand[20]) / palmScale > 0.16f
            val thumbAway = distance(hand[4], hand[9]) / palmScale > 0.45f
            val tipsAboveMcp =
                hand[8].y() < hand[5].y() + 0.05f &&
                    hand[12].y() < hand[9].y() + 0.05f &&
                    hand[16].y() < hand[13].y() + 0.05f &&
                    hand[20].y() < hand[17].y() + 0.05f
            val planarPalm = abs(hand[5].z() - hand[17].z()) < 0.18f
            return indexExtended &&
                middleExtended &&
                ringExtended &&
                pinkyExtended &&
                fingersSpread &&
                thumbAway &&
                tipsAboveMcp &&
                planarPalm
        }

        fun fingerExtended(
            hand: List<NormalizedLandmark>,
            wrist: NormalizedLandmark,
            mcp: Int,
            pip: Int,
            tip: Int,
        ): Boolean {
            return distance(hand[tip], wrist) > distance(hand[pip], wrist) * 1.08f &&
                distance(hand[tip], hand[mcp]) > distance(hand[pip], hand[mcp]) * 1.12f
        }

        fun distance(a: NormalizedLandmark, b: NormalizedLandmark): Float {
            val x = a.x() - b.x()
            val y = a.y() - b.y()
            val z = a.z() - b.z()
            return sqrt(x * x + y * y + z * z)
        }
    }
}

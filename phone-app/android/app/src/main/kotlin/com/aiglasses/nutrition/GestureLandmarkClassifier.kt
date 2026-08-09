package com.aiglasses.nutrition

import kotlin.math.abs
import kotlin.math.sqrt

internal enum class GestureKind {
    OK,
    OPEN_PALM,
    FIST,
    UNKNOWN,
}

internal data class GestureLandmark(
    val x: Float,
    val y: Float,
    val z: Float,
)

internal object GestureLandmarkClassifier {
    fun classify(hand: List<GestureLandmark>): GestureKind = when {
        isOkGesture(hand) -> GestureKind.OK
        isOpenPalm(hand) -> GestureKind.OPEN_PALM
        isFist(hand) -> GestureKind.FIST
        else -> GestureKind.UNKNOWN
    }

    private fun isOkGesture(hand: List<GestureLandmark>): Boolean {
        if (hand.size < 21) return false
        val wrist = hand[0]
        val palmScale = distance(wrist, hand[9]).coerceAtLeast(0.05f)
        val pinchRatio = distance(hand[4], hand[8]) / palmScale
        val middleExtended = distance(hand[12], wrist) > distance(hand[10], wrist) * 1.05f
        val ringExtended = distance(hand[16], wrist) > distance(hand[14], wrist) * 1.05f
        val pinkyExtended = distance(hand[20], wrist) > distance(hand[18], wrist) * 1.05f
        return pinchRatio < 0.4f && middleExtended && ringExtended && pinkyExtended
    }

    private fun isOpenPalm(hand: List<GestureLandmark>): Boolean {
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
            hand[8].y < hand[5].y + 0.05f &&
                hand[12].y < hand[9].y + 0.05f &&
                hand[16].y < hand[13].y + 0.05f &&
                hand[20].y < hand[17].y + 0.05f
        val planarPalm = abs(hand[5].z - hand[17].z) < 0.18f
        return indexExtended &&
            middleExtended &&
            ringExtended &&
            pinkyExtended &&
            fingersSpread &&
            thumbAway &&
            tipsAboveMcp &&
            planarPalm
    }

    private fun isFist(hand: List<GestureLandmark>): Boolean {
        if (hand.size < 21) return false
        val wrist = hand[0]
        val palmScale = distance(wrist, hand[9]).coerceAtLeast(0.05f)
        val foldedFingers = listOf(8 to 6, 12 to 10, 16 to 14, 20 to 18).count { (tip, pip) ->
            distance(hand[tip], wrist) < distance(hand[pip], wrist) * 1.05f
        }
        val fingertipCluster = listOf(8, 12, 16, 20).all {
            distance(hand[it], hand[9]) / palmScale < 0.85f
        }
        return foldedFingers == 4 && fingertipCluster
    }

    private fun fingerExtended(
        hand: List<GestureLandmark>,
        wrist: GestureLandmark,
        mcp: Int,
        pip: Int,
        tip: Int,
    ): Boolean {
        return distance(hand[tip], wrist) > distance(hand[pip], wrist) * 1.08f &&
            distance(hand[tip], hand[mcp]) > distance(hand[pip], hand[mcp]) * 1.12f
    }

    private fun distance(a: GestureLandmark, b: GestureLandmark): Float {
        val x = a.x - b.x
        val y = a.y - b.y
        val z = a.z - b.z
        return sqrt(x * x + y * y + z * z)
    }
}

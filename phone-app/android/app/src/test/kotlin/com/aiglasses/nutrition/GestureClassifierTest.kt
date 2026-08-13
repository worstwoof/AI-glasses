package com.aiglasses.nutrition

import org.junit.Assert.assertEquals
import org.junit.Test

class GestureClassifierTest {
    @Test
    fun curledFourFingerFixtureIsFist() {
        assertEquals(GestureKind.FIST, GestureLandmarkClassifier.classify(fistFixture()))
    }

    @Test
    fun openPalmFixtureRemainsOpenPalm() {
        assertEquals(GestureKind.OPEN_PALM, GestureLandmarkClassifier.classify(openPalmFixture()))
    }

    @Test
    fun okPinchIsNotFist() {
        assertEquals(GestureKind.OK, GestureLandmarkClassifier.classify(okFixture()))
    }

    @Test
    fun rotatedOpenPalmRemainsOpenPalm() {
        assertEquals(GestureKind.OPEN_PALM, GestureLandmarkClassifier.classify(rotatedOpenPalmFixture()))
    }

    @Test
    fun slightlyRotatedFistRemainsFist() {
        assertEquals(GestureKind.FIST, GestureLandmarkClassifier.classify(rotatedFistFixture()))
    }

    @Test
    fun partiallyFoldedHandDoesNotBecomeFist() {
        assertEquals(GestureKind.UNKNOWN, GestureLandmarkClassifier.classify(partiallyFoldedFixture()))
    }

    @Test
    fun incompleteLandmarksAreUnknown() {
        assertEquals(GestureKind.UNKNOWN, GestureLandmarkClassifier.classify(openPalmFixture().take(12)))
    }

    private fun fistFixture() = listOf(
        p(.50f, .90f),
        p(.34f, .76f), p(.37f, .68f), p(.41f, .70f), p(.43f, .72f),
        p(.43f, .66f), p(.45f, .57f), p(.48f, .68f), p(.49f, .71f),
        p(.50f, .64f), p(.51f, .55f), p(.53f, .68f), p(.54f, .71f),
        p(.57f, .66f), p(.58f, .57f), p(.57f, .69f), p(.58f, .72f),
        p(.63f, .70f), p(.64f, .62f), p(.63f, .70f), p(.62f, .73f),
    )

    private fun openPalmFixture() = listOf(
        p(.50f, .90f),
        p(.30f, .72f), p(.28f, .60f), p(.25f, .48f), p(.20f, .38f),
        p(.40f, .67f), p(.39f, .54f), p(.38f, .40f), p(.37f, .25f),
        p(.50f, .65f), p(.50f, .52f), p(.50f, .37f), p(.50f, .20f),
        p(.60f, .67f), p(.61f, .54f), p(.62f, .40f), p(.63f, .26f),
        p(.70f, .72f), p(.72f, .60f), p(.75f, .48f), p(.80f, .35f),
    )

    private fun rotatedOpenPalmFixture() = listOf(
        p(.55f, .91f),
        p(.34f, .75f), p(.31f, .61f), p(.29f, .49f), p(.25f, .39f),
        p(.45f, .69f), p(.44f, .55f), p(.43f, .41f), p(.42f, .27f),
        p(.55f, .66f), p(.55f, .52f), p(.55f, .37f), p(.55f, .21f),
        p(.65f, .68f), p(.66f, .55f), p(.67f, .41f), p(.68f, .27f),
        p(.75f, .73f), p(.78f, .61f), p(.81f, .49f), p(.85f, .37f),
    )

    private fun rotatedFistFixture() = listOf(
        p(.55f, .91f),
        p(.39f, .77f), p(.42f, .69f), p(.46f, .71f), p(.48f, .74f),
        p(.48f, .68f), p(.50f, .60f), p(.53f, .70f), p(.54f, .74f),
        p(.55f, .66f), p(.56f, .58f), p(.58f, .70f), p(.59f, .74f),
        p(.62f, .68f), p(.64f, .60f), p(.63f, .71f), p(.64f, .75f),
        p(.68f, .72f), p(.70f, .64f), p(.68f, .72f), p(.68f, .76f),
    )

    private fun partiallyFoldedFixture() = listOf(
        p(.50f, .90f),
        p(.34f, .76f), p(.37f, .68f), p(.41f, .70f), p(.43f, .72f),
        p(.43f, .66f), p(.45f, .57f), p(.48f, .68f), p(.49f, .71f),
        p(.50f, .65f), p(.50f, .52f), p(.50f, .37f), p(.50f, .20f),
        p(.57f, .66f), p(.58f, .57f), p(.57f, .69f), p(.58f, .72f),
        p(.63f, .70f), p(.64f, .62f), p(.63f, .70f), p(.62f, .73f),
    )

    private fun okFixture() = listOf(
        p(.50f, .90f),
        p(.40f, .70f), p(.39f, .58f), p(.38f, .45f), p(.47f, .42f),
        p(.43f, .66f), p(.43f, .52f), p(.43f, .38f), p(.47f, .42f),
        p(.52f, .65f), p(.52f, .52f), p(.52f, .38f), p(.52f, .22f),
        p(.62f, .67f), p(.63f, .54f), p(.64f, .40f), p(.65f, .25f),
        p(.70f, .72f), p(.72f, .60f), p(.74f, .48f), p(.76f, .34f),
    )

    private fun p(x: Float, y: Float) = GestureLandmark(x, y, 0f)
}

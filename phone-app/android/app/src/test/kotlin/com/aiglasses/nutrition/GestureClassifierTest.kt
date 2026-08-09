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

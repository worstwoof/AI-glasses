package com.aiglasses.nutrition

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val classifierExecutor = Executors.newSingleThreadExecutor()
    private var sceneClassifier: PhoneSceneClassifier? = null
    private var foodPresenceClassifier: FoodPresenceClassifier? = null
    private var foodPresenceClassifierError: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        HotspotNetworkDetector.install()
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.aiglasses.nutrition/scene_classifier",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "classifyJpeg" -> {
                    val bytes = call.arguments as? ByteArray
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("invalid_frame", "JPEG bytes are empty", null)
                        return@setMethodCallHandler
                    }
                    classifierExecutor.execute {
                        try {
                            val classification = classifier().classifyJpeg(bytes)
                            runOnUiThread { result.success(classification) }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "classification_failed",
                                    error.message ?: error.javaClass.simpleName,
                                    null,
                                )
                            }
                        }
                    }
                }
                "predictFoodProbability" -> {
                    val bytes = call.arguments as? ByteArray
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("invalid_frame", "JPEG bytes are empty", null)
                        return@setMethodCallHandler
                    }
                    classifierExecutor.execute {
                        try {
                            val probability = foodClassifier().predictFoodProbability(bytes)
                            runOnUiThread { result.success(probability) }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "food_classification_failed",
                                    error.message ?: error.javaClass.simpleName,
                                    null,
                                )
                            }
                        }
                    }
                }
                "foodModelStatus" -> {
                    classifierExecutor.execute {
                        try {
                            val classifier = foodClassifier()
                            runOnUiThread {
                                result.success(
                                    mapOf(
                                        "loaded" to true,
                                        "runtime" to classifier.runtimeName,
                                        "inputShape" to classifier.inputShape.toList(),
                                        "outputShape" to classifier.outputShape.toList(),
                                    ),
                                )
                            }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.success(
                                    mapOf(
                                        "loaded" to false,
                                        "runtime" to "cpu",
                                        "error" to (error.message ?: error.javaClass.simpleName),
                                    ),
                                )
                            }
                        }
                    }
                }
                "reset" -> {
                    classifierExecutor.execute {
                        sceneClassifier?.close()
                        sceneClassifier = null
                        foodPresenceClassifier?.close()
                        foodPresenceClassifier = null
                        foodPresenceClassifierError = null
                        runOnUiThread { result.success(true) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        sceneClassifier?.close()
        foodPresenceClassifier?.close()
        classifierExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun classifier(): PhoneSceneClassifier =
        sceneClassifier ?: PhoneSceneClassifier(applicationContext).also {
            sceneClassifier = it
        }

    private fun foodClassifier(): FoodPresenceClassifier =
        foodPresenceClassifier
            ?: foodPresenceClassifierError?.let { throw IllegalStateException(it) }
            ?: try {
                FoodPresenceClassifier(applicationContext).also {
                    foodPresenceClassifier = it
                }
            } catch (error: Exception) {
                foodPresenceClassifierError =
                    error.message ?: error.javaClass.simpleName
                throw error
            }
}

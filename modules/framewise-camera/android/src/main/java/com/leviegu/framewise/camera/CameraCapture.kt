package com.leviegu.framewise.camera

import android.graphics.BitmapFactory
import android.net.Uri
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.exifinterface.media.ExifInterface
import expo.modules.kotlin.Promise
import java.io.File
import java.util.concurrent.Executor
import java.util.concurrent.atomic.AtomicBoolean

class CameraCapture(
  private val cacheDirectory: File,
  private val executor: Executor,
  private val emitLog: (String, String, Map<String, Any?>) -> Unit
) {
  private val captureInProgress = AtomicBoolean(false)

  fun takePicture(
    imageCapture: ImageCapture,
    lensId: String,
    zoomRatio: Float,
    promise: Promise
  ) {
    if (!captureInProgress.compareAndSet(false, true)) {
      promise.reject("E_CAPTURE_IN_PROGRESS", "已有拍照任务正在进行", null)
      return
    }

    emitLog(
      "info",
      "camera.capture_started",
      mapOf("lensId" to lensId, "zoomRatio" to zoomRatio)
    )
    val outputFile = try {
      File.createTempFile("framewise-", ".jpg", cacheDirectory)
    } catch (error: Exception) {
      captureInProgress.set(false)
      emitCaptureFailure("camera.capture_file_failed", error)
      promise.reject("E_CAPTURE_FILE_FAILED", error.message ?: "无法创建照片文件", error)
      return
    }
    val outputOptions = ImageCapture.OutputFileOptions.Builder(outputFile).build()

    try {
      imageCapture.takePicture(
        outputOptions,
        executor,
        object : ImageCapture.OnImageSavedCallback {
          override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
            captureInProgress.set(false)
            try {
              val (width, height) = readImageDimensions(outputFile)
              emitLog(
                "info",
                "camera.capture_completed",
                mapOf(
                  "width" to width,
                  "height" to height,
                  "lensId" to lensId,
                  "zoomRatio" to zoomRatio
                )
              )
              promise.resolve(
                mapOf(
                  "uri" to Uri.fromFile(outputFile).toString(),
                  "width" to width,
                  "height" to height,
                  "lensId" to lensId,
                  "zoomRatio" to zoomRatio
                )
              )
            } catch (error: Exception) {
              outputFile.delete()
              emitCaptureFailure("camera.capture_result_failed", error)
              promise.reject("E_CAPTURE_RESULT_FAILED", error.message ?: "无法读取照片", error)
            }
          }

          override fun onError(exception: ImageCaptureException) {
            captureInProgress.set(false)
            outputFile.delete()
            emitCaptureFailure(
              "camera.capture_failed",
              exception,
              mapOf("errorCode" to exception.imageCaptureError)
            )
            promise.reject("E_CAPTURE_FAILED", exception.message ?: "拍照失败", exception)
          }
        }
      )
    } catch (error: Exception) {
      captureInProgress.set(false)
      outputFile.delete()
      emitCaptureFailure("camera.capture_start_failed", error)
      promise.reject("E_CAPTURE_FAILED", error.message ?: "拍照失败", error)
    }
  }

  private fun readImageDimensions(file: File): Pair<Int, Int> {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(file.absolutePath, bounds)
    val orientation = ExifInterface(file).getAttributeInt(
      ExifInterface.TAG_ORIENTATION,
      ExifInterface.ORIENTATION_NORMAL
    )
    val isRotated = orientation == ExifInterface.ORIENTATION_ROTATE_90 ||
      orientation == ExifInterface.ORIENTATION_ROTATE_270 ||
      orientation == ExifInterface.ORIENTATION_TRANSPOSE ||
      orientation == ExifInterface.ORIENTATION_TRANSVERSE

    return if (isRotated) {
      bounds.outHeight to bounds.outWidth
    } else {
      bounds.outWidth to bounds.outHeight
    }
  }

  private fun emitCaptureFailure(
    event: String,
    error: Exception,
    data: Map<String, Any?> = emptyMap()
  ) {
    emitLog(
      "error",
      event,
      data + mapOf(
        "errorType" to error.javaClass.simpleName,
        "message" to error.message
      )
    )
  }
}

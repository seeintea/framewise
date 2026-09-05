package com.leviegu.framewise.camera

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.Surface
import android.view.View
import android.view.ViewGroup
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.exifinterface.media.ExifInterface
import androidx.lifecycle.LifecycleOwner
import expo.modules.kotlin.AppContext
import expo.modules.kotlin.Promise
import expo.modules.kotlin.viewevent.EventDispatcher
import expo.modules.kotlin.views.ExpoView
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

@SuppressLint("ViewConstructor")
class FramewiseCameraView(
  context: Context,
  appContext: AppContext
) : ExpoView(context, appContext) {
  private val onCameraReady by EventDispatcher<Unit>()
  private val onMountError by EventDispatcher<Map<String, String>>()
  private val mainExecutor = ContextCompat.getMainExecutor(context)
  private val captureInProgress = AtomicBoolean(false)
  private val previewView = PreviewView(context).apply {
    implementationMode = PreviewView.ImplementationMode.COMPATIBLE
    scaleType = PreviewView.ScaleType.FILL_CENTER
    layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
  }

  private var cameraProvider: ProcessCameraProvider? = null
  private var camera: Camera? = null
  private var preview: Preview? = null
  private var imageCapture: ImageCapture? = null
  private var requestedFacing = CameraSelector.LENS_FACING_BACK
  private var boundFacing: Int? = null
  private var requestedFlashEnabled = false
  private var requestedLinearZoom = 0f
  private var isDestroyed = false
  private var isBinding = false

  init {
    addView(previewView)
  }

  override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    measureChild(previewView, widthMeasureSpec, heightMeasureSpec)
    setMeasuredDimension(
      ViewGroup.resolveSize(previewView.measuredWidth, widthMeasureSpec),
      ViewGroup.resolveSize(previewView.measuredHeight, heightMeasureSpec)
    )
  }

  override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
    previewView.layout(0, 0, right - left, bottom - top)
  }

  fun setFacing(facing: String) {
    val nextFacing = when (facing) {
      "front" -> CameraSelector.LENS_FACING_FRONT
      else -> CameraSelector.LENS_FACING_BACK
    }

    if (requestedFacing != nextFacing) {
      requestedFacing = nextFacing
    }
  }

  fun setFlashEnabled(enabled: Boolean) {
    requestedFlashEnabled = enabled
    imageCapture?.flashMode = resolveFlashMode()
  }

  fun setLinearZoom(zoom: Float) {
    requestedLinearZoom = zoom.coerceIn(0f, 1f)
    camera?.cameraControl?.setLinearZoom(requestedLinearZoom)
  }

  fun bindCamera() {
    if (isDestroyed || isBinding) {
      return
    }

    if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
      emitMountError("没有相机权限")
      return
    }

    if (camera != null && boundFacing == requestedFacing) {
      setFlashEnabled(requestedFlashEnabled)
      setLinearZoom(requestedLinearZoom)
      return
    }

    val lifecycleOwner = appContext.currentActivity as? LifecycleOwner
    if (lifecycleOwner == null) {
      emitMountError("当前 Activity 不支持相机生命周期")
      return
    }

    isBinding = true
    val providerFuture = ProcessCameraProvider.getInstance(context)
    providerFuture.addListener(
      {
        try {
          if (isDestroyed) {
            isBinding = false
            return@addListener
          }

          val provider = providerFuture.get()
          val selector = CameraSelector.Builder()
            .requireLensFacing(requestedFacing)
            .build()
          val resolutionSelector = ResolutionSelector.Builder()
            .setAspectRatioStrategy(AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY)
            .build()
          val targetRotation = previewView.display?.rotation ?: Surface.ROTATION_0
          val nextPreview = Preview.Builder()
            .setResolutionSelector(resolutionSelector)
            .setTargetRotation(targetRotation)
            .build()
            .also { it.surfaceProvider = previewView.surfaceProvider }
          val nextImageCapture = ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
            .setFlashMode(resolveFlashMode())
            .setResolutionSelector(resolutionSelector)
            .setTargetRotation(targetRotation)
            .build()

          unbindUseCases()
          camera = provider.bindToLifecycle(
            lifecycleOwner,
            selector,
            nextPreview,
            nextImageCapture
          )
          cameraProvider = provider
          preview = nextPreview
          imageCapture = nextImageCapture
          boundFacing = requestedFacing
          isBinding = false
          setLinearZoom(requestedLinearZoom)
          onCameraReady(Unit)
        } catch (error: Exception) {
          isBinding = false
          emitMountError(error.message ?: "相机启动失败")
        }
      },
      mainExecutor
    )
  }

  fun takePicture(promise: Promise) {
    val capture = imageCapture
    if (capture == null) {
      promise.reject("E_CAMERA_NOT_READY", "相机尚未就绪", null)
      return
    }

    if (!captureInProgress.compareAndSet(false, true)) {
      promise.reject("E_CAPTURE_IN_PROGRESS", "已有拍照任务正在进行", null)
      return
    }

    val outputFile = File.createTempFile("framewise-", ".jpg", appContext.cacheDirectory)
    val outputOptions = ImageCapture.OutputFileOptions.Builder(outputFile).build()

    capture.takePicture(
      outputOptions,
      mainExecutor,
      object : ImageCapture.OnImageSavedCallback {
        override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
          captureInProgress.set(false)
          val (width, height) = readImageDimensions(outputFile)
          promise.resolve(
            mapOf(
              "uri" to Uri.fromFile(outputFile).toString(),
              "width" to width,
              "height" to height
            )
          )
        }

        override fun onError(exception: ImageCaptureException) {
          captureInProgress.set(false)
          outputFile.delete()
          promise.reject("E_CAPTURE_FAILED", exception.message ?: "拍照失败", exception)
        }
      }
    )
  }

  fun cleanup() {
    isDestroyed = true
    unbindUseCases()
    camera = null
    cameraProvider = null
  }

  private fun resolveFlashMode() =
    if (requestedFlashEnabled) ImageCapture.FLASH_MODE_ON else ImageCapture.FLASH_MODE_OFF

  private fun unbindUseCases() {
    val useCases = listOfNotNull(preview, imageCapture)
    if (useCases.isNotEmpty()) {
      cameraProvider?.unbind(*useCases.toTypedArray())
    }
    preview = null
    imageCapture = null
    camera = null
    boundFacing = null
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

  private fun emitMountError(message: String) {
    onMountError(mapOf("message" to message))
  }
}

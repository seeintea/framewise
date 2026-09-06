package com.leviegu.framewise.camera

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.net.Uri
import android.os.Build
import android.view.Surface
import android.view.View
import android.view.ViewGroup
import androidx.annotation.OptIn
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.Camera
import androidx.camera.core.CameraFilter
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.CameraState
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.lifecycle.awaitInstance
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.exifinterface.media.ExifInterface
import androidx.lifecycle.LifecycleOwner
import expo.modules.kotlin.AppContext
import expo.modules.kotlin.Promise
import expo.modules.kotlin.viewevent.EventDispatcher
import expo.modules.kotlin.views.ExpoView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

@SuppressLint("ViewConstructor")
class FramewiseCameraView(
  context: Context,
  appContext: AppContext
) : ExpoView(context, appContext) {
  private val onCameraReady by EventDispatcher<Unit>()
  private val onMountError by EventDispatcher<Map<String, String>>()
  private val onCapabilitiesChanged by EventDispatcher<Map<String, Any?>>()
  private val mainExecutor = ContextCompat.getMainExecutor(context)
  private val captureInProgress = AtomicBoolean(false)
  private val cameraScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
  private val currentActivity
    get() = appContext.throwingActivity as LifecycleOwner
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
  private var requestedLensId: String? = null
  private var boundLensId: String? = null
  private var requestedFlashEnabled = false
  private var requestedZoomRatio = 1f
  private var requestedExposureCompensation = 0
  private var isDestroyed = false
  private var isBinding = false
  private var shouldCreateCamera = true

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
      requestedLensId = null
    }
    shouldCreateCamera = true
  }

  fun setLensId(lensId: String?) {
    if (requestedLensId != lensId) {
      requestedLensId = lensId
      shouldCreateCamera = true
    }
  }

  fun setFlashEnabled(enabled: Boolean) {
    requestedFlashEnabled = enabled
    imageCapture?.flashMode = resolveFlashMode()
  }

  fun setZoomRatio(zoomRatio: Float) {
    requestedZoomRatio = zoomRatio
    val activeCamera = camera ?: return
    val zoomState = activeCamera.cameraInfo.zoomState.value ?: return
    val appliedRatio = zoomRatio.coerceIn(zoomState.minZoomRatio, zoomState.maxZoomRatio)
    requestedZoomRatio = appliedRatio
    val result = activeCamera.cameraControl.setZoomRatio(appliedRatio)
    result.addListener(
      {
        runCatching { result.get() }
          .onSuccess { emitCapabilities() }
      },
      mainExecutor
    )
  }

  fun setExposureCompensation(index: Int) {
    requestedExposureCompensation = index
    val activeCamera = camera ?: return
    val exposureState = activeCamera.cameraInfo.exposureState
    if (!exposureState.isExposureCompensationSupported) {
      return
    }

    val appliedIndex = index.coerceIn(
      exposureState.exposureCompensationRange.lower,
      exposureState.exposureCompensationRange.upper
    )
    requestedExposureCompensation = appliedIndex
    val result = activeCamera.cameraControl.setExposureCompensationIndex(appliedIndex)
    result.addListener(
      {
        runCatching { result.get() }
          .onSuccess { emitCapabilities() }
      },
      mainExecutor
    )
  }

  fun recreateCamera() {
    cameraScope.launch {
      createCamera()
    }
  }

  private suspend fun createCamera() {
    if (isDestroyed || isBinding || !shouldCreateCamera) {
      return
    }
    shouldCreateCamera = false

    if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
      shouldCreateCamera = true
      emitMountError("没有相机权限")
      return
    }

    if (
      camera != null &&
      boundFacing == requestedFacing &&
      (requestedLensId == null || boundLensId == requestedLensId)
    ) {
      setFlashEnabled(requestedFlashEnabled)
      return
    }

    isBinding = true
    val targetFacing = requestedFacing
    val targetLensId = requestedLensId
    try {
      val provider = ProcessCameraProvider.awaitInstance(context)
      if (isDestroyed) {
        isBinding = false
        return
      }

      val selectorBuilder = CameraSelector.Builder()
        .requireLensFacing(targetFacing)
      targetLensId?.let { lensId ->
        selectorBuilder.addCameraFilter(
          CameraFilter { cameraInfos ->
            cameraInfos.filter { getCameraId(it) == lensId }
          }
        )
      }
      val selector = selectorBuilder.build()
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

      provider.unbindAll()
      val nextCamera = provider.bindToLifecycle(
        currentActivity,
        selector,
        nextPreview,
        nextImageCapture
      )
      cameraProvider = provider
      camera = nextCamera
      preview = nextPreview
      imageCapture = nextImageCapture
      boundFacing = targetFacing
      boundLensId = getCameraId(nextCamera.cameraInfo)
      observeCameraState(nextCamera.cameraInfo)
      isBinding = false
      setZoomRatio(requestedZoomRatio)
      setExposureCompensation(requestedExposureCompensation)
      emitCapabilities()

      if (requestedFacing != targetFacing || requestedLensId != targetLensId) {
        shouldCreateCamera = true
        recreateCamera()
      }
    } catch (error: Exception) {
      isBinding = false
      shouldCreateCamera = true
      emitMountError(error.message ?: "相机启动失败")
    }
  }

  private fun observeCameraState(cameraInfo: CameraInfo) {
    cameraInfo.cameraState.observe(currentActivity) { state ->
      if (state.type == CameraState.Type.OPEN) {
        onCameraReady(Unit)
      }
    }
  }

  fun focusAt(normalizedX: Float, normalizedY: Float, promise: Promise) {
    val activeCamera = camera
    if (activeCamera == null || previewView.width == 0 || previewView.height == 0) {
      promise.reject("E_CAMERA_NOT_READY", "相机尚未就绪", null)
      return
    }

    val point = previewView.meteringPointFactory.createPoint(
      normalizedX.coerceIn(0f, 1f) * previewView.width,
      normalizedY.coerceIn(0f, 1f) * previewView.height
    )
    val action = FocusMeteringAction.Builder(
      point,
      FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE
    )
      .setAutoCancelDuration(3, TimeUnit.SECONDS)
      .build()

    if (!activeCamera.cameraInfo.isFocusMeteringSupported(action)) {
      promise.reject("E_FOCUS_UNSUPPORTED", "当前镜头不支持点击聚焦或测光", null)
      return
    }

    val result = activeCamera.cameraControl.startFocusAndMetering(action)
    result.addListener(
      {
        runCatching { result.get() }
          .onSuccess { focusResult ->
            promise.resolve(mapOf("focusSuccessful" to focusResult.isFocusSuccessful))
          }
          .onFailure { error ->
            promise.reject("E_FOCUS_FAILED", error.message ?: "聚焦失败", error)
          }
      },
      mainExecutor
    )
  }

  fun takePicture(promise: Promise) {
    val capture = imageCapture
    val activeCamera = camera
    if (capture == null || activeCamera == null) {
      promise.reject("E_CAMERA_NOT_READY", "相机尚未就绪", null)
      return
    }

    if (!captureInProgress.compareAndSet(false, true)) {
      promise.reject("E_CAPTURE_IN_PROGRESS", "已有拍照任务正在进行", null)
      return
    }

    val captureLensId = getCameraId(activeCamera.cameraInfo)
    val captureZoomRatio = activeCamera.cameraInfo.zoomState.value?.zoomRatio ?: requestedZoomRatio
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
              "height" to height,
              "lensId" to captureLensId,
              "zoomRatio" to captureZoomRatio
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
    cameraScope.cancel()
    unbindUseCases()
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
    boundLensId = null
  }

  @OptIn(ExperimentalCamera2Interop::class)
  private fun emitCapabilities() {
    if (isBinding) {
      return
    }

    val provider = cameraProvider ?: return
    val activeCamera = camera ?: return
    val activeInfo = activeCamera.cameraInfo
    val zoomState = activeInfo.zoomState.value
    val exposureState = activeInfo.exposureState
    val cameraInfos = provider.availableCameraInfos.filter {
      it.lensFacing == requestedFacing
    }

    onCapabilitiesChanged(
      mapOf(
        "lenses" to cameraInfos.map { serializeLens(it) },
        "activeLensId" to getCameraId(activeInfo),
        "zoomRatio" to (zoomState?.zoomRatio ?: requestedZoomRatio),
        "exposureCompensation" to exposureState.exposureCompensationIndex
      )
    )
  }

  @OptIn(ExperimentalCamera2Interop::class)
  private fun serializeLens(cameraInfo: CameraInfo): Map<String, Any?> {
    val camera2Info = Camera2CameraInfo.from(cameraInfo)
    val zoomState = cameraInfo.zoomState.value
    val exposureState = cameraInfo.exposureState
    val exposureRange = exposureState.exposureCompensationRange
    val focusAction = FocusMeteringAction.Builder(
      previewView.meteringPointFactory.createPoint(
        previewView.width.coerceAtLeast(1) / 2f,
        previewView.height.coerceAtLeast(1) / 2f
      ),
      FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE
    ).build()
    val physicalCameraIds = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      runCatching {
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        cameraManager.getCameraCharacteristics(camera2Info.cameraId).physicalCameraIds.toList()
      }.getOrDefault(emptyList())
    } else {
      emptyList()
    }

    return mapOf(
      "id" to camera2Info.cameraId,
      "facing" to if (cameraInfo.lensFacing == CameraSelector.LENS_FACING_FRONT) "front" else "back",
      "focalLengths" to camera2Info
        .getCameraCharacteristic(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
        ?.toList()
        .orEmpty(),
      "minimumZoomRatio" to (zoomState?.minZoomRatio ?: 1f),
      "maximumZoomRatio" to (zoomState?.maxZoomRatio ?: 1f),
      "intrinsicZoomRatio" to cameraInfo.intrinsicZoomRatio,
      "supportsFlash" to cameraInfo.hasFlashUnit(),
      "supportsFocusMetering" to cameraInfo.isFocusMeteringSupported(focusAction),
      "isLogicalMultiCamera" to cameraInfo.isLogicalMultiCameraSupported,
      "physicalCameraIds" to physicalCameraIds,
      "exposureCompensationRange" to if (exposureState.isExposureCompensationSupported) {
        mapOf(
          "minimum" to exposureRange.lower,
          "maximum" to exposureRange.upper,
          "step" to exposureState.exposureCompensationStep.toFloat()
        )
      } else {
        null
      }
    )
  }

  @OptIn(ExperimentalCamera2Interop::class)
  private fun getCameraId(cameraInfo: CameraInfo) = Camera2CameraInfo.from(cameraInfo).cameraId

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

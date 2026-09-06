package com.leviegu.framewise.camera

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.os.SystemClock
import android.util.Log
import android.view.Surface
import android.view.View
import android.view.ViewGroup
import androidx.camera.core.Camera
import androidx.camera.core.CameraFilter
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.CameraState
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageCapture
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.lifecycle.awaitInstance
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
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
import java.util.concurrent.TimeUnit

private const val LOG_TAG = "FramewiseCamera"

@SuppressLint("ViewConstructor")
class FramewiseCameraView(
  context: Context,
  appContext: AppContext
) : ExpoView(context, appContext) {
  private val onCameraReady by EventDispatcher<Unit>()
  private val onMountError by EventDispatcher<Map<String, String>>()
  private val onCapabilitiesChanged by EventDispatcher<Map<String, Any?>>()
  private val onLog by EventDispatcher<Map<String, Any?>>()
  private val mainExecutor = ContextCompat.getMainExecutor(context)
  private val cameraScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
  private val currentActivity
    get() = appContext.throwingActivity as LifecycleOwner
  private val previewView = PreviewView(context).apply {
    implementationMode = PreviewView.ImplementationMode.COMPATIBLE
    scaleType = PreviewView.ScaleType.FILL_CENTER
    layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
  }
  private val capabilitiesReader = CameraCapabilitiesReader(previewView)
  private val cameraCapture = CameraCapture(
    appContext.cacheDirectory,
    mainExecutor,
    ::emitLog
  )

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
  private var observedCameraInfo: CameraInfo? = null
  private var observedLifecycleOwner: LifecycleOwner? = null
  private var isDestroyed = false
  private var isBinding = false
  private var shouldCreateCamera = true

  init {
    previewView.setOnHierarchyChangeListener(object : ViewGroup.OnHierarchyChangeListener {
      override fun onChildViewRemoved(parent: View?, child: View?) = Unit

      override fun onChildViewAdded(parent: View?, child: View?) {
        emitLog(
          "debug",
          "camera.preview_child_added",
          mapOf(
            "childType" to child?.javaClass?.simpleName,
            "width" to measuredWidth,
            "height" to measuredHeight
          )
        )
        parent?.measure(
          MeasureSpec.makeMeasureSpec(measuredWidth, MeasureSpec.EXACTLY),
          MeasureSpec.makeMeasureSpec(measuredHeight, MeasureSpec.EXACTLY)
        )
        parent?.layout(0, 0, parent.measuredWidth, parent.measuredHeight)
      }
    })
    addView(previewView)
    Log.i(LOG_TAG, "camera.view_created")
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
    if (
      boundFacing != requestedFacing ||
      (requestedLensId != null && boundLensId != requestedLensId)
    ) {
      return
    }
    val activeCamera = camera ?: return
    val zoomState = activeCamera.cameraInfo.zoomState.value ?: return
    val appliedRatio = zoomRatio.coerceIn(zoomState.minZoomRatio, zoomState.maxZoomRatio)
    requestedZoomRatio = appliedRatio
    val result = activeCamera.cameraControl.setZoomRatio(appliedRatio)
    result.addListener(
      {
        runCatching { result.get() }
          .onSuccess { emitCapabilities() }
          .onFailure { error ->
            emitControlFailure("camera.zoom_failed", error)
          }
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
          .onFailure { error ->
            emitControlFailure("camera.exposure_failed", error)
          }
      },
      mainExecutor
    )
  }

  fun recreateCamera() {
    emitLog(
      "debug",
      "camera.create_requested",
      mapOf(
        "shouldCreateCamera" to shouldCreateCamera,
        "isBinding" to isBinding,
        "isDestroyed" to isDestroyed
      )
    )
    cameraScope.launch {
      createCamera()
    }
  }

  private suspend fun createCamera() {
    if (isDestroyed || isBinding || !shouldCreateCamera) {
      emitLog(
        "debug",
        "camera.create_skipped",
        mapOf(
          "shouldCreateCamera" to shouldCreateCamera,
          "isBinding" to isBinding,
          "isDestroyed" to isDestroyed
        )
      )
      return
    }
    shouldCreateCamera = false

    if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
      shouldCreateCamera = true
      emitLog("error", "camera.permission_missing")
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
      val providerWaitStartedAt = SystemClock.elapsedRealtime()
      emitLog("info", "camera.provider_wait_started")
      val provider = ProcessCameraProvider.awaitInstance(context)
      emitLog(
        "info",
        "camera.provider_ready",
        mapOf("elapsedMs" to SystemClock.elapsedRealtime() - providerWaitStartedAt)
      )
      if (isDestroyed) {
        isBinding = false
        emitLog("debug", "camera.create_cancelled")
        return
      }

      val selectorBuilder = CameraSelector.Builder()
        .requireLensFacing(targetFacing)
      targetLensId?.let { lensId ->
        val logicalCameraId = capabilitiesReader.getLogicalCameraId(lensId)
        selectorBuilder.addCameraFilter(
          CameraFilter { cameraInfos ->
            cameraInfos.filter { capabilitiesReader.getCameraId(it) == logicalCameraId }
          }
        )
        capabilitiesReader.getPhysicalCameraId(lensId)?.let {
          selectorBuilder.setPhysicalCameraId(it)
        }
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

      val bindStartedAt = SystemClock.elapsedRealtime()
      emitLog(
        "info",
        "camera.bind_started",
        mapOf(
          "facing" to facingName(targetFacing),
          "lensId" to targetLensId,
          "previewWidth" to previewView.width,
          "previewHeight" to previewView.height
        )
      )
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
      boundLensId = targetLensId ?: capabilitiesReader.getCameraId(nextCamera.cameraInfo)
      emitLog(
        "info",
        "camera.bind_completed",
        mapOf(
          "elapsedMs" to SystemClock.elapsedRealtime() - bindStartedAt,
          "facing" to facingName(targetFacing),
          "lensId" to boundLensId
        )
      )
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
      emitLog(
        "error",
        "camera.create_failed",
        mapOf(
          "errorType" to error.javaClass.simpleName,
          "message" to error.message
        )
      )
      emitMountError(error.message ?: "相机启动失败")
    }
  }

  private fun observeCameraState(cameraInfo: CameraInfo) {
    observedLifecycleOwner?.let { owner ->
      observedCameraInfo?.cameraState?.removeObservers(owner)
    }
    val lifecycleOwner = currentActivity
    observedCameraInfo = cameraInfo
    observedLifecycleOwner = lifecycleOwner
    cameraInfo.cameraState.observe(lifecycleOwner) { state ->
      emitLog(
        if (state.error == null) "info" else "error",
        "camera.state_changed",
        mapOf(
          "state" to state.type.name,
          "errorCode" to state.error?.code
        )
      )
      if (state.type == CameraState.Type.OPEN) {
        emitLog("info", "camera.ready_emitted")
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

    val captureLensId = boundLensId ?: capabilitiesReader.getCameraId(activeCamera.cameraInfo)
    val captureZoomRatio = activeCamera.cameraInfo.zoomState.value?.zoomRatio ?: requestedZoomRatio
    cameraCapture.takePicture(capture, captureLensId, captureZoomRatio, promise)
  }

  fun cleanup() {
    emitLog("info", "camera.cleanup")
    isDestroyed = true
    cameraScope.cancel()
    observedLifecycleOwner?.let { owner ->
      observedCameraInfo?.cameraState?.removeObservers(owner)
    }
    observedCameraInfo = null
    observedLifecycleOwner = null
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

  private fun emitCapabilities() {
    if (isBinding) {
      return
    }

    val provider = cameraProvider ?: return
    val activeCamera = camera ?: return
    onCapabilitiesChanged(
      capabilitiesReader.read(
        provider,
        activeCamera,
        requestedFacing,
        requestedZoomRatio,
        boundLensId ?: capabilitiesReader.getCameraId(activeCamera.cameraInfo)
      )
    )
  }

  private fun emitMountError(message: String) {
    onMountError(mapOf("message" to message))
  }

  private fun facingName(facing: Int) =
    if (facing == CameraSelector.LENS_FACING_FRONT) "front" else "back"

  private fun emitControlFailure(event: String, error: Throwable) {
    emitLog(
      "error",
      event,
      mapOf(
        "errorType" to error.javaClass.simpleName,
        "message" to error.message
      )
    )
  }

  private fun emitLog(
    level: String,
    event: String,
    data: Map<String, Any?> = emptyMap()
  ) {
    val message = "$event $data"
    when (level) {
      "error" -> Log.e(LOG_TAG, message)
      "warn" -> Log.w(LOG_TAG, message)
      "debug" -> Log.d(LOG_TAG, message)
      else -> Log.i(LOG_TAG, message)
    }

    onLog(
      mapOf(
        "timestampMs" to System.currentTimeMillis(),
        "level" to level,
        "scope" to "native-camera",
        "event" to event,
        "data" to data
      )
    )
  }
}

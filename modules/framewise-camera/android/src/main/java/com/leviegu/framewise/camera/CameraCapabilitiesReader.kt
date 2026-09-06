package com.leviegu.framewise.camera

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import androidx.annotation.OptIn
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.Camera
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.FocusMeteringAction
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView

class CameraCapabilitiesReader(
  private val context: Context,
  private val previewView: PreviewView
) {
  @OptIn(ExperimentalCamera2Interop::class)
  fun read(
    provider: ProcessCameraProvider,
    activeCamera: Camera,
    requestedFacing: Int,
    requestedZoomRatio: Float
  ): Map<String, Any?> {
    val activeInfo = activeCamera.cameraInfo
    val zoomState = activeInfo.zoomState.value
    val exposureState = activeInfo.exposureState
    val cameraInfos = provider.availableCameraInfos.filter {
      it.lensFacing == requestedFacing
    }

    return mapOf(
      "lenses" to cameraInfos.map { serializeLens(it) },
      "activeLensId" to getCameraId(activeInfo),
      "zoomRatio" to (zoomState?.zoomRatio ?: requestedZoomRatio),
      "exposureCompensation" to exposureState.exposureCompensationIndex
    )
  }

  @OptIn(ExperimentalCamera2Interop::class)
  fun getCameraId(cameraInfo: CameraInfo) = Camera2CameraInfo.from(cameraInfo).cameraId

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
}

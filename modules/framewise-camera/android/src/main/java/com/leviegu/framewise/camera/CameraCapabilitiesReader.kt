package com.leviegu.framewise.camera

import android.hardware.camera2.CameraCharacteristics
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
  private val previewView: PreviewView
) {
  @OptIn(ExperimentalCamera2Interop::class)
  fun read(
    provider: ProcessCameraProvider,
    activeCamera: Camera,
    requestedFacing: Int,
    requestedZoomRatio: Float,
    activeLensId: String
  ): Map<String, Any?> {
    val activeInfo = activeCamera.cameraInfo
    val zoomState = activeInfo.zoomState.value
    val exposureState = activeInfo.exposureState
    val cameraInfos = provider.availableCameraInfos.filter {
      it.lensFacing == requestedFacing
    }

    return mapOf(
      "lenses" to serializeAvailableLenses(cameraInfos),
      "activeLensId" to activeLensId,
      "zoomRatio" to (zoomState?.zoomRatio ?: requestedZoomRatio),
      "exposureCompensation" to exposureState.exposureCompensationIndex
    )
  }

  @OptIn(ExperimentalCamera2Interop::class)
  fun getCameraId(cameraInfo: CameraInfo) = Camera2CameraInfo.from(cameraInfo).cameraId

  fun getLogicalCameraId(lensId: String) = lensId.substringBefore(PHYSICAL_LENS_SEPARATOR)

  fun getPhysicalCameraId(lensId: String) = lensId
    .substringAfter(PHYSICAL_LENS_SEPARATOR, missingDelimiterValue = "")
    .ifEmpty { null }

  @OptIn(ExperimentalCamera2Interop::class)
  private fun serializeAvailableLenses(cameraInfos: List<CameraInfo>) = buildList {
    cameraInfos.forEach { logicalCameraInfo ->
      val logicalCameraId = getCameraId(logicalCameraInfo)
      add(serializeLens(logicalCameraInfo, logicalCameraId))

      if (logicalCameraInfo.isLogicalMultiCameraSupported) {
        logicalCameraInfo.physicalCameraInfos.forEach { physicalCameraInfo ->
          val physicalCameraId = getCameraId(physicalCameraInfo)
          add(
            serializeLens(
              physicalCameraInfo,
              "$logicalCameraId$PHYSICAL_LENS_SEPARATOR$physicalCameraId"
            )
          )
        }
      }
    }
  }

  @OptIn(ExperimentalCamera2Interop::class)
  private fun serializeLens(cameraInfo: CameraInfo, lensId: String): Map<String, Any?> {
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

    return mapOf(
      "id" to lensId,
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
      "physicalCameraIds" to cameraInfo.physicalCameraInfos.map(::getCameraId),
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

  private companion object {
    const val PHYSICAL_LENS_SEPARATOR = "::physical::"
  }
}

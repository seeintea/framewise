package com.leviegu.framewise.camera

import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class FramewiseCameraModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("FramewiseCamera")

    View(FramewiseCameraView::class) {
      Events("onCameraReady", "onMountError", "onCapabilitiesChanged", "onLog")

      Prop("facing") { view: FramewiseCameraView, facing: String ->
        view.setFacing(facing)
      }

      Prop("flashEnabled") { view: FramewiseCameraView, enabled: Boolean ->
        view.setFlashEnabled(enabled)
      }

      Prop("lensId") { view: FramewiseCameraView, lensId: String? ->
        view.setLensId(lensId)
      }

      Prop("zoomRatio") { view: FramewiseCameraView, zoomRatio: Float ->
        view.setZoomRatio(zoomRatio)
      }

      Prop("exposureCompensation") { view: FramewiseCameraView, index: Int ->
        view.setExposureCompensation(index)
      }

      OnViewDidUpdateProps { view: FramewiseCameraView ->
        view.recreateCamera()
      }

      OnViewDestroys { view: FramewiseCameraView ->
        view.cleanup()
      }

      AsyncFunction("takePicture") { view: FramewiseCameraView, promise: Promise ->
        view.takePicture(promise)
      }

      AsyncFunction("focusAt") { view: FramewiseCameraView, x: Float, y: Float, promise: Promise ->
        view.focusAt(x, y, promise)
      }
    }
  }
}

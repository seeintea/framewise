package com.leviegu.framewise.camera

import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class FramewiseCameraModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("FramewiseCamera")

    View(FramewiseCameraView::class) {
      Events("onCameraReady", "onMountError")

      Prop("facing") { view: FramewiseCameraView, facing: String ->
        view.setFacing(facing)
      }

      Prop("flashEnabled") { view: FramewiseCameraView, enabled: Boolean ->
        view.setFlashEnabled(enabled)
      }

      Prop("zoom") { view: FramewiseCameraView, zoom: Float ->
        view.setLinearZoom(zoom)
      }

      OnViewDidUpdateProps { view: FramewiseCameraView ->
        view.bindCamera()
      }

      OnViewDestroys { view: FramewiseCameraView ->
        view.cleanup()
      }

      AsyncFunction("takePicture") { view: FramewiseCameraView, promise: Promise ->
        view.takePicture(promise)
      }
    }
  }
}

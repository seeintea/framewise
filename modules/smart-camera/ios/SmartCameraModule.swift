import ExpoModulesCore

public class SmartCameraModule: Module {
  public func definition() -> ModuleDefinition {
    Name("SmartCamera")

    View(SmartCameraView.self) {
    }
  }
}

import { NativeModule, requireNativeModule } from 'expo';

declare class SmartCameraModule extends NativeModule<{}> {}

export default requireNativeModule<SmartCameraModule>('SmartCamera');

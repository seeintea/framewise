import { requireNativeView } from 'expo';
import * as React from 'react';

import { SmartCameraViewProps } from './SmartCamera.types';

const NativeView: React.ComponentType<SmartCameraViewProps> = requireNativeView('SmartCamera');

export default function SmartCameraView(props: SmartCameraViewProps) {
  return <NativeView {...props} />;
}

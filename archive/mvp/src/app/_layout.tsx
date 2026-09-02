import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';

import { CaptureSessionProvider } from '@/features/photo-review/model/capture-session';

export default function RootLayout() {
  return (
    <CaptureSessionProvider>
      <Stack screenOptions={{ headerShown: false }} />
      <StatusBar style="light" />
    </CaptureSessionProvider>
  );
}

import { Stack } from 'expo-router';
import { useEffect } from 'react';

import { initializeLogging } from '@/logging';

export default function RootLayout() {
  useEffect(() => {
    initializeLogging();
  }, []);

  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="(tabs)" />
      <Stack.Screen name="camera" />
      <Stack.Screen name="diagnostics" />
    </Stack>
  );
}

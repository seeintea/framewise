import { Redirect, router } from 'expo-router';

import { Diagnostics } from '@/features/diagnostics';
import { diagnosticsEnabled } from '@/logging';

export default function DiagnosticsRoute() {
  if (!diagnosticsEnabled) {
    return <Redirect href="/" />;
  }

  return <Diagnostics onBack={() => router.back()} />;
}

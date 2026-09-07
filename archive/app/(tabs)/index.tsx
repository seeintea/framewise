import { router } from 'expo-router';

import { useCameraAccess } from '@/features/camera/hooks/use-camera-access';
import { Templates } from '@/features/templates';
import { diagnosticsEnabled, logInfo } from '@/logging';

const FEATURED_PRESET_ID = 'classic-rule-of-thirds';

export default function TemplatesRoute() {
  const requestCameraAccess = useCameraAccess();

  async function openCamera(presetId: string) {
    logInfo('templates', 'camera_requested', { presetId });

    if (!(await requestCameraAccess())) {
      return;
    }

    logInfo('templates', 'camera_navigation_started', { presetId });
    router.push({ pathname: '/camera', params: { presetId } });
  }

  return (
    <Templates
      onOpenDiagnostics={
        diagnosticsEnabled ? () => router.push('../diagnostics') : undefined
      }
      onOpenFeatured={() => void openCamera(FEATURED_PRESET_ID)}
      onSelectTemplate={(presetId) => void openCamera(presetId)}
    />
  );
}

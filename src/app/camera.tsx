import { router, useLocalSearchParams } from 'expo-router';

import { Camera } from '@/features/camera';

export default function CameraRoute() {
  const { presetId } = useLocalSearchParams<{ presetId?: string | string[] }>();

  return (
    <Camera
      onBack={() => router.back()}
      presetId={typeof presetId === 'string' ? presetId : undefined}
    />
  );
}

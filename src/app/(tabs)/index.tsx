import { router } from 'expo-router';

import { Templates } from '@/features/templates';

export default function TemplatesRoute() {
  return (
    <Templates
      onOpenFeatured={() => router.push('/camera')}
      onSelectTemplate={(presetId) =>
        router.push({ pathname: '/camera', params: { presetId } })
      }
    />
  );
}

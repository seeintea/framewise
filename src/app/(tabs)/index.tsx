import { router } from 'expo-router';

import { Templates } from '@/features/templates';

const FEATURED_PRESET_ID = 'classic-rule-of-thirds';

export default function TemplatesRoute() {
  return (
    <Templates
      onOpenFeatured={() =>
        router.push({
          pathname: '/camera',
          params: { presetId: FEATURED_PRESET_ID },
        })
      }
      onSelectTemplate={(presetId) =>
        router.push({ pathname: '/camera', params: { presetId } })
      }
    />
  );
}

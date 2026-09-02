import { router } from 'expo-router';

import { Templates } from '@/features/templates';

export default function TemplatesRoute() {
  return <Templates onSelectTemplate={() => router.push('/camera')} />;
}

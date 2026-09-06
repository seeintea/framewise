import { Tabs } from 'expo-router';

import { FloatingTabBar } from '@/navigation/FloatingTabBar.android';

export default function AndroidTabLayout() {
  return (
    <Tabs
      screenOptions={{ headerShown: false }}
      tabBar={(props) => <FloatingTabBar {...props} />}
    >
      <Tabs.Screen name="index" />
      <Tabs.Screen name="mine" />
    </Tabs>
  );
}

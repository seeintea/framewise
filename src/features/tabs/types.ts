import { Tabs as ExpoTabs } from 'expo-router';
import { ComponentProps } from 'react';

export type TabBarProps = Parameters<
  Exclude<ComponentProps<typeof ExpoTabs>['tabBar'], undefined>
>[0];

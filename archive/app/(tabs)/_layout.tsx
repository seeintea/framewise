import { NativeTabs } from 'expo-router/unstable-native-tabs';

const ACTIVE_COLOR = '#111111';
const INACTIVE_COLOR = '#8E8E93';

export default function TabLayout() {
  return (
    <NativeTabs
      backBehavior="initialRoute"
      disableTransparentOnScrollEdge
      iconColor={{ default: INACTIVE_COLOR, selected: ACTIVE_COLOR }}
      labelStyle={{ color: INACTIVE_COLOR }}
      tintColor={ACTIVE_COLOR}
    >
      <NativeTabs.Trigger name="index">
        <NativeTabs.Trigger.Icon
          md="grid_view"
          sf={{
            default: 'rectangle.grid.2x2',
            selected: 'rectangle.grid.2x2.fill',
          }}
        />
        <NativeTabs.Trigger.Label selectedStyle={{ color: ACTIVE_COLOR }}>
          模版
        </NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="mine">
        <NativeTabs.Trigger.Icon
          md={{ default: 'person_outline', selected: 'person' }}
          sf={{
            default: 'person.crop.circle',
            selected: 'person.crop.circle.fill',
          }}
        />
        <NativeTabs.Trigger.Label selectedStyle={{ color: ACTIVE_COLOR }}>
          我的
        </NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}

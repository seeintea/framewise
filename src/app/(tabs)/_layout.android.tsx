import { Tabs } from 'expo-router';
import {
  type LucideIcon,
  LayoutTemplate,
  UserRound,
} from 'lucide-react-native';
import { type ComponentProps, useEffect, useState } from 'react';
import {
  type LayoutChangeEvent,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

const ACTIVE_COLOR = '#111111';
const INACTIVE_COLOR = '#8E8E93';

const tabs = [
  { key: 'index', label: '模版', icon: LayoutTemplate },
  { key: 'mine', label: '我的', icon: UserRound },
] as const;

type TabBarProps = Parameters<
  Exclude<ComponentProps<typeof Tabs>['tabBar'], undefined>
>[0];

type TabMeasurement = {
  x: number;
  width: number;
  height: number;
};

export default function AndroidTabLayout() {
  return (
    <Tabs
      screenOptions={{ headerShown: false }}
      tabBar={(props) => <FloatingTabBar {...props} />}
    >
      {tabs.map((tab) => (
        <Tabs.Screen key={tab.key} name={tab.key} />
      ))}
    </Tabs>
  );
}

function FloatingTabBar({ state, navigation }: TabBarProps) {
  const { bottom } = useSafeAreaInsets();
  const [measurements, setMeasurements] = useState<TabMeasurement[]>([]);
  const activeIndex = useSharedValue(state.index);
  const shouldAnimate = useSharedValue(false);

  useEffect(() => {
    activeIndex.value = state.index;
  }, [activeIndex, state.index]);

  useEffect(() => {
    if (measurements.filter(Boolean).length === tabs.length) {
      shouldAnimate.value = true;
    }
  }, [measurements, shouldAnimate]);

  function handleTabLayout(index: number, event: LayoutChangeEvent) {
    const { x, width, height } = event.nativeEvent.layout;

    setMeasurements((currentMeasurements) => {
      const currentMeasurement = currentMeasurements[index];

      if (
        currentMeasurement?.x === x &&
        currentMeasurement.width === width &&
        currentMeasurement.height === height
      ) {
        return currentMeasurements;
      }

      const nextMeasurements = [...currentMeasurements];
      nextMeasurements[index] = { x, width, height };
      return nextMeasurements;
    });
  }

  function handleTabPress(index: number, key: (typeof tabs)[number]['key']) {
    const route = state.routes[index];
    const event = navigation.emit({
      type: 'tabPress',
      target: route.key,
      canPreventDefault: true,
    });

    if (state.index !== index && !event.defaultPrevented) {
      navigation.navigate(key);
    }
  }

  const indicatorStyle = useAnimatedStyle(() => {
    const measurement = measurements[activeIndex.value];

    if (!measurement) {
      return { width: 0, height: 0, transform: [{ translateX: 0 }] };
    }

    const translateX = measurement.x - 4;
    const width = measurement.width + 8;
    const height = measurement.height - 6;

    if (!shouldAnimate.value) {
      return { width, height, transform: [{ translateX }] };
    }

    const spring = { damping: 55, stiffness: 500 };

    return {
      width: withSpring(width, spring),
      height: withSpring(height, spring),
      transform: [{ translateX: withSpring(translateX, spring) }],
    };
  });

  return (
    <View style={[styles.positioner, { bottom: Math.max(bottom, 12) }]}>
      <View style={styles.tabBar}>
        <Animated.View style={[styles.indicator, indicatorStyle]} />
        {tabs.map((tab, index) => {
          const isActive = state.index === index;

          return (
            <View
              key={tab.key}
              onLayout={(event) => handleTabLayout(index, event)}
            >
              <TabButton
                icon={tab.icon}
                isActive={isActive}
                label={tab.label}
                onPress={() => handleTabPress(index, tab.key)}
              />
            </View>
          );
        })}
      </View>
    </View>
  );
}

type TabButtonProps = {
  label: string;
  icon: LucideIcon;
  isActive: boolean;
  onPress: () => void;
};

function TabButton({ label, icon: Icon, isActive, onPress }: TabButtonProps) {
  const color = isActive ? ACTIVE_COLOR : INACTIVE_COLOR;

  return (
    <Pressable
      accessibilityRole="tab"
      accessibilityState={{ selected: isActive }}
      onPress={onPress}
      style={({ pressed }) => [styles.button, pressed && styles.buttonPressed]}
    >
      <Icon color={color} size={20} strokeWidth={2.5} />
      <Text style={[styles.label, { color }, isActive && styles.activeLabel]}>
        {label}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  positioner: {
    position: 'absolute',
    right: 0,
    left: 0,
    alignItems: 'center',
  },
  tabBar: {
    flexDirection: 'row',
    paddingHorizontal: 8,
    overflow: 'hidden',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(0, 0, 0, 0.12)',
    borderRadius: 32,
    backgroundColor: 'rgba(248, 248, 250, 0.96)',
    elevation: 10,
  },
  indicator: {
    position: 'absolute',
    top: 3,
    left: 0,
    borderRadius: 999,
    backgroundColor: '#E5E5EA',
  },
  button: {
    zIndex: 1,
    alignItems: 'center',
    gap: 1.5,
    paddingHorizontal: 36,
    paddingVertical: 12,
  },
  buttonPressed: {
    opacity: 0.75,
  },
  label: {
    fontSize: 10,
    lineHeight: 12,
    fontWeight: '500',
  },
  activeLabel: {
    fontWeight: '600',
  },
});

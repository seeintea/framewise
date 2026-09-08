import { LayoutTemplate, UserRound } from 'lucide-react-native';
import { useEffect, useState } from 'react';
import { StyleSheet, View, type LayoutChangeEvent } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';
import { TabButton } from './TabButton';
import { TabView } from './TabView';
import type { TabBarProps } from './types';

const tabs = [
  { key: 'index', label: '模版', icon: LayoutTemplate },
  { key: 'mine', label: '我的', icon: UserRound },
] as const;

interface TabsProps {
  state: TabBarProps['state'];
  navigation: TabBarProps['navigation'];
}

type TabMeasurement = {
  x: number;
  width: number;
  height: number;
};

export function Tabs({ state, navigation }: TabsProps) {
  const [measurements, setMeasurements] = useState<TabMeasurement[]>([]);
  const activeIndex = useSharedValue(state.index);
  const shouldAnimate = useSharedValue(false);

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

  const blockPosition = useAnimatedStyle(() => {
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

  useEffect(() => {
    activeIndex.value = state.index;
  }, [activeIndex, state.index]);

  useEffect(() => {
    if (measurements.filter(Boolean).length === tabs.length) {
      shouldAnimate.value = true;
    }
  }, [measurements, shouldAnimate]);

  return (
    <TabView style={styles.tabs}>
      <Animated.View style={[styles.block, blockPosition]} />
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
    </TabView>
  );
}

const styles = StyleSheet.create({
  tabs: {
    flexDirection: 'row',
    paddingHorizontal: 8,
    overflow: 'hidden',
    elevation: 10,
  },
  block: {
    position: 'absolute',
    top: 3,
    left: 0,
    borderRadius: 999,
    backgroundColor: '#e5e5ea',
  },
});

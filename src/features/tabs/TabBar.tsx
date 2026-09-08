import { GlassContainer } from 'expo-glass-effect';
import { PropsWithChildren } from 'react';
import { StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { supportsLiquidGlass } from './liquid-glass';
import { TabSearch } from './TabSearch';
import { Tabs } from './Tabs';
import type { TabBarProps } from './types';

function TabBarSurface({ children }: PropsWithChildren) {
  if (supportsLiquidGlass) {
    return (
      <GlassContainer spacing={8} style={styles.tabBar}>
        {children}
      </GlassContainer>
    );
  }

  return <View style={styles.tabBar}>{children}</View>;
}

export function TabBar(props: TabBarProps) {
  const { bottom } = useSafeAreaInsets();

  return (
    <View style={[styles.position, { bottom: Math.max(bottom + 8, 12) }]}>
      <TabBarSurface>
        <Tabs state={props.state} navigation={props.navigation} />
        <TabSearch />
      </TabBarSurface>
    </View>
  );
}

const styles = StyleSheet.create({
  position: {
    position: 'absolute',
    right: 0,
    left: 0,
    paddingHorizontal: 16,
  },
  tabBar: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
});

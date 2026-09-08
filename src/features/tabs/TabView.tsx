import { GlassView } from 'expo-glass-effect';
import { PropsWithChildren } from 'react';
import { type StyleProp, StyleSheet, View, type ViewStyle } from 'react-native';
import { supportsLiquidGlass } from './liquid-glass';

export function TabView(
  props: PropsWithChildren<{
    style: StyleProp<ViewStyle>;
  }>,
) {
  if (supportsLiquidGlass) {
    return (
      <GlassView glassEffectStyle="regular" style={[styles.glass, props.style]}>
        {props.children}
      </GlassView>
    );
  }

  return <View style={[styles.fallback, props.style]}>{props.children}</View>;
}

const styles = StyleSheet.create({
  glass: {
    borderRadius: 36,
  },
  fallback: {
    backgroundColor: '#f8f8faf5',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#0000001f',
    borderRadius: 36,
    elevation: 10,
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 8,
  },
});

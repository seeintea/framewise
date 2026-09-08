import {
  isGlassEffectAPIAvailable,
  isLiquidGlassAvailable,
} from 'expo-glass-effect';
import { Platform } from 'react-native';

export const supportsLiquidGlass =
  Platform.OS === 'ios' &&
  isGlassEffectAPIAvailable() &&
  isLiquidGlassAvailable();

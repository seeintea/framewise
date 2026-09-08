import type { LucideIcon } from 'lucide-react-native';
import { Pressable, StyleSheet, Text } from 'react-native';
import { ACTIVE_COLOR, INACTIVE_COLOR } from './constants';

type TabButtonProps = {
  label: string;
  icon: LucideIcon;
  isActive: boolean;
  onPress: () => void;
};

export function TabButton({
  label,
  icon: Icon,
  isActive,
  onPress,
}: TabButtonProps) {
  const color = isActive ? ACTIVE_COLOR : INACTIVE_COLOR;

  return (
    <Pressable
      accessibilityRole="tab"
      accessibilityState={{ selected: isActive }}
      onPress={onPress}
      style={({ pressed }) => [styles.btn, pressed && styles.pressedBtn]}
    >
      <Icon color={color} size={20} strokeWidth={2} />
      <Text style={[styles.label, { color }, isActive && styles.activeLabel]}>
        {label}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  btn: {
    zIndex: 1,
    alignItems: 'center',
    gap: 1.5,
    paddingHorizontal: 36,
    paddingVertical: 12,
  },
  pressedBtn: {
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

import { ArrowUpRight } from 'lucide-react-native';
import { Pressable, StyleSheet, Text, View } from 'react-native';

type CardProps = {
  description: string;
  onPress: () => void;
  previewColor: string;
  title: string;
};

export function Card({ description, onPress, previewColor, title }: CardProps) {
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.card, pressed && styles.pressed]}
    >
      <View style={styles.surface}>
        <View style={[styles.preview, { backgroundColor: previewColor }]} />

        <View style={styles.footer}>
          <View style={styles.copy}>
            <Text style={styles.title}>{title}</Text>
            <Text numberOfLines={2} style={styles.description}>
              {description}
            </Text>
          </View>
          <ArrowUpRight color="#77777D" size={17} strokeWidth={2.2} />
        </View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    width: '100%',
    borderRadius: 22,
    backgroundColor: '#FFFFFF',
  },
  pressed: {
    opacity: 0.82,
    transform: [{ scale: 0.985 }],
  },
  surface: {
    overflow: 'hidden',
    borderRadius: 22,
    backgroundColor: '#FFFFFF',
  },
  preview: {
    height: 142,
  },
  footer: {
    zIndex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    padding: 14,
    backgroundColor: '#FFFFFF',
    boxShadow:
      '0 1px 3px rgba(0, 0, 0, 0.1), 0 1px 2px -1px rgba(0, 0, 0, 0.1)',
  },
  copy: {
    flex: 1,
    gap: 2,
  },
  title: {
    color: '#191919',
    fontSize: 14,
    lineHeight: 19,
    fontWeight: '700',
  },
  description: {
    color: '#858581',
    fontSize: 11,
    lineHeight: 16,
  },
});

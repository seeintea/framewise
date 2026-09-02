import { ArrowUpRight } from 'lucide-react-native';
import { Pressable, StyleSheet, Text, View } from 'react-native';

type CardProps = {
  description: string;
  onPress: () => void;
  orientation: 'portrait' | 'landscape';
  title: string;
};

export function Card({ description, onPress, orientation, title }: CardProps) {
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.card, pressed && styles.pressed]}
    >
      <View style={styles.preview}>
        <View
          style={[
            styles.frame,
            orientation === 'portrait'
              ? styles.portraitFrame
              : styles.landscapeFrame,
          ]}
        >
          {orientation === 'portrait' ? (
            <>
              <View style={styles.subjectHead} />
              <View style={styles.subjectBody} />
              <View style={styles.centerGuide} />
            </>
          ) : (
            <>
              <View style={styles.horizonGuide} />
              <View style={styles.sun} />
            </>
          )}
        </View>
      </View>

      <View style={styles.footer}>
        <View style={styles.copy}>
          <Text style={styles.title}>{title}</Text>
          <Text style={styles.description}>{description}</Text>
        </View>
        <ArrowUpRight color="#77777D" size={17} strokeWidth={2.2} />
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    flex: 1,
    overflow: 'hidden',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#E1E1DC',
    borderRadius: 22,
    backgroundColor: '#FFFFFF',
  },
  pressed: {
    opacity: 0.82,
    transform: [{ scale: 0.985 }],
  },
  preview: {
    height: 142,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#EAEAE5',
  },
  frame: {
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: '#9B9C96',
    borderRadius: 7,
    backgroundColor: '#D8D9D3',
  },
  portraitFrame: {
    width: 70,
    height: 94,
  },
  landscapeFrame: {
    width: 106,
    height: 76,
  },
  subjectHead: {
    position: 'absolute',
    top: 22,
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#878983',
  },
  subjectBody: {
    position: 'absolute',
    bottom: -18,
    width: 54,
    height: 58,
    borderRadius: 28,
    backgroundColor: '#878983',
  },
  centerGuide: {
    position: 'absolute',
    top: 7,
    bottom: 7,
    width: StyleSheet.hairlineWidth,
    backgroundColor: '#F3D857',
  },
  horizonGuide: {
    position: 'absolute',
    right: 7,
    left: 7,
    height: 1,
    backgroundColor: '#F3D857',
  },
  sun: {
    position: 'absolute',
    top: 15,
    right: 21,
    width: 13,
    height: 13,
    borderRadius: 7,
    backgroundColor: '#92948E',
  },
  footer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    padding: 14,
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

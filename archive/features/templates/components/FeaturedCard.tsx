import { Camera } from 'lucide-react-native';
import { Pressable, StyleSheet, Text, View } from 'react-native';

type FeaturedCardProps = {
  onPress: () => void;
};

export function FeaturedCard({ onPress }: FeaturedCardProps) {
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.card, pressed && styles.pressed]}
    >
      <View style={styles.copy}>
        <View style={styles.badge}>
          <Text style={styles.badgeText}>推荐</Text>
        </View>
        <Text style={styles.title}>经典三分法</Text>
        <Text style={styles.description}>适合人像、街拍和日常记录</Text>
        <View style={styles.action}>
          <Camera color="#111111" size={17} strokeWidth={2.4} />
          <Text style={styles.actionText}>开始拍摄</Text>
        </View>
      </View>

      <View pointerEvents="none" style={styles.preview}>
        <View style={styles.previewFrame}>
          <View style={[styles.guideLine, styles.verticalGuideOne]} />
          <View style={[styles.guideLine, styles.verticalGuideTwo]} />
          <View style={[styles.guideLine, styles.horizontalGuideOne]} />
          <View style={[styles.guideLine, styles.horizontalGuideTwo]} />
          <View style={styles.focusPoint} />
        </View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    minHeight: 226,
    overflow: 'hidden',
    borderRadius: 28,
    backgroundColor: '#171817',
  },
  pressed: {
    opacity: 0.82,
    transform: [{ scale: 0.985 }],
  },
  copy: {
    zIndex: 1,
    width: '67%',
    alignItems: 'flex-start',
    padding: 22,
  },
  badge: {
    marginBottom: 30,
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 999,
    backgroundColor: 'rgba(255, 255, 255, 0.12)',
  },
  badgeText: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: '600',
  },
  title: {
    color: '#FFFFFF',
    fontSize: 23,
    lineHeight: 29,
    fontWeight: '700',
  },
  description: {
    marginTop: 5,
    color: '#A9AAA6',
    fontSize: 13,
    lineHeight: 19,
  },
  action: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 7,
    marginTop: 20,
    paddingHorizontal: 13,
    paddingVertical: 9,
    borderRadius: 999,
    backgroundColor: '#F3D857',
  },
  actionText: {
    color: '#111111',
    fontSize: 13,
    fontWeight: '700',
  },
  preview: {
    position: 'absolute',
    top: 26,
    right: -26,
    width: 156,
    height: 194,
    padding: 13,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
    borderRadius: 25,
    backgroundColor: '#292B29',
    transform: [{ rotate: '6deg' }],
  },
  previewFrame: {
    flex: 1,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.35)',
    borderRadius: 14,
    backgroundColor: '#353835',
  },
  guideLine: {
    position: 'absolute',
    backgroundColor: 'rgba(243, 216, 87, 0.65)',
  },
  verticalGuideOne: {
    top: 0,
    bottom: 0,
    left: '33.33%',
    width: StyleSheet.hairlineWidth,
  },
  verticalGuideTwo: {
    top: 0,
    bottom: 0,
    left: '66.66%',
    width: StyleSheet.hairlineWidth,
  },
  horizontalGuideOne: {
    top: '33.33%',
    right: 0,
    left: 0,
    height: StyleSheet.hairlineWidth,
  },
  horizontalGuideTwo: {
    top: '66.66%',
    right: 0,
    left: 0,
    height: StyleSheet.hairlineWidth,
  },
  focusPoint: {
    position: 'absolute',
    top: '29%',
    left: '27%',
    width: 13,
    height: 13,
    borderWidth: 2,
    borderColor: '#F3D857',
    borderRadius: 7,
  },
});

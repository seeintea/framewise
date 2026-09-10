import { Camera } from 'lucide-react-native';
import { StyleSheet, Text, View } from 'react-native';

export function Header() {
  return (
    <View style={styles.header}>
      <View style={{ flex: 1 }}>
        <View style={styles.subTitle}>
          <Text style={styles.subIcon}>✦</Text>
          <Text style={styles.subTitleContent}>随手定格眼前的美好</Text>
        </View>
        <Text style={styles.title}>今天想拍什么？</Text>
      </View>
      <View style={styles.fastButton}>
        <Camera color="#718099" size={17} strokeWidth={1} />
        <Text style={styles.label}>拍一张</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
  },
  subTitle: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    marginBottom: 5,
    fontSize: 12,
  },
  subIcon: {
    fontSize: 10,
    color: '#8798b5',
  },
  subTitleContent: {
    color: '#66738a',
    letterSpacing: 0.2,
    fontFamily: 'DingTalk_JinBU',
  },
  title: {
    color: '#212121',
    fontSize: 32,
    lineHeight: 38,
    fontWeight: '700',
    fontFamily: 'DingTalk_JinBU',
  },
  fastButton: {
    height: 44,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingHorizontal: 12,
    backgroundColor: '#ffffff',
    borderRadius: 24,
    shadowColor: '#536078',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.05,
    shadowRadius: 10,
    elevation: 1,
  },
  label: {
    color: '#4d524e',
    fontSize: 12,
    lineHeight: 16,
    fontWeight: '300',
  },
});

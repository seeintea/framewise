import { Check } from 'lucide-react-native';
import { StyleSheet, Text, View } from 'react-native';

export function Tip() {
  return (
    <View style={styles.card}>
      <View style={styles.icon}>
        <Check color="#FFFFFF" size={15} strokeWidth={3} />
      </View>
      <View style={styles.copy}>
        <Text style={styles.title}>拍摄时可随时调整</Text>
        <Text style={styles.description}>
          引导线只帮助构图，不会出现在最终照片中。
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginTop: 20,
    padding: 15,
    borderRadius: 18,
    backgroundColor: '#E8E8E3',
  },
  icon: {
    width: 28,
    height: 28,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 14,
    backgroundColor: '#1B1B1A',
  },
  copy: {
    flex: 1,
    gap: 2,
  },
  title: {
    color: '#252524',
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '600',
  },
  description: {
    color: '#777773',
    fontSize: 11,
    lineHeight: 16,
  },
});

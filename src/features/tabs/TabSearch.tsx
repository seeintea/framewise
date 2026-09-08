import { router } from 'expo-router';
import { Search } from 'lucide-react-native';
import { Pressable, StyleSheet, View } from 'react-native';
import { ACTIVE_COLOR, INACTIVE_COLOR } from './constants';
import { TabView } from './TabView';

export function TabSearch() {
  const handle = () => {
    router.push('/search');
  };

  return (
    <Pressable
      accessibilityLabel="搜索"
      accessibilityRole="button"
      onPress={handle}
    >
      {({ pressed }) => (
        <TabView style={styles.search}>
          <View style={[styles.placeholder, pressed && styles.pressed]}>
            <Search
              size={32}
              strokeWidth={1.5}
              color={pressed ? ACTIVE_COLOR : INACTIVE_COLOR}
            />
          </View>
        </TabView>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  search: {
    width: 56,
    height: 56,
    padding: 4,
  },
  placeholder: {
    width: '100%',
    height: '100%',
    alignItems: 'center',
    justifyContent: 'center',
  },
  pressed: {
    backgroundColor: '#e5e5ea',
    borderRadius: 32,
  },
});

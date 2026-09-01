import { StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import Canvas, {
  getViewportSize,
  type CompositionTemplateDocumentV1,
} from '@/canvas';

const templateDocument = {
  schemaVersion: 1,
  presets: [
    {
      id: 'horizon',
      title: '水平线',
      description: '用于验证构图引导线渲染',
      variants: [
        {
          id: 'horizon-3x4',
          aspectRatio: { width: 3, height: 4 },
          instruction: '将主体沿水平线放置',
          defaultFacing: 'back',
          elements: [
            {
              id: 'center-line',
              type: 'horizon',
              shape: {
                type: 'line',
                start: { x: 0.1, y: 0.5 },
                end: { x: 0.9, y: 0.5 },
              },
            },
          ],
        },
      ],
    },
  ],
} satisfies CompositionTemplateDocumentV1;

const variant = templateDocument.presets[0].variants[0];
const viewportSize = getViewportSize(variant.aspectRatio);

export default function HomeScreen() {
  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.content}>
        <View style={styles.viewport}>
          <Canvas variant={variant} viewportSize={viewportSize} />
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#111111',
  },
  content: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  viewport: {
    backgroundColor: '#333333',
  },
});

import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { listPresets } from '@/data/composition-templates';

import { Card } from './components/Card';
import { FeaturedCard } from './components/FeaturedCard';
import { Tip } from './components/Tip';

const PLACEHOLDER_COLORS = ['#D9DDD5', '#DDD7D1', '#D6D9DF'] as const;
const presets = listPresets();

type TemplatesProps = {
  onOpenFeatured: () => void;
  onSelectTemplate: (presetId: string) => void;
};

export function Templates({
  onOpenFeatured,
  onSelectTemplate,
}: TemplatesProps) {
  return (
    <SafeAreaView edges={['top']} style={styles.safeArea}>
      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.header}>
          <Text style={styles.eyebrow}>FRAMEWISE</Text>
          <Text style={styles.title}>选择一个构图模版</Text>
          <Text style={styles.subtitle}>让取景框替你守住画面的秩序。</Text>
        </View>

        <FeaturedCard onPress={onOpenFeatured} />

        <Tip />

        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>常用构图</Text>
          <Text style={styles.sectionHint}>快速开始</Text>
        </View>

        <View style={styles.templateGrid}>
          {presets.map((preset, index) => (
            <View key={preset.id} style={styles.templateCard}>
              <Card
                description={preset.description}
                onPress={() => onSelectTemplate(preset.id)}
                previewColor={
                  PLACEHOLDER_COLORS[index % PLACEHOLDER_COLORS.length]
                }
                title={preset.title}
              />
            </View>
          ))}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#F4F4F1',
  },
  content: {
    paddingTop: 24,
    paddingHorizontal: 20,
    paddingBottom: 120,
  },
  header: {
    gap: 5,
    marginBottom: 24,
  },
  eyebrow: {
    color: '#8B8B87',
    fontSize: 11,
    lineHeight: 14,
    fontWeight: '700',
    letterSpacing: 1.8,
  },
  title: {
    color: '#151515',
    fontSize: 30,
    lineHeight: 38,
    fontWeight: '700',
    letterSpacing: -0.7,
  },
  subtitle: {
    color: '#747470',
    fontSize: 15,
    lineHeight: 22,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'baseline',
    justifyContent: 'space-between',
    marginTop: 30,
    marginBottom: 13,
  },
  sectionTitle: {
    color: '#151515',
    fontSize: 19,
    lineHeight: 25,
    fontWeight: '700',
  },
  sectionHint: {
    color: '#888884',
    fontSize: 12,
  },
  templateGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  templateCard: {
    width: '48%',
  },
});

import {
  Building2,
  Camera,
  Check,
  Coffee,
  Image as ImageIcon,
  MountainSnow,
  Sparkles,
  UserRound,
  type LucideIcon,
} from 'lucide-react-native';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

type QuickEntryProps = {
  title: string;
  description: string;
  icon: LucideIcon;
  backgroundColor: string;
  borderColor: string;
  iconColor: string;
  focus: 'top' | 'center' | 'bottom' | 'right';
};

function QuickEntry({
  title,
  description,
  icon: Icon,
  backgroundColor,
  borderColor,
  iconColor,
  focus,
}: QuickEntryProps) {
  return (
    <View style={[styles.quickEntry, { backgroundColor, borderColor }]}>
      <View style={styles.compositionSketch}>
        <View
          style={[styles.guideLineVertical, { backgroundColor: iconColor }]}
        />
        <View
          style={[styles.guideLineHorizontal, { backgroundColor: iconColor }]}
        />
        <Icon
          color={iconColor}
          size={58}
          strokeWidth={1.15}
          style={styles.sketchIcon}
        />
        <View
          style={[
            styles.focusPoint,
            focus === 'top' && styles.focusPointTop,
            focus === 'center' && styles.focusPointCenter,
            focus === 'bottom' && styles.focusPointBottom,
            focus === 'right' && styles.focusPointRight,
            { backgroundColor: iconColor, borderColor: backgroundColor },
          ]}
        />
      </View>
      <View style={styles.quickCopy}>
        <Text style={styles.quickTitle}>{title}</Text>
        <Text style={styles.quickDescription}>{description}</Text>
      </View>
    </View>
  );
}

type RecommendationRowProps = {
  title: string;
  backgrounds: readonly [string, string, string];
};

function RecommendationRow({ title, backgrounds }: RecommendationRowProps) {
  return (
    <View style={styles.recommendationSection}>
      <View style={styles.sectionHeading}>
        <Text style={styles.recommendationTitle}>{title}</Text>
      </View>

      <ScrollView
        contentContainerStyle={styles.previewList}
        decelerationRate="fast"
        directionalLockEnabled
        horizontal
        showsHorizontalScrollIndicator={false}
        snapToAlignment="start"
        snapToInterval={176}
      >
        {backgrounds.map((backgroundColor, index) => (
          <View
            key={`${title}-${backgroundColor}`}
            style={styles.previewSurface}
          >
            <View style={styles.previewCard}>
              <View style={[styles.previewArtwork, { backgroundColor }]}>
                <View style={styles.previewSun} />
                <View
                  style={[
                    styles.previewShape,
                    index === 1 && styles.previewShapeCentered,
                    index === 2 && styles.previewShapeRight,
                  ]}
                />
                <View style={styles.previewFrame} />
                <View style={styles.previewLabel}>
                  <ImageIcon color="#536251" size={14} strokeWidth={1.8} />
                  <Text style={styles.previewLabelText}>示例图</Text>
                </View>
              </View>
            </View>
          </View>
        ))}
      </ScrollView>
    </View>
  );
}

export function GuidesScreen() {
  return (
    <SafeAreaView edges={['top']} style={styles.safeArea}>
      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.header}>
          <View style={styles.headerCopy}>
            <View style={styles.headerHintRow}>
              <Sparkles color="#D48545" size={12} strokeWidth={1.8} />
              <Text style={styles.headerHint}>随手定格眼前的美好</Text>
            </View>
            <Text style={styles.title}>今天想拍什么？</Text>
          </View>
          <View style={styles.cameraBadge}>
            <Camera color="#60725E" size={17} strokeWidth={1.8} />
            <Text style={styles.cameraLabel}>开相机</Text>
          </View>
        </View>

        <View style={styles.quickGrid}>
          <QuickEntry
            backgroundColor="#FEF2EB"
            borderColor="#F5DED0"
            description="单人 · 合照"
            focus="top"
            icon={UserRound}
            iconColor="#D87956"
            title="拍人物"
          />
          <QuickEntry
            backgroundColor="#EDF4EC"
            borderColor="#D8E5D5"
            description="山川 · 湖海 · 日落"
            focus="right"
            icon={MountainSnow}
            iconColor="#5C7E59"
            title="拍风景"
          />
          <QuickEntry
            backgroundColor="#EAF2F8"
            borderColor="#D6E3EB"
            description="街道 · 楼宇 · 地标"
            focus="center"
            icon={Building2}
            iconColor="#4C7895"
            title="拍建筑"
          />
          <QuickEntry
            backgroundColor="#FFF5E2"
            borderColor="#FAE8C9"
            description="美食 · 花草 · 小物"
            focus="bottom"
            icon={Coffee}
            iconColor="#C28735"
            title="拍静物"
          />
        </View>

        <View style={styles.tipCard}>
          <View style={styles.tipIcon}>
            <Check color="#FFFFFF" size={15} strokeWidth={3} />
          </View>
          <View style={styles.tipCopy}>
            <Text style={styles.tipTitle}>拍摄时可随时调整</Text>
            <Text style={styles.tipDescription}>
              引导线只帮助构图，不会出现在最终照片中。
            </Text>
          </View>
        </View>

        <View style={styles.inspirationHeading}>
          <Text style={styles.inspirationTitle}>找点构图灵感</Text>
          <Text style={styles.inspirationSubtitle}>
            左右滑动，看看不同的画面
          </Text>
        </View>

        <RecommendationRow
          backgrounds={['#E9F0E5', '#F6EBDD', '#E4EEF4']}
          title="在风景里留个影"
        />
        <RecommendationRow
          backgrounds={['#E5EFF5', '#F1E8DC', '#E7EEE6']}
          title="走到街角，拍一张"
        />
        <RecommendationRow
          backgrounds={['#F6ECD8', '#F2E6DF', '#E6EFE9']}
          title="记录喜欢的事物"
        />
        <RecommendationRow
          backgrounds={['#E3EDF5', '#EBE8F2', '#F3E8DC']}
          title="遇到好看的天空"
        />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#FAF9F5',
  },
  content: {
    paddingTop: 18,
    paddingBottom: 132,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    marginBottom: 22,
  },
  headerCopy: {
    flex: 1,
    paddingRight: 16,
  },
  headerHintRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    marginBottom: 5,
  },
  headerHint: {
    color: '#536251',
    fontSize: 12,
    lineHeight: 17,
    fontWeight: '500',
    letterSpacing: 0.2,
  },
  title: {
    color: '#171A18',
    fontSize: 31,
    lineHeight: 38,
    fontWeight: '700',
    letterSpacing: -0.8,
  },
  cameraBadge: {
    height: 44,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingHorizontal: 14,
    backgroundColor: '#FFFFFF',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#E1E3DD',
    borderRadius: 22,
    shadowColor: '#465046',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.07,
    shadowRadius: 10,
    elevation: 1,
  },
  cameraLabel: {
    color: '#4D524E',
    fontSize: 12,
    lineHeight: 17,
    fontWeight: '500',
    letterSpacing: -0.1,
  },
  quickGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
    paddingHorizontal: 20,
  },
  quickEntry: {
    minWidth: 0,
    minHeight: 152,
    flexGrow: 1,
    flexBasis: '45%',
    justifyContent: 'space-between',
    padding: 16,
    borderWidth: 1,
    borderRadius: 20,
    overflow: 'hidden',
    shadowColor: '#27342F',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.055,
    shadowRadius: 12,
    elevation: 1,
  },
  compositionSketch: {
    position: 'absolute',
    top: 10,
    right: 9,
    width: 88,
    height: 76,
  },
  guideLineVertical: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    left: 34,
    width: StyleSheet.hairlineWidth,
    opacity: 0.3,
  },
  guideLineHorizontal: {
    position: 'absolute',
    top: 30,
    right: 0,
    left: 0,
    height: StyleSheet.hairlineWidth,
    opacity: 0.3,
  },
  sketchIcon: {
    position: 'absolute',
    top: 4,
    right: 3,
    opacity: 0.46,
  },
  focusPoint: {
    position: 'absolute',
    width: 8,
    height: 8,
    borderWidth: 2,
    borderRadius: 4,
  },
  focusPointTop: {
    top: 26,
    left: 30,
  },
  focusPointCenter: {
    top: 26,
    left: 50,
  },
  focusPointBottom: {
    top: 51,
    left: 30,
  },
  focusPointRight: {
    top: 26,
    right: 11,
  },
  quickCopy: {
    position: 'absolute',
    right: 16,
    bottom: 15,
    left: 16,
  },
  quickTitle: {
    marginBottom: 4,
    color: '#202622',
    fontSize: 18,
    lineHeight: 23,
    fontWeight: '600',
    letterSpacing: -0.25,
  },
  quickDescription: {
    color: '#626B66',
    fontSize: 12,
    lineHeight: 18,
    letterSpacing: 0.05,
  },
  tipCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginTop: 20,
    marginHorizontal: 20,
    padding: 15,
    backgroundColor: '#F4F1E8',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#EBE5D7',
    borderRadius: 16,
    shadowColor: '#315B4F',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.045,
    shadowRadius: 9,
    elevation: 1,
  },
  tipIcon: {
    width: 28,
    height: 28,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#71806E',
    borderRadius: 14,
  },
  tipCopy: {
    flex: 1,
    gap: 2,
  },
  tipTitle: {
    color: '#333833',
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '600',
    letterSpacing: 0.05,
  },
  tipDescription: {
    color: '#747970',
    fontSize: 11,
    lineHeight: 16,
    letterSpacing: 0.05,
  },
  inspirationHeading: {
    paddingHorizontal: 20,
    marginTop: 36,
    marginBottom: 20,
  },
  inspirationTitle: {
    color: '#171A18',
    fontSize: 24,
    lineHeight: 30,
    fontWeight: '700',
    letterSpacing: -0.45,
  },
  inspirationSubtitle: {
    marginTop: 5,
    color: '#777C79',
    fontSize: 13,
    lineHeight: 19,
  },
  recommendationSection: {
    marginBottom: 28,
  },
  sectionHeading: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 20,
    marginBottom: 12,
  },
  recommendationTitle: {
    color: '#272B29',
    fontSize: 18,
    lineHeight: 24,
    fontWeight: '600',
    letterSpacing: -0.2,
  },
  previewList: {
    gap: 12,
    paddingHorizontal: 20,
  },
  previewSurface: {
    width: 164,
    height: 218,
    borderRadius: 18,
    shadowColor: '#26352F',
    shadowOffset: { width: 0, height: 5 },
    shadowOpacity: 0.07,
    shadowRadius: 14,
    elevation: 2,
  },
  previewCard: {
    width: '100%',
    height: '100%',
    padding: 9,
    backgroundColor: '#FDFCF9',
    borderWidth: 1,
    borderColor: '#EBE8DC',
    borderRadius: 18,
  },
  previewArtwork: {
    flex: 1,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#FFFFFFCC',
    borderRadius: 12,
    overflow: 'hidden',
  },
  previewSun: {
    position: 'absolute',
    top: 25,
    right: 23,
    width: 30,
    height: 30,
    backgroundColor: '#FFFFFF82',
    borderRadius: 15,
  },
  previewShape: {
    position: 'absolute',
    bottom: -22,
    left: -28,
    width: 160,
    height: 135,
    backgroundColor: '#456D6052',
    borderRadius: 80,
    transform: [{ rotate: '12deg' }],
  },
  previewShapeCentered: {
    left: 20,
    bottom: -34,
    transform: [{ rotate: '-8deg' }],
  },
  previewShapeRight: {
    left: 64,
    bottom: -16,
    transform: [{ rotate: '18deg' }],
  },
  previewFrame: {
    position: 'absolute',
    top: 15,
    right: 15,
    bottom: 15,
    left: 15,
    borderWidth: 1,
    borderColor: '#FFFFFF80',
    borderRadius: 8,
  },
  previewLabel: {
    position: 'absolute',
    bottom: 14,
    left: 14,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    paddingHorizontal: 9,
    paddingVertical: 6,
    backgroundColor: '#FFFFFFE8',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#FFFFFF',
    borderRadius: 9,
  },
  previewLabelText: {
    color: '#5B625F',
    fontSize: 11,
    lineHeight: 15,
    fontWeight: '600',
    letterSpacing: 0.1,
  },
});

import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Pressable,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import {
  clearLogSessions,
  listLogSessions,
  readLogSession,
  type LogEntry,
  type LogSession,
} from '@/logging';

type DiagnosticsProps = {
  onBack: () => void;
};

export function Diagnostics({ onBack }: DiagnosticsProps) {
  const [sessions, setSessions] = useState<LogSession[]>([]);
  const [selectedSessionId, setSelectedSessionId] = useState<string>();
  const [entries, setEntries] = useState<LogEntry[]>([]);
  const [rawLog, setRawLog] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  const loadSession = useCallback(async (sessionId: string) => {
    setSelectedSessionId(sessionId);
    const session = await readLogSession(sessionId);
    setEntries(session.entries);
    setRawLog(session.text);
  }, []);

  const refresh = useCallback(async () => {
    setIsLoading(true);
    try {
      const nextSessions = await listLogSessions();
      setSessions(nextSessions);
      const nextSessionId = nextSessions.some(
        (session) => session.id === selectedSessionId,
      )
        ? selectedSessionId
        : nextSessions[0]?.id;

      if (nextSessionId) {
        await loadSession(nextSessionId);
      } else {
        setSelectedSessionId(undefined);
        setEntries([]);
        setRawLog('');
      }
    } catch (error) {
      Alert.alert(
        '读取日志失败',
        error instanceof Error ? error.message : '请稍后重试',
      );
    } finally {
      setIsLoading(false);
    }
  }, [loadSession, selectedSessionId]);

  useEffect(() => {
    const timeoutId = setTimeout(() => void refresh(), 0);
    return () => clearTimeout(timeoutId);
  }, [refresh]);

  function confirmClear() {
    Alert.alert('清空诊断日志？', '最近的启动记录将被永久删除。', [
      { text: '取消', style: 'cancel' },
      {
        text: '清空',
        style: 'destructive',
        onPress: () => {
          clearLogSessions();
          void refresh();
        },
      },
    ]);
  }

  async function shareSelectedSession() {
    if (!selectedSessionId || !rawLog) {
      return;
    }

    try {
      await Share.share({
        title: `Framewise diagnostics ${selectedSessionId}`,
        message: rawLog,
      });
    } catch (error) {
      Alert.alert(
        '分享日志失败',
        error instanceof Error ? error.message : '请稍后重试',
      );
    }
  }

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.header}>
        <Pressable onPress={onBack} style={styles.headerButton}>
          <Text style={styles.headerButtonText}>返回</Text>
        </Pressable>
        <Text style={styles.title}>诊断日志</Text>
        <Pressable onPress={() => void refresh()} style={styles.headerButton}>
          <Text style={styles.headerButtonText}>刷新</Text>
        </Pressable>
      </View>

      {isLoading ? (
        <View style={styles.loading}>
          <ActivityIndicator color="#111111" />
        </View>
      ) : (
        <ScrollView contentContainerStyle={styles.content}>
          <Text style={styles.sectionTitle}>最近启动</Text>
          <ScrollView
            horizontal
            contentContainerStyle={styles.sessionList}
            showsHorizontalScrollIndicator={false}
          >
            {sessions.map((session, index) => {
              const selected = session.id === selectedSessionId;
              return (
                <Pressable
                  key={session.id}
                  onPress={() => void loadSession(session.id)}
                  style={[styles.sessionCard, selected && styles.selectedCard]}
                >
                  <Text
                    style={[
                      styles.sessionTitle,
                      selected && styles.selectedText,
                    ]}
                  >
                    {index === 0 ? '当前' : `上次 ${index}`}
                  </Text>
                  <Text
                    style={[
                      styles.sessionMeta,
                      selected && styles.selectedMeta,
                    ]}
                  >
                    {formatSessionTime(session.startedAt)} ·{' '}
                    {session.entryCount} 条
                  </Text>
                  {session.errorCount > 0 && (
                    <Text style={styles.errorCount}>
                      {session.errorCount} 个错误
                    </Text>
                  )}
                </Pressable>
              );
            })}
          </ScrollView>

          <View style={styles.actions}>
            <Pressable
              disabled={!rawLog}
              onPress={() => void shareSelectedSession()}
              style={[styles.primaryAction, !rawLog && styles.disabledAction]}
            >
              <Text style={styles.primaryActionText}>分享当前日志</Text>
            </Pressable>
            <Pressable onPress={confirmClear} style={styles.secondaryAction}>
              <Text style={styles.secondaryActionText}>清空全部</Text>
            </Pressable>
          </View>

          <Text style={styles.sectionTitle}>事件</Text>
          {entries.length ? (
            <View style={styles.logSurface}>
              {entries.map((entry, index) => (
                <View
                  key={`${entry.timestamp}-${index}`}
                  style={styles.logEntry}
                >
                  <Text selectable style={styles.logHeader}>
                    {formatEntryTime(entry.timestamp)}{' '}
                    {entry.level.toUpperCase()} [{entry.scope}]
                  </Text>
                  <Text selectable style={styles.logEvent}>
                    {entry.event}
                  </Text>
                  {entry.data && (
                    <Text selectable style={styles.logData}>
                      {JSON.stringify(entry.data)}
                    </Text>
                  )}
                </View>
              ))}
            </View>
          ) : (
            <Text style={styles.empty}>暂无日志</Text>
          )}
        </ScrollView>
      )}
    </SafeAreaView>
  );
}

function formatSessionTime(timestamp?: string) {
  return timestamp
    ? new Date(timestamp).toLocaleString('zh-CN', {
        hour: '2-digit',
        minute: '2-digit',
        month: '2-digit',
        day: '2-digit',
      })
    : '时间未知';
}

function formatEntryTime(timestamp: string) {
  const date = new Date(timestamp);
  return `${date.toLocaleTimeString('zh-CN', { hour12: false })}.${date.getMilliseconds().toString().padStart(3, '0')}`;
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#F4F4F1',
  },
  header: {
    height: 56,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#D8D8D3',
  },
  headerButton: {
    minWidth: 52,
    paddingVertical: 8,
  },
  headerButtonText: {
    color: '#555550',
    fontSize: 14,
  },
  title: {
    color: '#151515',
    fontSize: 17,
    fontWeight: '700',
  },
  loading: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  content: {
    padding: 18,
    paddingBottom: 48,
  },
  sectionTitle: {
    marginBottom: 10,
    color: '#6F6F6A',
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 1,
  },
  sessionList: {
    gap: 10,
    paddingBottom: 18,
  },
  sessionCard: {
    minWidth: 150,
    padding: 13,
    borderRadius: 14,
    backgroundColor: '#FFFFFF',
  },
  selectedCard: {
    backgroundColor: '#1E1F1E',
  },
  sessionTitle: {
    color: '#202020',
    fontSize: 14,
    fontWeight: '700',
  },
  selectedText: {
    color: '#FFFFFF',
  },
  sessionMeta: {
    marginTop: 4,
    color: '#7C7C77',
    fontSize: 11,
  },
  selectedMeta: {
    color: '#B8B9B5',
  },
  errorCount: {
    marginTop: 5,
    color: '#E45C54',
    fontSize: 11,
    fontWeight: '600',
  },
  actions: {
    flexDirection: 'row',
    gap: 10,
    marginBottom: 26,
  },
  primaryAction: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 12,
    borderRadius: 12,
    backgroundColor: '#F3D857',
  },
  disabledAction: {
    opacity: 0.4,
  },
  primaryActionText: {
    color: '#171817',
    fontSize: 13,
    fontWeight: '700',
  },
  secondaryAction: {
    alignItems: 'center',
    paddingHorizontal: 18,
    paddingVertical: 12,
    borderRadius: 12,
    backgroundColor: '#E4E4DF',
  },
  secondaryActionText: {
    color: '#565651',
    fontSize: 13,
    fontWeight: '600',
  },
  logSurface: {
    overflow: 'hidden',
    borderRadius: 14,
    backgroundColor: '#181918',
  },
  logEntry: {
    gap: 3,
    padding: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#3B3C39',
  },
  logHeader: {
    color: '#999B95',
    fontFamily: 'monospace',
    fontSize: 10,
    lineHeight: 15,
  },
  logEvent: {
    color: '#F3D857',
    fontFamily: 'monospace',
    fontSize: 12,
    lineHeight: 17,
  },
  logData: {
    color: '#D6D7D1',
    fontFamily: 'monospace',
    fontSize: 10,
    lineHeight: 15,
  },
  empty: {
    color: '#898984',
    fontSize: 14,
  },
});

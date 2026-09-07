import Constants from 'expo-constants';
import type { File } from 'expo-file-system';

import { appendLogEntry, createSessionFile } from './log-storage';
import type { LogData, LogEntry, LogLevel, LogValue } from './log-types';

export type NativeLogEvent = {
  timestampMs: number;
  level: LogLevel;
  scope: string;
  event: string;
  data?: Record<string, unknown>;
};

export const diagnosticsEnabled =
  Constants.expoConfig?.extra?.enableDiagnostics === true;

const startedAt = new Date();
const sessionId = `${startedAt.getTime().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
let sessionFile: File | undefined;
let initialized = false;

export function initializeLogging() {
  if (!diagnosticsEnabled || initialized) {
    return;
  }

  initialized = true;
  try {
    sessionFile = createSessionFile(sessionId, startedAt);
  } catch (error) {
    console.error('初始化诊断日志失败', error);
    return;
  }
  writeLog('info', 'app', 'session_started', {
    platform: Constants.platform?.android ? 'android' : 'ios',
    appVersion: Constants.expoConfig?.version ?? 'unknown',
  });
}

export function logDebug(scope: string, event: string, data?: LogData) {
  writeLog('debug', scope, event, data);
}

export function logInfo(scope: string, event: string, data?: LogData) {
  writeLog('info', scope, event, data);
}

export function logWarn(scope: string, event: string, data?: LogData) {
  writeLog('warn', scope, event, data);
}

export function logError(
  scope: string,
  event: string,
  error: unknown,
  data?: LogData,
) {
  writeLog('error', scope, event, {
    ...data,
    error: normalizeError(error),
  });
}

export function logNativeEvent(nativeEvent: NativeLogEvent) {
  writeEntry({
    timestamp: new Date(nativeEvent.timestampMs).toISOString(),
    sessionId,
    level: nativeEvent.level,
    scope: nativeEvent.scope,
    event: nativeEvent.event,
    data: nativeEvent.data ? normalizeData(nativeEvent.data) : undefined,
  });
}

function writeLog(
  level: LogLevel,
  scope: string,
  event: string,
  data?: LogData,
) {
  writeEntry({
    timestamp: new Date().toISOString(),
    sessionId,
    level,
    scope,
    event,
    data,
  });
}

function writeEntry(entry: LogEntry) {
  if (!diagnosticsEnabled) {
    return;
  }

  if (!initialized) {
    initializeLogging();
  }

  try {
    if (sessionFile) {
      appendLogEntry(sessionFile, entry);
    }
  } catch (error) {
    console.error('写入诊断日志失败', error);
  }

  if (__DEV__) {
    const method = entry.level === 'debug' ? 'log' : entry.level;
    console[method](`[${entry.scope}] ${entry.event}`, entry.data ?? '');
  }
}

function normalizeError(error: unknown): LogValue {
  if (error instanceof Error) {
    return {
      name: error.name,
      message: error.message,
      stack: error.stack ?? null,
    };
  }

  return normalizeValue(error);
}

function normalizeData(data: Record<string, unknown>): LogData {
  return normalizeObject(data);
}

function normalizeObject(value: object): LogData {
  return Object.fromEntries(
    Object.entries(value).map(([key, entry]) => [key, normalizeValue(entry)]),
  );
}

function normalizeValue(value: unknown): LogValue {
  if (
    value === null ||
    typeof value === 'string' ||
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return value;
  }

  if (Array.isArray(value)) {
    return value.map(normalizeValue);
  }

  if (value && typeof value === 'object') {
    return normalizeObject(value);
  }

  return String(value);
}

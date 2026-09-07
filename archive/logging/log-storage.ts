import { Directory, File, Paths } from 'expo-file-system';

import type { LogEntry, LogSession } from './log-types';

const MAX_LOG_SESSIONS = 5;
const MAX_SESSION_BYTES = 250_000;
const LOG_DIRECTORY_NAME = 'framewise-diagnostics';
const LOG_FILE_EXTENSION = '.ndjson';

const logDirectory = new Directory(Paths.document, LOG_DIRECTORY_NAME);

export function createSessionFile(sessionId: string, startedAt: Date) {
  ensureLogDirectory();
  const timestamp = startedAt.toISOString().replaceAll(':', '-');
  const file = new File(
    logDirectory,
    `session-${timestamp}-${sessionId}${LOG_FILE_EXTENSION}`,
  );
  file.create({ intermediates: true, overwrite: false });
  pruneOldSessions();
  return file;
}

export function appendLogEntry(file: File, entry: LogEntry) {
  if (!file.exists) {
    file.create({ intermediates: true, overwrite: false });
  }

  if (file.size >= MAX_SESSION_BYTES) {
    return;
  }

  file.write(`${JSON.stringify(entry)}\n`, { append: true });
}

export async function listLogSessions(): Promise<LogSession[]> {
  if (!logDirectory.exists) {
    return [];
  }

  return Promise.all(
    listLogFiles().map(async (file) => {
      const entries = parseEntries(await file.text());

      return {
        id: file.name,
        startedAt: entries[0]?.timestamp,
        size: file.size,
        entryCount: entries.length,
        errorCount: entries.filter((entry) => entry.level === 'error').length,
      };
    }),
  );
}

export async function readLogSession(sessionId: string) {
  const file = listLogFiles().find((candidate) => candidate.name === sessionId);

  if (!file) {
    throw new Error('日志会话不存在');
  }

  const text = await file.text();
  return { entries: parseEntries(text), text };
}

export function clearLogSessions() {
  if (!logDirectory.exists) {
    return;
  }

  for (const file of listLogFiles()) {
    file.delete();
  }
}

function ensureLogDirectory() {
  logDirectory.create({ idempotent: true, intermediates: true });
}

function listLogFiles() {
  return logDirectory
    .list()
    .filter(
      (entry): entry is File =>
        entry instanceof File && entry.name.endsWith(LOG_FILE_EXTENSION),
    )
    .sort((left, right) => right.name.localeCompare(left.name));
}

function pruneOldSessions() {
  for (const file of listLogFiles().slice(MAX_LOG_SESSIONS)) {
    file.delete();
  }
}

function parseEntries(text: string) {
  const entries: LogEntry[] = [];

  for (const line of text.split('\n')) {
    if (!line) {
      continue;
    }

    try {
      const value: unknown = JSON.parse(line);
      if (isLogEntry(value)) {
        entries.push(value);
      }
    } catch {
      // A partially written final line is ignored when a process is killed.
    }
  }

  return entries;
}

function isLogEntry(value: unknown): value is LogEntry {
  if (!value || typeof value !== 'object') {
    return false;
  }

  const timestamp = Reflect.get(value, 'timestamp');
  const sessionId = Reflect.get(value, 'sessionId');
  const level = Reflect.get(value, 'level');
  const scope = Reflect.get(value, 'scope');
  const event = Reflect.get(value, 'event');
  return (
    typeof timestamp === 'string' &&
    typeof sessionId === 'string' &&
    (level === 'debug' ||
      level === 'info' ||
      level === 'warn' ||
      level === 'error') &&
    typeof scope === 'string' &&
    typeof event === 'string'
  );
}

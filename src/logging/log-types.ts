export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

export type LogValue =
  boolean | number | string | null | LogValue[] | { [key: string]: LogValue };

export type LogData = Record<string, LogValue>;

export type LogEntry = {
  timestamp: string;
  sessionId: string;
  level: LogLevel;
  scope: string;
  event: string;
  data?: LogData;
};

export type LogSession = {
  id: string;
  startedAt?: string;
  size: number;
  entryCount: number;
  errorCount: number;
};

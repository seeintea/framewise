import { createContext, useContext, useState, type ReactNode } from 'react';

export type CaptureSession = {
  presetId: string;
  variantId: string;
  photoUri: string;
  width: number;
  height: number;
};

type CaptureSessionContextValue = {
  session: CaptureSession | undefined;
  setSession: (session: CaptureSession) => void;
  clearSession: () => void;
};

const CaptureSessionContext = createContext<
  CaptureSessionContextValue | undefined
>(undefined);

type CaptureSessionProviderProps = {
  children: ReactNode;
};

export function CaptureSessionProvider({
  children,
}: CaptureSessionProviderProps) {
  const [session, setSession] = useState<CaptureSession>();

  return (
    <CaptureSessionContext
      value={{
        session,
        setSession,
        clearSession: () => setSession(undefined),
      }}
    >
      {children}
    </CaptureSessionContext>
  );
}

export function useCaptureSession(): CaptureSessionContextValue {
  const context = useContext(CaptureSessionContext);

  if (!context) {
    throw new Error(
      'useCaptureSession must be used inside CaptureSessionProvider',
    );
  }

  return context;
}

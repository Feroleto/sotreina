import { createContext, useContext, useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import { apiFetch } from '@/lib/api';
import { authMe, clearBootHints } from '@/lib/boot';

export interface AuthUser {
  id: string;
  firstName: string | null;
  profileImgUrl: string | null;
  maxHr: number | null;
  hasStravaAccount: boolean;
  hasPassword: boolean;
}

interface AuthContextValue {
  user: AuthUser | null;
  loading: boolean;
  logout: () => Promise<void>;
  setUser: (user: AuthUser | null) => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // the request itself fired at module eval in lib/boot.ts (in parallel
    // with the boot prefetches) — this effect only consumes the shared
    // promise, which also spares the duplicate StrictMode fetch in dev
    let cancelled = false;
    authMe.then((u) => {
      if (!cancelled) {
        setUser(u);
        setLoading(false);
      }
    });
    return () => {
      cancelled = true;
    };
  }, []);

  async function logout(): Promise<void> {
    await apiFetch('/auth/logout', { method: 'POST' });
    // drop the optimistic-boot hints so the next (logged-out) load doesn't
    // fire gated fetches; FIRST_SYNC_FLAG stays — a relogin mid-first-import
    // relies on it to resume the progress card
    clearBootHints();
    setUser(null);
  }

  return (
    <AuthContext.Provider value={{ user, loading, logout, setUser }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within an AuthProvider');
  return ctx;
}

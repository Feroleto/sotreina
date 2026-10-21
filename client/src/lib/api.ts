import { API_BASE_URL } from './apiUrl';
import i18n from '@/i18n';

// thin fetch wrapper applied to every API call — the backend session lives in
// an httpOnly cookie, so credentials: 'include' is required on every request
// or auth breaks silently (the cookie just never gets sent cross-origin).
// Accept-Language lets locale-aware endpoints (exercise library, workouts,
// routines) return pt-translated content without every call site having to
// pass it explicitly — same synchronous i18n.language read as dateLocale.ts.
// X-Time-Zone (the browser's IANA zone) lets day-bucketed endpoints (the diet
// logs, summary and history) cut days at local midnight instead of UTC's
const TIME_ZONE = Intl.DateTimeFormat().resolvedOptions().timeZone;

export function apiFetch(path: string, init?: RequestInit): Promise<Response> {
  return fetch(`${API_BASE_URL}${path}`, {
    ...init,
    credentials: 'include',
    headers: { ...init?.headers, 'Accept-Language': i18n.language, 'X-Time-Zone': TIME_ZONE },
  });
}

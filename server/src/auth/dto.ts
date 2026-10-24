import { BadRequestException } from '@nestjs/common';

// Manual validation, no class-validator (not used anywhere in this project) —
// same convention as workouts/dto.ts, exercises/dto.ts, lap-editor/dto.ts

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_EMAIL_LEN = 254;
const MIN_PASSWORD_LEN = 8;
// upper bound exists to cap argon2's hashing cost independent of the throttle
const MAX_PASSWORD_LEN = 128;
const MAX_FIRST_NAME_LEN = 60;

export interface RegisterInput {
  email: string;
  password: string;
  firstName?: string;
}

export interface LoginInput {
  email: string;
  password: string;
}

export interface SetPasswordInput {
  email: string;
  password: string;
}

export interface ForgotPasswordInput {
  email: string;
}

export interface VerifyEmailInput {
  code: string;
}

export interface ResetPasswordInput {
  token: string;
  newPassword: string;
}

/** shared by register and PATCH /users/me (profile edit) */
export function parseFirstName(value: unknown): string {
  if (
    typeof value !== 'string' ||
    value.trim().length === 0 ||
    value.length > MAX_FIRST_NAME_LEN
  ) {
    throw new BadRequestException(
      `firstName must be a non-empty string up to ${MAX_FIRST_NAME_LEN} characters`,
    );
  }
  return value.trim();
}

export function parseRegisterInput(body: unknown): RegisterInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }
  const { email, password, firstName } = body as Record<string, unknown>;
  const result: RegisterInput = {
    email: parseEmail(email),
    password: parsePassword(password, MIN_PASSWORD_LEN),
  };
  if (firstName !== undefined && firstName !== null) {
    result.firstName = parseFirstName(firstName);
  }
  return result;
}

export function parseLoginInput(body: unknown): LoginInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }
  const { email, password } = body as Record<string, unknown>;
  return { email: parseEmail(email), password: parsePassword(password, 1) };
}

export function parseSetPasswordInput(body: unknown): SetPasswordInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }
  const { email, password } = body as Record<string, unknown>;
  return {
    email: parseEmail(email),
    password: parsePassword(password, MIN_PASSWORD_LEN),
  };
}

export function parseForgotPasswordInput(body: unknown): ForgotPasswordInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }
  const { email } = body as Record<string, unknown>;
  return { email: parseEmail(email) };
}

export function parseResetPasswordInput(body: unknown): ResetPasswordInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }
  const { token, newPassword } = body as Record<string, unknown>;
  if (typeof token !== 'string' || token.trim().length === 0) {
    throw new BadRequestException('token is required');
  }
  return {
    token,
    newPassword: parsePassword(newPassword, MIN_PASSWORD_LEN),
  };
}

// a string, never a number: leading zeros are part of the code
export function parseVerifyEmailInput(body: unknown): VerifyEmailInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }
  const { code } = body as Record<string, unknown>;
  const trimmed = typeof code === 'string' ? code.trim() : '';
  if (!/^\d{6}$/.test(trimmed)) {
    throw new BadRequestException('code must be 6 digits');
  }
  return { code: trimmed };
}

// trims + lowercases here — the ONE normalization point; every write/read of
// User.email must go through this, since Postgres' unique index on `email`
// is case-sensitive (no citext) and relies on us never storing mixed case
function parseEmail(value: unknown): string {
  if (typeof value !== 'string') {
    throw new BadRequestException('email is required');
  }
  const normalized = value.trim().toLowerCase();
  if (
    normalized.length === 0 ||
    normalized.length > MAX_EMAIL_LEN ||
    !EMAIL_RE.test(normalized)
  ) {
    throw new BadRequestException('email must be a valid email address');
  }
  return normalized;
}

function parsePassword(value: unknown, minLen: number): string {
  if (
    typeof value !== 'string' ||
    value.length < minLen ||
    value.length > MAX_PASSWORD_LEN
  ) {
    throw new BadRequestException(
      `password must be between ${minLen} and ${MAX_PASSWORD_LEN} characters`,
    );
  }
  return value;
}

import { describe, it, expect } from 'vitest';
import { BadRequestException } from '@nestjs/common';
import {
  parseLoginInput,
  parseRegisterInput,
  parseSetPasswordInput,
  parseForgotPasswordInput,
  parseResetPasswordInput,
  parseVerifyEmailInput,
} from 'src/auth/dto';

describe('parseRegisterInput', () => {
  it('accepts a valid body and normalizes the email', () => {
    const result = parseRegisterInput({
      email: '  Test@Example.com  ',
      password: 'password123',
      firstName: '  Test  ',
    });

    expect(result).toEqual({
      email: 'test@example.com',
      password: 'password123',
      firstName: 'Test',
    });
  });

  it('omits firstName when not provided', () => {
    const result = parseRegisterInput({
      email: 'test@example.com',
      password: 'password123',
    });

    expect(result).toEqual({
      email: 'test@example.com',
      password: 'password123',
    });
    expect(result).not.toHaveProperty('firstName');
  });

  it('rejects a non-object body', () => {
    expect(() => parseRegisterInput(null)).toThrow(BadRequestException);
    expect(() => parseRegisterInput('nope')).toThrow(BadRequestException);
  });

  it('rejects a missing or malformed email', () => {
    expect(() => parseRegisterInput({ password: 'password123' })).toThrow(
      BadRequestException,
    );
    expect(() =>
      parseRegisterInput({ email: 'not-an-email', password: 'password123' }),
    ).toThrow(BadRequestException);
  });

  it('rejects a password shorter than 8 characters', () => {
    expect(() =>
      parseRegisterInput({ email: 'test@example.com', password: 'short' }),
    ).toThrow(BadRequestException);
  });

  it('rejects a password longer than 128 characters', () => {
    expect(() =>
      parseRegisterInput({
        email: 'test@example.com',
        password: 'a'.repeat(129),
      }),
    ).toThrow(BadRequestException);
  });

  it('rejects an empty or overly long firstName', () => {
    expect(() =>
      parseRegisterInput({
        email: 'test@example.com',
        password: 'password123',
        firstName: '   ',
      }),
    ).toThrow(BadRequestException);
    expect(() =>
      parseRegisterInput({
        email: 'test@example.com',
        password: 'password123',
        firstName: 'a'.repeat(61),
      }),
    ).toThrow(BadRequestException);
  });
});

describe('parseLoginInput', () => {
  it('accepts a valid body and normalizes the email', () => {
    const result = parseLoginInput({
      email: 'Test@Example.com',
      password: 'anything',
    });

    expect(result).toEqual({ email: 'test@example.com', password: 'anything' });
  });

  it('accepts a 1-character password (no minimum enforced on login)', () => {
    const result = parseLoginInput({
      email: 'test@example.com',
      password: 'a',
    });

    expect(result.password).toBe('a');
  });

  it('rejects a non-object body', () => {
    expect(() => parseLoginInput(undefined)).toThrow(BadRequestException);
  });

  it('rejects a missing password', () => {
    expect(() => parseLoginInput({ email: 'test@example.com' })).toThrow(
      BadRequestException,
    );
  });

  it('rejects an empty password', () => {
    expect(() =>
      parseLoginInput({ email: 'test@example.com', password: '' }),
    ).toThrow(BadRequestException);
  });
});

describe('parseSetPasswordInput', () => {
  it('accepts a valid body and normalizes the email', () => {
    const result = parseSetPasswordInput({
      email: '  Test@Example.com  ',
      password: 'password123',
    });

    expect(result).toEqual({
      email: 'test@example.com',
      password: 'password123',
    });
  });

  it('rejects a non-object body', () => {
    expect(() => parseSetPasswordInput(null)).toThrow(BadRequestException);
  });

  it('rejects a missing or malformed email', () => {
    expect(() => parseSetPasswordInput({ password: 'password123' })).toThrow(
      BadRequestException,
    );
    expect(() =>
      parseSetPasswordInput({ email: 'not-an-email', password: 'password123' }),
    ).toThrow(BadRequestException);
  });

  it('rejects a password shorter than 8 characters (same minimum as register)', () => {
    expect(() =>
      parseSetPasswordInput({ email: 'test@example.com', password: 'short' }),
    ).toThrow(BadRequestException);
  });
});

describe('parseForgotPasswordInput', () => {
  it('accepts a valid body and normalizes the email', () => {
    const result = parseForgotPasswordInput({ email: '  Test@Example.com  ' });

    expect(result).toEqual({ email: 'test@example.com' });
  });

  it('rejects a non-object body', () => {
    expect(() => parseForgotPasswordInput(null)).toThrow(BadRequestException);
  });

  it('rejects a missing or malformed email', () => {
    expect(() => parseForgotPasswordInput({})).toThrow(BadRequestException);
    expect(() =>
      parseForgotPasswordInput({ email: 'not-an-email' }),
    ).toThrow(BadRequestException);
  });
});

describe('parseResetPasswordInput', () => {
  it('accepts a valid body', () => {
    const result = parseResetPasswordInput({
      token: 'abc123',
      newPassword: 'password123',
    });

    expect(result).toEqual({ token: 'abc123', newPassword: 'password123' });
  });

  it('rejects a non-object body', () => {
    expect(() => parseResetPasswordInput(undefined)).toThrow(
      BadRequestException,
    );
  });

  it('rejects a missing or empty token', () => {
    expect(() =>
      parseResetPasswordInput({ newPassword: 'password123' }),
    ).toThrow(BadRequestException);
    expect(() =>
      parseResetPasswordInput({ token: '   ', newPassword: 'password123' }),
    ).toThrow(BadRequestException);
  });

  it('rejects a newPassword shorter than 8 characters', () => {
    expect(() =>
      parseResetPasswordInput({ token: 'abc123', newPassword: 'short' }),
    ).toThrow(BadRequestException);
  });
});

describe('parseVerifyEmailInput', () => {
  it('accepts 6 digits, trimming whitespace and keeping leading zeros', () => {
    expect(parseVerifyEmailInput({ code: ' 004219 ' })).toEqual({
      code: '004219',
    });
  });

  it.each([
    ['too short', { code: '12345' }],
    ['too long', { code: '1234567' }],
    ['not digits', { code: '12a456' }],
    ['a number, not a string', { code: 123456 }],
    ['missing', {}],
    ['not an object', null],
  ])('rejects a code that is %s', (_label, body) => {
    expect(() => parseVerifyEmailInput(body)).toThrow(BadRequestException);
  });
});

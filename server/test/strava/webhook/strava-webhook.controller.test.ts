import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { BadRequestException } from '@nestjs/common';
import { StravaWebhookController } from 'src/strava/webhook/strava-webhook.controller';
import { StravaWebhookService } from 'src/strava/webhook/strava-webhook.service';

const VERIFY_TOKEN = 'test-verify-token';
const SUBSCRIPTION_ID = '999888';

describe('StravaWebhookController', () => {
  let controller: StravaWebhookController;
  let service: {
    handleDeauthorization: ReturnType<typeof vi.fn>;
    handleActivityDeleted: ReturnType<typeof vi.fn>;
    handleActivityUpdated: ReturnType<typeof vi.fn>;
  };

  beforeEach(async () => {
    service = {
      handleDeauthorization: vi.fn().mockResolvedValue(undefined),
      handleActivityDeleted: vi.fn().mockResolvedValue(undefined),
      handleActivityUpdated: vi.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [StravaWebhookController],
      providers: [
        { provide: StravaWebhookService, useValue: service },
        {
          provide: ConfigService,
          useValue: {
            getOrThrow: vi.fn((key: string) => {
              if (key === 'STRAVA_WEBHOOK_VERIFY_TOKEN') return VERIFY_TOKEN;
              if (key === 'STRAVA_WEBHOOK_SUBSCRIPTION_ID')
                return SUBSCRIPTION_ID;
              throw new Error(`Config key not found: ${key}`);
            }),
          },
        },
      ],
    }).compile();

    controller = module.get(StravaWebhookController);
  });

  describe('verify (GET challenge)', () => {
    it('echoes the challenge back when the verify token matches', () => {
      const result = controller.verify({
        'hub.mode': 'subscribe',
        'hub.verify_token': VERIFY_TOKEN,
        'hub.challenge': 'abc123',
      });

      expect(result).toEqual({ 'hub.challenge': 'abc123' });
    });

    it('rejects a request with the wrong verify token', () => {
      expect(() =>
        controller.verify({
          'hub.mode': 'subscribe',
          'hub.verify_token': 'wrong-token',
          'hub.challenge': 'abc123',
        }),
      ).toThrow(BadRequestException);
    });
  });

  describe('handleEvent (POST)', () => {
    it('deauthorizes the account when the athlete revokes access', async () => {
      await controller.handleEvent({
        object_type: 'athlete',
        aspect_type: 'update',
        object_id: 105494700,
        subscription_id: Number(SUBSCRIPTION_ID),
        owner_id: 105494700,
        event_time: 1700000000,
        updates: { authorized: 'false' },
      });

      expect(service.handleDeauthorization).toHaveBeenCalledWith(105494700n);
    });

    it('ignores unrelated events (e.g. activity create) without touching the account', async () => {
      const result = await controller.handleEvent({
        object_type: 'activity',
        aspect_type: 'create',
        object_id: 999,
        subscription_id: Number(SUBSCRIPTION_ID),
        owner_id: 105494700,
        event_time: 1700000000,
      });

      expect(service.handleDeauthorization).not.toHaveBeenCalled();
      expect(service.handleActivityDeleted).not.toHaveBeenCalled();
      expect(service.handleActivityUpdated).not.toHaveBeenCalled();
      expect(result).toEqual({ received: true });
    });

    it('removes an activity deleted on Strava, scoped to its owner', async () => {
      await controller.handleEvent({
        object_type: 'activity',
        aspect_type: 'delete',
        object_id: 12345,
        subscription_id: Number(SUBSCRIPTION_ID),
        owner_id: 105494700,
        event_time: 1700000000,
      });

      expect(service.handleActivityDeleted).toHaveBeenCalledWith(12345n, 105494700n);
    });

    it('forwards activity title/type updates', async () => {
      await controller.handleEvent({
        object_type: 'activity',
        aspect_type: 'update',
        object_id: 12345,
        subscription_id: Number(SUBSCRIPTION_ID),
        owner_id: 105494700,
        event_time: 1700000000,
        updates: { title: 'Long run' },
      });

      expect(service.handleActivityUpdated).toHaveBeenCalledWith(12345n, 105494700n, {
        title: 'Long run',
      });
    });

    it('acks malformed bodies without throwing (public endpoint, forged garbage must not 500)', async () => {
      for (const body of [
        undefined,
        {},
        { subscription_id: 'not-a-number', object_id: 1 },
        { subscription_id: Number(SUBSCRIPTION_ID), object_id: 'abc' },
        { subscription_id: Number(SUBSCRIPTION_ID), object_id: 1.5 },
        { subscription_id: Number(SUBSCRIPTION_ID), object_id: 1, owner_id: 'x' },
      ]) {
        const result = await controller.handleEvent(body as any);
        expect(result).toEqual({ received: true });
      }

      expect(service.handleDeauthorization).not.toHaveBeenCalled();
      expect(service.handleActivityDeleted).not.toHaveBeenCalled();
    });

    it('ignores events with an unexpected subscription_id, even a forged deauthorization', async () => {
      const result = await controller.handleEvent({
        object_type: 'athlete',
        aspect_type: 'update',
        object_id: 105494700,
        subscription_id: 111222,
        owner_id: 105494700,
        event_time: 1700000000,
        updates: { authorized: 'false' },
      });

      expect(service.handleDeauthorization).not.toHaveBeenCalled();
      expect(result).toEqual({ received: true });
    });
  });
});

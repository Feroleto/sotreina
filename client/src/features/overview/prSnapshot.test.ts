import { describe, expect, it } from 'vitest';
import type { PersonalBestRecord } from '@/lib/types';
import { newRecordKeys, topRecordIdentities } from './prSnapshot';

const rec = (
  name: string,
  rank: number,
  activityId: string,
  movingTime: number,
): PersonalBestRecord => ({
  name,
  rank,
  movingTime,
  distance: 5000,
  startDate: '2026-10-01T10:00:00Z',
  activityId,
  prRank: null,
});

describe('topRecordIdentities', () => {
  it('keeps only rank 1 per distance, keyed by lowercased name', () => {
    expect(
      topRecordIdentities([
        rec('5k', 1, 'a1', 1300),
        rec('5k', 2, 'a2', 1320),
        rec('10K', 1, 'a3', 2900),
      ]),
    ).toEqual({ '5k': 'a1:1300', '10k': 'a3:2900' });
  });
});

describe('newRecordKeys', () => {
  it('celebrates nothing on the first visit (no snapshot yet)', () => {
    expect(newRecordKeys(null, { '5k': 'a1:1300' })).toEqual([]);
  });

  it('flags a distance whose top-1 effort changed or appeared', () => {
    expect(
      newRecordKeys(
        { '5k': 'a1:1300', '10k': 'a3:2900' },
        { '5k': 'a9:1280', '10k': 'a3:2900', '1k': 'a4:230' },
      ),
    ).toEqual(['5k', '1k']);
  });

  it('flags nothing when every top-1 is unchanged', () => {
    expect(newRecordKeys({ '5k': 'a1:1300' }, { '5k': 'a1:1300' })).toEqual([]);
  });
});

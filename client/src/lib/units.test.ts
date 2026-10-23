import { afterEach, describe, expect, it } from 'vitest';
import {
  currentUnits,
  displayToKg,
  displayToKm,
  distanceLabel,
  formatVolume,
  formatWeight,
  goalFromDisplay,
  goalToDisplay,
  kgToDisplay,
  KM_PER_MI,
  kmToDisplay,
  paceToDisplay,
  setUnitPrefs,
  volumeLabel,
  weightLabel,
} from './units';

afterEach(() => setUnitPrefs(null));

describe('distance', () => {
  it('is the identity in km', () => {
    expect(kmToDisplay(10, 'KM')).toBe(10);
    expect(displayToKm(10, 'KM')).toBe(10);
  });

  it('converts a marathon to miles', () => {
    expect(kmToDisplay(42.195, 'MI')).toBeCloseTo(26.2188, 4);
  });

  it('round-trips km → mi → km', () => {
    expect(displayToKm(kmToDisplay(21.0975, 'MI'), 'MI')).toBeCloseTo(
      21.0975,
      10,
    );
  });

  it('round-trips every whole-mile weekly goal through whole km', () => {
    for (let mi = 1; mi <= 186; mi++) {
      expect(goalToDisplay(goalFromDisplay(mi, 'MI'), 'MI')).toBe(mi);
    }
    expect(goalFromDisplay(10, 'MI')).toBe(16);
    expect(goalToDisplay(20, 'KM')).toBe(20);
  });

  it('makes pace slower per mile (5:00/km ≈ 8:03/mi)', () => {
    expect(paceToDisplay(300, 'MI')).toBeCloseTo(482.8, 1);
    expect(paceToDisplay(300, 'KM')).toBe(300);
  });
});

describe('weight', () => {
  // the example from the spec: 45 lb is stored as 20.41 kg (Decimal(6,2))
  // and must read back as 45, not 44.996
  it('round-trips 45 lb through the 2-decimal kg column', () => {
    const stored = displayToKg(45, 'LB');
    expect(stored).toBe(20.41);
    expect(kgToDisplay(stored, 'LB')).toBe(45);
  });

  it.each([5, 10, 25, 35, 45, 95, 135, 225, 315, 405])(
    'round-trips %d lb',
    (lb) => {
      expect(kgToDisplay(displayToKg(lb, 'LB'), 'LB')).toBe(lb);
    },
  );

  it('keeps kg to 2 decimals', () => {
    expect(displayToKg(22.5, 'KG')).toBe(22.5);
    expect(displayToKg(22.555, 'KG')).toBe(22.56);
    expect(kgToDisplay(20.41, 'KG')).toBe(20.41);
  });

  it('formats without trailing zeros', () => {
    expect(formatWeight(20, 'KG')).toBe('20');
    expect(formatWeight(22.5, 'KG')).toBe('22.5');
    expect(formatWeight(20.41, 'LB')).toBe('45');
  });

  it('shows volume in tonnes or thousands of pounds', () => {
    expect(formatVolume(12_345, 'KG')).toBe('12.3');
    expect(volumeLabel('KG')).toBe('t');
    expect(formatVolume(1000, 'LB')).toBe('2.2');
    expect(volumeLabel('LB')).toBe('k lb');
  });
});

describe('current preference', () => {
  it('defaults to km and kg', () => {
    expect(currentUnits()).toEqual({ distanceUnit: 'KM', weightUnit: 'KG' });
    expect(distanceLabel()).toBe('km');
    expect(weightLabel()).toBe('kg');
  });

  it('drives the helpers when no unit is passed', () => {
    setUnitPrefs({ distanceUnit: 'MI', weightUnit: 'LB' });
    expect(distanceLabel()).toBe('mi');
    expect(weightLabel()).toBe('lb');
    expect(kmToDisplay(KM_PER_MI)).toBeCloseTo(1, 10);
  });

  // a user payload from an older backend (before the columns existed)
  it('falls back to the defaults for missing fields', () => {
    setUnitPrefs({});
    expect(currentUnits()).toEqual({ distanceUnit: 'KM', weightUnit: 'KG' });
  });
});

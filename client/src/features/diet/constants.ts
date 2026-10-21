import type { MealType } from '@/lib/types';

// The closed vocabulary MealTypePicker offers when naming a meal — NOT the
// day's slots, which come from GET /meals and can repeat a name or leave one
// out. Order here is just the order the picker lists them in.
export const MEAL_TYPES: MealType[] = ['BREAKFAST', 'LUNCH', 'SNACK', 'DINNER', 'SUPPER'];

// fallback portion for foods with no known household measure
export const DEFAULT_PORTION_G = 100;

// mirror of SERVING_UNITS in server/src/foods/serving-units.ts — the server
// sends a slug, the label is resolved here through i18n (diet:quantity.units.*)
// with proper pluralization. An unknown slug falls back to the slug itself
// rather than breaking the row.
export const SERVING_UNITS = [
  'unit',
  'slice',
  'serving',
  'tablespoon',
  'teaspoon',
  'cup',
  'scoop',
] as const;

export type ServingUnit = (typeof SERVING_UNITS)[number];

export function capitalize(text: string): string {
  return text.charAt(0).toUpperCase() + text.slice(1);
}

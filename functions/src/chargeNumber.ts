export const MINIMUM_CHARGE_NUMBER = 10000;
export const MAXIMUM_CHARGE_NUMBER = 99999;

export const isFiveDigitChargeNumber = (value: unknown): value is number =>
  typeof value === "number" &&
  Number.isSafeInteger(value) &&
  value >= MINIMUM_CHARGE_NUMBER &&
  value <= MAXIMUM_CHARGE_NUMBER;

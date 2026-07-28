const stable = (value: unknown): string => {
  if (value === undefined) return "undefined";
  if (value === null || typeof value !== "object") {
    const serialized = JSON.stringify(value);
    return serialized === undefined ? "undefined" : serialized;
  }
  if (Array.isArray(value)) return `[${value.map(stable).join(",")}]`;
  const object = value as Record<string, unknown>;
  return `{${
    Object.keys(object)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${stable(object[key])}`)
      .join(",")
  }}`;
};

export const stableJson = (value: unknown): string => stable(value);

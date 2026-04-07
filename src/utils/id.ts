let seq = 1;

export function nextId(prefix: string): string {
  const value = `${prefix}-${Date.now()}-${seq}`;
  seq += 1;
  return value;
}

T asT<T>(dynamic v, T fallback) {
  if (v is T) return v;
  return fallback;
}

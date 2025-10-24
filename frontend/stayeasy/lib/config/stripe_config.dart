class StripeConfig {
  StripeConfig._();

  /// TODO: cập nhật publishable key (pk_test hoặc pk_live) trước khi build.
  static const publishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue:
        'pk_test_51SKX10RwyvsRdU4ohibOyxGQGY1WKwlV3Qah4oIadFl1rfGkw2yUSaZsgpC3Xjz5Yntr0mkhPjwRRicEcoQrrpXm00z9J8PPmS',
  );
}

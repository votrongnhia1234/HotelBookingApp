class StripeConfig {
  StripeConfig._();

  /// TODO: cập nhật publishable key (pk_test hoặc pk_live) trước khi build.
  static const publishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue:
        'pk_test_51SKX10RwyvsRdU4ohibOyxGQGY1WKwlV3Qah4oIadFl1rfGkw2yUSaZsgpC3Xjz5Yntr0mkhPjwRRicEcoQrrpXm00z9J8PPmS',
  );

  // Merchant ID cho Apple Pay (để trống nếu chưa cấu hình Apple Merchant)
  static const merchantIdentifier = String.fromEnvironment(
    'STRIPE_MERCHANT_IDENTIFIER',
    defaultValue: '',
  );

  // Country & currency sử dụng cho ví điện tử
  static const merchantCountryCode = String.fromEnvironment(
    'STRIPE_MERCHANT_COUNTRY',
    defaultValue: 'VN',
  );
  static const currencyCode = String.fromEnvironment(
    'STRIPE_CURRENCY',
    defaultValue: 'VND',
  );

  // Bật môi trường test cho Google Pay khi chưa cấu hình production
  static const googlePayTestEnv = bool.fromEnvironment(
    'STRIPE_GPAY_TEST_ENV',
    defaultValue: true,
  );
}

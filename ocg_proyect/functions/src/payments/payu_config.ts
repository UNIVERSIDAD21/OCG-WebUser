export type PayuResolvedConfig = {
  apiKey: string;
  merchantId: string;
  accountId: string;
  checkoutUrl: string;
  test: '0' | '1';
  environment: 'sandbox' | 'production';
};

const SANDBOX_CONFIG: PayuResolvedConfig = {
  apiKey: '4Vj8eK4rloUd272L48hsrarnUA',
  merchantId: '508029',
  accountId: '512321',
  checkoutUrl: 'https://sandbox.checkout.payulatam.com/ppp-web-gateway-payu/',
  test: '1',
  environment: 'sandbox',
};

function readEnv(name: string): string {
  return (process.env[name] ?? '').trim();
}

export function resolvePayuConfig(): PayuResolvedConfig {
  const configuredEnvironment = readEnv('PAYU_ENVIRONMENT').toLowerCase();
  const wantsProduction = configuredEnvironment === 'production';

  if (!wantsProduction) {
    return SANDBOX_CONFIG;
  }

  const apiKey = readEnv('PAYU_API_KEY');
  const merchantId = readEnv('PAYU_MERCHANT_ID');
  const accountId = readEnv('PAYU_ACCOUNT_ID');
  const checkoutUrl =
    readEnv('PAYU_CHECKOUT_URL') ||
    'https://checkout.payulatam.com/ppp-web-gateway-payu/';

  if (!apiKey || !merchantId || !accountId) {
    console.warn(
      'PAYU_ENVIRONMENT=production sin credenciales completas. Se usará sandbox.',
    );
    return SANDBOX_CONFIG;
  }

  return {
    apiKey,
    merchantId,
    accountId,
    checkoutUrl,
    test: '0',
    environment: 'production',
  };
}

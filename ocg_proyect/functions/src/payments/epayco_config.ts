export type EpaycoResolvedConfig = {
  publicKey: string;
  privateKey: string;
  customerId: string;
  checkoutUrl: string;
  test: boolean;
  environment: 'sandbox' | 'production';
};

const SANDBOX_CONFIG: EpaycoResolvedConfig = {
  publicKey: 'PUBLIC_KEY_SANDBOX',
  privateKey: 'PRIVATE_KEY_SANDBOX',
  customerId: 'CUSTOMER_ID_SANDBOX',
  checkoutUrl: 'https://checkout.epayco.co/payment/',
  test: true,
  environment: 'sandbox',
};

function readEnv(name: string): string {
  return (process.env[name] ?? '').trim();
}

export function resolveEpaycoConfig(): EpaycoResolvedConfig {
  const configuredEnvironment = readEnv('EPAYCO_ENVIRONMENT').toLowerCase();
  const wantsProduction = configuredEnvironment === 'production';

  if (!wantsProduction) {
    return SANDBOX_CONFIG;
  }

  const publicKey = readEnv('EPAYCO_PUBLIC_KEY');
  const privateKey = readEnv('EPAYCO_PRIVATE_KEY');
  const customerId = readEnv('EPAYCO_CUSTOMER_ID');
  const checkoutUrl =
    readEnv('EPAYCO_CHECKOUT_URL') ||
    'https://checkout.epayco.co/payment/';

  if (!publicKey || !privateKey || !customerId) {
    console.warn(
      'EPAYCO_ENVIRONMENT=production sin credenciales completas. Se usará sandbox.',
    );
    return SANDBOX_CONFIG;
  }

  return {
    publicKey,
    privateKey,
    customerId,
    checkoutUrl,
    test: false,
    environment: 'production',
  };
}

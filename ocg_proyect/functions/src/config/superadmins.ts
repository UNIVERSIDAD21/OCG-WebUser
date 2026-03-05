import {defineString} from 'firebase-functions/params';

const superadminUidsParam = defineString('SUPERADMIN_UIDS');
const superadminEmailsParam = defineString('SUPERADMIN_EMAILS');

function parseCsv(value: string | undefined): Set<string> {
  if (!value) return new Set<string>();

  return new Set(
    value
      .split(',')
      .map((item) => item.trim().toLowerCase())
      .filter((item) => item.length > 0),
  );
}

export type SuperadminConfig = {
  uids: Set<string>;
  emails: Set<string>;
  enabled: boolean;
};

export function loadSuperadminConfig(): SuperadminConfig {
  const uids = parseCsv(superadminUidsParam.value());
  const emails = parseCsv(superadminEmailsParam.value());
  const enabled = uids.size > 0 || emails.size > 0;

  return {uids, emails, enabled};
}

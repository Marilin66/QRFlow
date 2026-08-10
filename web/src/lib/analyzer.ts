import type { QrResult } from './types';

const SUSPICIOUS_TLDS = ['tk', 'ml', 'ga', 'cf', 'gq'];
const EMAIL_PATTERN = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
const PHONE_PATTERN = /^\+?[0-9][0-9 .\-()]{6,19}$/;
const GENERIC_SCHEME = /^([a-z][a-z0-9+.-]*):\/\//;

function shorten(value: string, max = 60): string {
  const v = value.replace(/\n/g, ' ').trim();
  return v.length <= max ? v : `${v.slice(0, max)}…`;
}

/** Analyse une chaîne brute et identifie son type. */
export function analyze(raw: string): QrResult {
  const content = raw.trim();
  if (!content) return { type: 'unknown', raw, summary: shorten(raw) };

  const wifi = tryWifi(content);
  if (wifi) return wifi;

  const geo = tryGeo(content);
  if (geo) return geo;

  const vcard = tryVCard(content);
  if (vcard) return vcard;

  const calendar = tryCalendar(content);
  if (calendar) return calendar;

  const sms = trySms(content);
  if (sms) return sms;

  const email = tryEmail(content);
  if (email) return email;

  const phone = tryPhone(content);
  if (phone) return phone;

  const app = tryApp(content);
  if (app) return app;

  const url = tryUrl(content);
  if (url) return url;

  return { type: 'text', raw, summary: shorten(content), text: { text: content } };
}

function tryWifi(content: string): QrResult | null {
  const upper = content.toUpperCase();
  if (!upper.startsWith('WIFI:')) return null;
  let ssid: string | undefined;
  let security: string | undefined;
  let password: string | undefined;
  let hidden = false;
  for (const part of content.slice(5).split(';')) {
    if (!part) continue;
    const colon = part.indexOf(':');
    if (colon <= 0) continue;
    const key = part.slice(0, colon).toUpperCase();
    const value = part.slice(colon + 1);
    if (key === 'S') ssid = value;
    else if (key === 'T') security = value || 'nopass';
    else if (key === 'P') password = value;
    else if (key === 'H') hidden = value.toUpperCase() === 'TRUE';
  }
  if (!ssid) return null;
  return {
    type: 'wifi',
    raw: content,
    summary: ssid,
    wifi: { ssid, security: (security ?? 'nopass').toUpperCase(), password, hidden },
  };
}

function tryGeo(content: string): QrResult | null {
  const match = /^(?:GEO|geo):\s*([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)/.exec(
    content,
  );
  if (!match) return null;
  const latitude = Number(match[1]);
  const longitude = Number(match[2]);
  if (Number.isNaN(latitude) || Number.isNaN(longitude)) return null;
  return {
    type: 'geo',
    raw: content,
    summary: `${latitude.toFixed(5)}, ${longitude.toFixed(5)}`,
    geo: { latitude, longitude },
  };
}

function tryVCard(content: string): QrResult | null {
  const upper = content.toUpperCase();
  const isVcard = upper.includes('BEGIN:VCARD');
  const isMecard = upper.startsWith('MECARD:');

  let name: string | undefined;
  let phone: string | undefined;
  let email: string | undefined;
  let org: string | undefined;
  let address: string | undefined;
  let url: string | undefined;
  let note: string | undefined;

  if (isVcard) {
    for (const line of content.split(/[\r\n]+/)) {
      const colon = line.indexOf(':');
      if (colon <= 0) continue;
      const key = line.slice(0, colon).split(';')[0].toUpperCase();
      const value = line.slice(colon + 1).trim();
      if (key === 'FN' || key === 'N') name = value;
      else if (key === 'TEL') phone = value;
      else if (key === 'EMAIL') email = value;
      else if (key === 'ORG') org = value;
      else if (key === 'ADR') address = value;
      else if (key === 'URL') url = value;
      else if (key === 'NOTE') note = value;
    }
  } else if (isMecard) {
    for (const part of content.slice(7).split(';')) {
      const colon = part.indexOf(':');
      if (colon <= 0) continue;
      const key = part.slice(0, colon).toUpperCase();
      const value = part.slice(colon + 1);
      if (key === 'N') name = value;
      else if (key === 'TEL') phone = value;
      else if (key === 'EMAIL') email = value;
      else if (key === 'ORG') org = value;
      else if (key === 'ADR') address = value;
      else if (key === 'URL') url = value;
      else if (key === 'NOTE') note = value;
    }
  } else {
    return null;
  }

  if (!name && !phone && !email && !org && !address && !url && !note) return null;
  return {
    type: 'vcard',
    raw: content,
    summary: name ?? phone ?? email ?? 'Contact',
    vcard: { name, phone, email, org, address, url, note },
  };
}

function tryCalendar(content: string): QrResult | null {
  if (!content.toUpperCase().includes('BEGIN:VEVENT')) return null;

  const read = (key: string): string | undefined => {
    const match = new RegExp(`${key}:([^\\r\\n]*)`, 'i').exec(content);
    return match?.[1]?.trim();
  };

  const parseDate = (value?: string): string | undefined => {
    if (!value) return undefined;
    const v = value.replace('T', '').replace('Z', '');
    if (v.length === 14) {
      return `${v.slice(0, 4)}-${v.slice(4, 6)}-${v.slice(6, 8)}T${v.slice(8, 10)}:${v.slice(10, 12)}:${v.slice(12, 14)}`;
    }
    if (v.length === 8) {
      return `${v.slice(0, 4)}-${v.slice(4, 6)}-${v.slice(6, 8)}`;
    }
    return undefined;
  };

  const title = read('SUMMARY');
  const start = parseDate(read('DTSTART'));
  const end = parseDate(read('DTEND'));
  const location = read('LOCATION');
  const description = read('DESCRIPTION');

  if (!title && !start && !location) return null;
  return {
    type: 'calendar',
    raw: content,
    summary: title ?? 'Événement',
    calendar: { title, start, end, location, description },
  };
}

function trySms(content: string): QrResult | null {
  const upper = content.toUpperCase();
  if (upper.startsWith('SMSTO:')) {
    const rest = content.slice(6);
    const colon = rest.indexOf(':');
    const number = colon >= 0 ? rest.slice(0, colon) : rest;
    const message = colon >= 0 ? rest.slice(colon + 1) : undefined;
    if (number) return { type: 'sms', raw: content, summary: number, sms: { number, message } };
  }
  if (upper.startsWith('SMS:') || upper.startsWith('SMSP:')) {
    const match = /^sms[p]?:([^?]+)(?:\?(.+))?$/i.exec(content);
    if (match) {
      const params = new URLSearchParams(match[2] ?? '');
      return {
        type: 'sms',
        raw: content,
        summary: match[1],
        sms: { number: match[1], message: params.get('body') ?? undefined },
      };
    }
  }
  return null;
}

function tryEmail(content: string): QrResult | null {
  const upper = content.toUpperCase();
  if (upper.startsWith('MAILTO:')) {
    const rest = content.slice(7);
    const q = rest.indexOf('?');
    const address = q >= 0 ? rest.slice(0, q) : rest;
    if (!address) return null;
    const params = q >= 0 ? new URLSearchParams(rest.slice(q + 1)) : new URLSearchParams();
    return {
      type: 'email',
      raw: content,
      summary: address,
      email: {
        address,
        subject: params.get('subject') ?? undefined,
        body: params.get('body') ?? undefined,
      },
    };
  }    if (upper.startsWith('MATMSG:')) {
      const read = (key: string): string | undefined => {
        const match = new RegExp(`${key}:([^;]*)`, 'i').exec(content);
        return match?.[1]?.trim();
      };
      const address = read('TO');
      if (address) {
        return {
          type: 'email',
          raw: content,
          summary: address,
          email: { address, subject: read('SUB'), body: read('BODY') },
        };
      }
    }
    // Adresse e-mail brute.
    if (EMAIL_PATTERN.test(content)) {
      return {
        type: 'email',
        raw: content,
        summary: content,
        email: { address: content },
      };
    }
    return null;
  }

function tryPhone(content: string): QrResult | null {
  if (content.toUpperCase().startsWith('TEL:')) {
    const number = content.slice(4).trim();
    if (number) return { type: 'phone', raw: content, summary: number, phone: { number } };
    return null;
  }
  if (PHONE_PATTERN.test(content)) {
    return { type: 'phone', raw: content, summary: content, phone: { number: content } };
  }
  return null;
}

function tryApp(content: string): QrResult | null {
  const lower = content.toLowerCase();
  if (lower.startsWith('market://')) {
    const id = new URL(content).searchParams.get('id') ?? undefined;
    return { type: 'app', raw: content, summary: id ?? content, app: { uri: content, packageName: id } };
  }
  if (lower.startsWith('intent://')) {
    return { type: 'app', raw: content, summary: content, app: { uri: content } };
  }
  return null;
}

function tryUrl(content: string): QrResult | null {
  const schemeMatch = GENERIC_SCHEME.exec(content);
  let url = content;
  let scheme: string | undefined;
  if (schemeMatch) {
    scheme = schemeMatch[1].toLowerCase();
  } else if (content.startsWith('www.')) {
    url = `https://${content}`;
    scheme = 'https';
  } else {
    return null;
  }

  if (!['http', 'https', 'ftp'].includes(scheme ?? '')) return null;

  let host = '';
  try {
    host = new URL(url).host.toLowerCase();
  } catch {
    host = content;
  }

  const reasons: string[] = [];
  const isIp = /^\d{1,3}(\.\d{1,3}){3}$/.test(host);
  if (isIp) reasons.push('Le domaine est une adresse IP (peu fiable).');
  const tld = host.split('.').pop() ?? '';
  if (SUSPICIOUS_TLDS.includes(tld)) {
    reasons.push(`Extension de domaine souvent utilisée pour des arnaques (.${tld}).`);
  }
  if (host.includes('@')) {
    reasons.push('Le domaine contient un « @ », ce qui peut masquer la vraie destination.');
  }

  return {
    type: 'url',
    raw: content,
    summary: host,
    url: {
      url,
      domain: host,
      isSecure: scheme === 'https',
      suspicious: reasons.length > 0,
      reasons,
    },
  };
}

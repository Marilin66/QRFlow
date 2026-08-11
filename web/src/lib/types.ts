import type { IconName } from '../components/icons';

export type QrContentType =
  | 'url'
  | 'text'
  | 'phone'
  | 'email'
  | 'sms'
  | 'vcard'
  | 'wifi'
  | 'geo'
  | 'calendar'
  | 'app'
  | 'unknown';

export const TYPE_META: Record<QrContentType, { label: string; icon: IconName }> = {
  url: { label: 'URL', icon: 'globe' },
  text: { label: 'Texte', icon: 'file' },
  phone: { label: 'Numéro de téléphone', icon: 'phone' },
  email: { label: 'Adresse e-mail', icon: 'mail' },
  sms: { label: 'SMS', icon: 'chat' },
  vcard: { label: 'Contact', icon: 'user' },
  wifi: { label: 'Réseau Wi-Fi', icon: 'wifi' },
  geo: { label: 'Géolocalisation', icon: 'map-pin' },
  calendar: { label: 'Événement', icon: 'calendar' },
  app: { label: 'Application', icon: 'smartphone' },
  unknown: { label: 'Contenu inconnu', icon: 'question' },
};

export interface QrResult {
  type: QrContentType;
  raw: string;
  summary: string;
  url?: {
    url: string;
    domain: string;
    isSecure: boolean;
    suspicious: boolean;
    reasons: string[];
  };
  phone?: { number: string };
  email?: { address: string; subject?: string; body?: string };
  sms?: { number: string; message?: string };
  vcard?: {
    name?: string;
    phone?: string;
    email?: string;
    org?: string;
    address?: string;
    url?: string;
    note?: string;
  };
  wifi?: { ssid: string; security: string; password?: string; hidden?: boolean };
  geo?: { latitude: number; longitude: number };
  calendar?: {
    title?: string;
    start?: string;
    end?: string;
    location?: string;
    description?: string;
  };
  app?: { uri: string; packageName?: string };
  text?: { text: string };
}

export type ScanMethod = 'screenshot' | 'screen_scan' | 'camera';

export const METHOD_LABEL: Record<ScanMethod, string> = {
  screenshot: 'Capture d’écran',
  screen_scan: 'Scanner l’écran',
  camera: 'Caméra',
};

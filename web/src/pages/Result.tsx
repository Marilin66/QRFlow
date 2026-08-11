import { useEffect, useMemo, useRef } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Icon } from '../components/icons';
import { openUrl, copyText, shareText } from '../lib/actions';
import { addHistory, updateActionHistory } from '../lib/history';
import { useApp } from '../lib/store';
import { METHOD_LABEL, type QrResult } from '../lib/types';
import QrBadge from '../components/QrBadge';

interface ActionDef {
  label: string;
  primary?: boolean;
  confirmMessage?: string;
  run: () => Promise<boolean> | boolean;
}

const savedKeys = new Set<string>();

export default function Result() {
  const navigate = useNavigate();
  const { lastResult, confirmActions, showToast } = useApp();
  const savedRef = useRef(false);

  useEffect(() => {
    if (!lastResult || lastResult.fromHistory || savedRef.current) return;
    savedRef.current = true;
    // Évite le doublon d'enregistrement (StrictMode, re-scan du même contenu).
    const key = `${lastResult.method}:${lastResult.raw}`;
    if (savedKeys.has(key)) return;
    savedKeys.add(key);
    addHistory({
      ts: Date.now(),
      type: lastResult.result.type,
      raw: lastResult.raw,
      summary: lastResult.result.summary,
      method: lastResult.method,
    });
  }, [lastResult]);

  const actions = useMemo<ActionDef[]>(() => {
    if (!lastResult) return [];
    const r = lastResult.result;
    const defs: ActionDef[] = [];

    const add = (def: ActionDef) => defs.push(def);

    if (r.type === 'url' && r.url) {
      add({
        label: 'Ouvrir le lien',
        primary: true,
        confirmMessage: r.url.suspicious
          ? `${r.url.url}\n\nAvertissement : ${r.url.reasons.join('\n• ')}`
          : r.url.url,
        run: () => openUrl(r.url!.url, 'Ouvrir ce lien ?'),
      });
      add({
        label: 'Copier',
        run: async () => {
          const ok = await copyText(r.url!.url);
          if (ok) showToast('Lien copié');
          return ok;
        },
      });
      add({ label: 'Partager', run: () => shareText(r.url!.url) });
    } else if (r.type === 'phone' && r.phone) {
      const number = r.phone.number;
      add({
        label: 'Appeler',
        primary: true,
        confirmMessage: number,
        run: () => {
          const ok = window.confirm(`Appeler ${number} ?`);
          if (!ok) return false;
          window.location.href = `tel:${number}`;
          return true;
        },
      });
      add({
        label: 'Copier',
        run: async () => {
          const ok = await copyText(number);
          if (ok) showToast('Numéro copié');
          return ok;
        },
      });
    } else if (r.type === 'email' && r.email) {
      const email = r.email;
      add({
        label: 'Envoyer un e-mail',
        primary: true,
        confirmMessage: email.address,
        run: () => {
          const ok = window.confirm(`Ouvrir l'application e-mail pour ${email.address} ?`);
          if (!ok) return false;
          const params = new URLSearchParams();
          if (email.subject) params.set('subject', email.subject);
          if (email.body) params.set('body', email.body);
          window.location.href = `mailto:${email.address}?${params.toString()}`;
          return true;
        },
      });
      add({
        label: 'Copier',
        run: async () => {
          const ok = await copyText(email.address);
          if (ok) showToast('Adresse copiée');
          return ok;
        },
      });
    } else if (r.type === 'sms' && r.sms) {
      const sms = r.sms;
      add({
        label: 'Ouvrir l’application SMS',
        primary: true,
        confirmMessage: sms.message ? `À ${sms.number}\n\n${sms.message}` : sms.number,
        run: () => {
          const ok = window.confirm('Ouvrir l’application SMS ?');
          if (!ok) return false;
          const params = new URLSearchParams();
          if (sms.message) params.set('body', sms.message);
          window.location.href = `sms:${sms.number}?${params.toString()}`;
          return true;
        },
      });
      add({
        label: 'Copier',
        run: async () => {
          const ok = await copyText(r.raw);
          if (ok) showToast('Contenu copié');
          return ok;
        },
      });
    } else if (r.type === 'wifi' && r.wifi) {
      const wifi = r.wifi;
      add({
        label: wifi.password ? 'Copier le mot de passe' : 'Réseau sans mot de passe',
        primary: true,
        run: async () => {
          if (!wifi.password) return true;
          const ok = await copyText(wifi.password);
          if (ok) showToast('Mot de passe copié');
          return ok;
        },
      });
      add({
        label: 'Partager le réseau',
        run: () =>
          shareText(
            `Wi-Fi : ${wifi.ssid}\nSécurité : ${wifi.security}`
            + (wifi.password ? `\nMot de passe : ${wifi.password}` : ''),
          ),
      });
    } else if (r.type === 'geo' && r.geo) {
      const geo = r.geo;
      add({
        label: 'Ouvrir dans Maps',
        primary: true,
        confirmMessage: `${geo.latitude}, ${geo.longitude}`,
        run: () =>
          openUrl(
            `https://www.google.com/maps/search/?api=1&query=${geo.latitude},${geo.longitude}`,
            'Ouvrir dans Maps ?',
          ),
      });
      add({
        label: 'Copier les coordonnées',
        run: async () => {
          const ok = await copyText(`${geo.latitude}, ${geo.longitude}`);
          if (ok) showToast('Coordonnées copiées');
          return ok;
        },
      });
    } else if (r.type === 'calendar' && r.calendar) {
      add({ label: 'Télécharger (.ics)', primary: true, run: () => downloadIcs(r) });
      add({ label: 'Copier les détails', run: () => copyText(r.raw) });
    } else if (r.type === 'vcard' && r.vcard) {
      add({ label: 'Télécharger (.vcf)', primary: true, run: () => downloadVcf(r) });
      add({ label: 'Copier la fiche', run: () => copyText(r.raw) });
    } else if (r.type === 'app' && r.app) {
      const app = r.app;
      add({
        label: 'Ouvrir',
        primary: true,
        confirmMessage: app.uri,
        run: () => {
          const ok = window.confirm(`Ouvrir ${app.uri} ?`);
          if (!ok) return false;
          window.location.href = app.uri;
          return true;
        },
      });
      add({
        label: 'Copier',
        run: async () => {
          const ok = await copyText(app.uri);
          if (ok) showToast('Contenu copié');
          return ok;
        },
      });
    }

    // Texte et contenu inconnu uniquement : pas d'actions spécifiques.
    if (defs.length === 0) {
      add({
        label: 'Copier',
        primary: true,
        run: async () => {
          const ok = await copyText(r.raw);
          if (ok) showToast('Contenu copié');
          return ok;
        },
      });
      add({ label: 'Partager', run: () => shareText(r.raw) });
    }

    return defs;
  }, [lastResult, showToast]);

  async function runAction(action: ActionDef) {
    let proceed = true;
    if (confirmActions && action.confirmMessage) {
      proceed = window.confirm(`${action.confirmMessage}\n\nConfirmer ?`);
    }
    if (!proceed) return;
    await action.run();
    updateActionHistoryById(action.label);
  }

  function updateActionHistoryById(label: string) {
    if (!lastResult || lastResult.fromHistory) return;
    const entries = JSON.parse(localStorage.getItem('qrflow:history') ?? '[]') as {
      id: number;
    }[];
    if (entries.length > 0) {
      updateActionHistory(entries[0].id, label);
    }
  }

  if (!lastResult) {
    return (
      <div className="page-enter space-y-4 py-16 text-center">
        <div className="grid place-items-center">
          <Icon name="search" className="size-12 text-slate-300 dark:text-slate-600" />
        </div>
        <p className="text-slate-500 dark:text-slate-400">
          Aucun résultat à afficher. Lancez d’abord un scan.
        </p>
        <Link to="/" className="btn btn-primary">
          Retour à l’accueil
        </Link>
      </div>
    );
  }

  const r = lastResult.result;

  return (
    <div className="page-enter space-y-5">
      <div className="flex items-center justify-between gap-3">
        <QrBadge type={r.type} />
        <span className="font-mono text-[11px] uppercase tracking-widest text-slate-400 dark:text-slate-500">
          {METHOD_LABEL[lastResult.method]}
        </span>
      </div>

      {/* Contenu brut — en mono, comme des données */}
      <pre className="max-h-52 overflow-auto whitespace-pre-wrap break-words rounded-2xl border border-slate-200 bg-ink-950 p-4 font-mono text-[13px] leading-relaxed text-laser-400 dark:border-ink-800 dark:bg-ink-950">
        {r.raw}
      </pre>

      <Details result={r} />

      {r.type === 'url' && r.url?.suspicious && (
        <div className="rounded-2xl border border-safety-500/40 bg-safety-500/10 p-4 text-sm text-safety-500 dark:border-safety-500/25">
          <p className="flex items-center gap-2 font-bold">
            <Icon name="alert" className="size-4" />
            Lien potentiellement dangereux
          </p>
          <ul className="mt-1 list-inside list-disc space-y-0.5">
            {r.url.reasons.map((reason, i) => (
              <li key={i}>{reason}</li>
            ))}
          </ul>
        </div>
      )}

      <div className="space-y-2.5">
        {actions.map((action, i) => (
          <button
            key={i}
            onClick={() => void runAction(action)}
            className={action.primary ? 'btn btn-primary w-full' : 'btn btn-ghost w-full'}
          >
            {action.label}
          </button>
        ))}
      </div>

      <div className="flex gap-3 pt-2">
        <Link to="/import" className="btn btn-ghost flex-1">
          Nouvelle capture
        </Link>
        <button onClick={() => navigate('/')} className="btn btn-ghost flex-1">
          Accueil
        </button>
      </div>
    </div>
  );
}

function Details({ result }: { result: QrResult }) {
  const rows: Array<[string, string]> = [];
  const add = (label: string, value?: string | null) => {
    if (value) rows.push([label, value]);
  };

  if (result.type === 'url' && result.url) {
    add('Domaine', result.url.domain);
    add('Connexion', result.url.isSecure ? 'Sécurisée (HTTPS)' : 'Non sécurisée (HTTP)');
  } else if (result.type === 'phone' && result.phone) {
    add('Numéro', result.phone.number);
  } else if (result.type === 'email' && result.email) {
    add('Adresse', result.email.address);
    add('Objet', result.email.subject);
    add('Message', result.email.body);
  } else if (result.type === 'sms' && result.sms) {
    add('Numéro', result.sms.number);
    add('Message', result.sms.message);
  } else if (result.type === 'vcard' && result.vcard) {
    add('Nom', result.vcard.name);
    add('Téléphone', result.vcard.phone);
    add('E-mail', result.vcard.email);
    add('Organisation', result.vcard.org);
    add('Adresse', result.vcard.address);
    add('Site web', result.vcard.url);
    add('Note', result.vcard.note);
  } else if (result.type === 'wifi' && result.wifi) {
    add('Réseau', result.wifi.ssid);
    add('Sécurité', result.wifi.security);
    add('Mot de passe', result.wifi.password);
    add('Réseau masqué', result.wifi.hidden ? 'Oui' : null);
  } else if (result.type === 'geo' && result.geo) {
    add('Latitude', result.geo.latitude.toFixed(6));
    add('Longitude', result.geo.longitude.toFixed(6));
  } else if (result.type === 'calendar' && result.calendar) {
    add('Titre', result.calendar.title);
    add('Début', formatDate(result.calendar.start));
    add('Fin', formatDate(result.calendar.end));
    add('Lieu', result.calendar.location);
    add('Description', result.calendar.description);
  } else if (result.type === 'app' && result.app) {
    add('Application', result.app.packageName ?? result.app.uri);
  }

  if (rows.length === 0) return null;

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 dark:border-ink-800">
      {rows.map(([label, value], i) => (
        <div
          key={i}
          className={`flex flex-col gap-0.5 px-4 py-3 text-sm ${
            i % 2 === 0 ? 'bg-white dark:bg-ink-900' : 'bg-slate-50 dark:bg-ink-950/60'
          }`}
        >
          <span className="eyebrow">{label}</span>
          <span className="break-words">{value}</span>
        </div>
      ))}
    </div>
  );
}

function formatDate(value?: string): string | undefined {
  if (!value) return undefined;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleString('fr-FR');
}

function downloadIcs(result: QrResult) {
  const cal = result.calendar;
  if (!cal) return false;
  const fmt = (iso?: string) => {
    if (!iso) return '';
    const d = new Date(iso);
    const p = (n: number) => String(n).padStart(2, '0');
    return `${d.getUTCFullYear()}${p(d.getUTCMonth() + 1)}${p(d.getUTCDate())}T${p(d.getUTCHours())}${p(d.getUTCMinutes())}00Z`;
  };
  const ics = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'BEGIN:VEVENT',
    `SUMMARY:${cal.title ?? 'Événement'}`,
    `DTSTART:${fmt(cal.start) || fmt(new Date().toISOString())}`,
    `DTEND:${fmt(cal.end) || fmt(cal.start) || fmt(new Date().toISOString())}`,
    cal.location ? `LOCATION:${cal.location}` : '',
    cal.description ? `DESCRIPTION:${cal.description}` : '',
    'END:VEVENT',
    'END:VCALENDAR',
  ]
    .filter(Boolean)
    .join('\r\n');
  const blob = new Blob([ics], { type: 'text/calendar' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'evenement.ics';
  a.click();
  URL.revokeObjectURL(url);
  return true;
}

function downloadVcf(result: QrResult) {
  const v = result.vcard;
  if (!v) return false;
  const lines = [
    'BEGIN:VCARD',
    'VERSION:3.0',
    v.name ? `FN:${v.name}` : '',
    v.phone ? `TEL:${v.phone}` : '',
    v.email ? `EMAIL:${v.email}` : '',
    v.org ? `ORG:${v.org}` : '',
    v.address ? `ADR:;;${v.address};;;` : '',
    v.url ? `URL:${v.url}` : '',
    v.note ? `NOTE:${v.note}` : '',
    'END:VCARD',
  ].filter(Boolean);
  const blob = new Blob([lines.join('\n')], { type: 'text/vcard' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'contact.vcf';
  a.click();
  URL.revokeObjectURL(url);
  return true;
}

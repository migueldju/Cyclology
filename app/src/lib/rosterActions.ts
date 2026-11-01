import type { SheetAction } from '../components/Modal';
import { t } from '../i18n';
import { api } from './api';
import { dateTime, moneyShort } from './format';
import type { RosterRow } from './types';

/** Acciones sobre un ciclista de mi plantilla: vender al juego, cambiar la cláusula, blindarlo, poner o quitar de la venta */
export function actionsFor(r: RosterRow, opts: { onChangeClause?: () => void } = {}): SheetAction[] {
  if (!r.transferable) return [];               // le llega o se va el lunes: no se puede tocar
  const out: SheetAction[] = [];
  if (r.game_offer_id && r.game_offer_amount) {
    out.push({
      label: t('actions.sellToGame', { amount: moneyShort(r.game_offer_amount) }), kind: 'primary',
      hint: t('actions.sellToGameHint', { when: dateTime(r.game_offer_expires) }),
      onPress: () => api.acceptGameOffer(r.game_offer_id!),
    });
  }
  if (opts.onChangeClause) {
    out.push({
      label: t('actions.changeClause'),
      hint: t('actions.changeClauseHint', { from: moneyShort(clauseLevelValue(clauseBase(r), 0)),
                                            to: moneyShort(clauseLevelValue(clauseBase(r), CLAUSE_LEVELS - 1)) }),
      onPress: opts.onChangeClause,
    });
  }
  // blindarlo la semana que viene (una vez por semana)
  if (!r.locked_next) {
    out.push({ label: t('actions.lock', { amount: moneyShort(r.lock_cost) }), hint: t('actions.lockHint'),
               onPress: () => api.lockRider(r.ownership_id) });
  }
  out.push(r.for_sale
    ? { label: t('actions.unsell'), hint: t('actions.unsellHint'),
        onPress: () => api.setForSale(r.ownership_id, false) }
    : { label: t('actions.sell'),
        hint: t('actions.sellHint'),
        onPress: () => api.setForSale(r.ownership_id, true) });
  return out;
}

/**
 * Escalones de la cláusula (las mismas cuentas que set_clause en la base de datos): 0 = 130 %, 1 = 150 %,
 * 2 = 200 % … 8 = 500 % de la base, que es lo que pagaste o, si es mayor, su valor de mercado. Subir cuesta la
 * mitad de lo que sube; bajar devuelve un cuarto.
 */
export const CLAUSE_LEVELS = 9;

export const clausePct = (level: number) => (level <= 0 ? 130 : 150 + 50 * (level - 1));

/** Base de la cláusula: lo pagado o, si es mayor, el valor de mercado */
export const clauseBase = (r: { price_paid: number; market_value: number }) => Math.max(r.price_paid, r.market_value);

export function clauseLevelValue(base: number, level: number): number {
  return Math.round((base * clausePct(level)) / 100);
}

/** Lo que cuesta (positivo) o devuelve (negativo) pasar de la cláusula actual a un nivel */
export function clauseChange(clause: number, base: number, level: number): number {
  const target = clauseLevelValue(base, level);
  return target >= clause ? Math.ceil((target - clause) / 2) : -Math.floor((clause - target) / 4);
}

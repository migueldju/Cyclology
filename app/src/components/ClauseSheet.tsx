import { useEffect, useState } from 'react';
import { Pressable, StyleSheet, TextInput, View } from 'react-native';
import { t } from '../i18n';
import { api } from '../lib/api';
import { money, moneyShort, parseAmount } from '../lib/format';
import { CLAUSE_MAX_PCT, CLAUSE_MIN_PCT, clauseChange } from '../lib/rosterActions';
import type { RosterRow } from '../lib/types';
import { colors, fonts, space, type } from '../theme';
import { Button } from './Button';
import { Sheet } from './Modal';
import { RangeSlider } from './RangeSlider';
import { ErrorText } from './Section';
import { Txt } from './Txt';

const STEPS = CLAUSE_MAX_PCT - CLAUSE_MIN_PCT + 1;      // de 1 en 1 %: 130 %, 131 % … 700 %

/**
 * Cambiar la cláusula de uno de mis ciclistas: una barra del 130 % al 700 % de su base (lo que pagó o, si es
 * mayor, su valor de mercado), de 1 en 1 %, con − y + para afinar, o escribiendo la cantidad. Subir cuesta la mitad
 * de lo que sube; bajar devuelve un cuarto.
 */
export function ClauseSheet({ row, available, visible, onClose, onDone }: {
  row: RosterRow | null; available: number | null | undefined; visible: boolean; onClose: () => void; onDone?: () => void;
}) {
  // la cantidad elegida: la barra la pone en porcentajes enteros; escribiendo, en la cifra exacta
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => { if (visible && row) { setText(String(row.clause)); setError(null); } }, [visible, row]);

  if (!row) return null;
  const base = Math.max(1, row.clause_base);
  const min = Math.ceil(base * CLAUSE_MIN_PCT / 100);
  const max = Math.floor(base * CLAUSE_MAX_PCT / 100);
  const target = parseAmount(text) ?? 0;
  const pct = Math.min(CLAUSE_MAX_PCT, Math.max(CLAUSE_MIN_PCT, Math.round((target / base) * 100)));
  const inRange = target >= min && target <= max;
  const same = target === row.clause;
  const change = same || !inRange ? 0 : clauseChange(row.clause, target);     // > 0 pago, < 0 me devuelven
  const after = available != null ? available - change : null;
  const short = change > 0 && after != null && after < 0;
  const setPct = (p: number) => setText(String(Math.round((base * Math.min(CLAUSE_MAX_PCT, Math.max(CLAUSE_MIN_PCT, p))) / 100)));
  const move = (d: number) => setPct(pct + d);

  async function confirm() {
    if (!row || same || !inRange) return;
    setBusy(true);
    setError(null);
    try {
      await api.setClause(row.ownership_id, target);
      onDone?.();
      onClose();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Sheet visible={visible} onClose={onClose} title={t('clause.title', { name: row.rider_name })}>
      <View style={styles.headline}>
        <Txt variant="title" style={{ color: colors.inkSoft }}>{moneyShort(row.clause)}</Txt>
        <Txt variant="title" style={{ color: colors.inkSoft }}>→</Txt>
        <Txt variant="display">{moneyShort(target)}</Txt>
        <Txt variant="small">({pct}{' '}%)</Txt>
      </View>
      {/* o escribir la cantidad exacta */}
      <TextInput
        value={target ? money(target).replace(' €', '') : ''}
        onChangeText={setText}
        keyboardType="number-pad"
        style={styles.amount}
        accessibilityLabel={t('sheet.amountLabel')}
        placeholder="0"
        placeholderTextColor={colors.inkSoft}
      />
      <Txt style={{ marginBottom: space.m }}>
        {!inRange ? <Txt style={{ color: colors.red }}>{t('clause.range', { min: money(min), max: money(max) })}</Txt>
          : same ? t('clause.hint')
          : change > 0 ? <>{t('clause.pay')} <Txt variant="number">{money(change)}</Txt></>
          : <>{t('clause.receive')} <Txt variant="number" style={{ color: colors.green }}>{money(-change)}</Txt></>}
        {inRange && !same && after != null ? (
          <Txt variant="small" style={short ? { color: colors.red } : undefined}>{'  ·  '}{t('clause.balanceAfter', { amount: money(after) })}</Txt>
        ) : null}
      </Txt>

      <View style={styles.sliderRow}>
        <Pressable onPress={() => move(-1)} style={styles.step} accessibilityRole="button" accessibilityLabel="−1 %">
          <Txt variant="lead">−</Txt>
        </Pressable>
        <View style={{ flex: 1 }}>
          <RangeSlider single steps={STEPS} low={0} high={pct - CLAUSE_MIN_PCT} label={t('clause.level')}
                       onChange={(_, h) => setPct(CLAUSE_MIN_PCT + h)} />
        </View>
        <Pressable onPress={() => move(1)} style={styles.step} accessibilityRole="button" accessibilityLabel="+1 %">
          <Txt variant="lead">+</Txt>
        </Pressable>
      </View>
      <View style={styles.ends}>
        <Txt variant="small">{CLAUSE_MIN_PCT}{' '}%</Txt>
        <Txt variant="small">{CLAUSE_MAX_PCT}{' '}%</Txt>
      </View>

      <ErrorText error={error} />
      <Button onPress={confirm} busy={busy} disabled={same || short || !inRange} style={{ marginTop: space.l }}
              label={same || !inRange ? t('clause.chooseOther') : change > 0
                ? t('clause.raiseTo', { clause: moneyShort(target), amount: money(change) })
                : t('clause.lowerTo', { clause: moneyShort(target), amount: money(-change) })} />
      <Txt variant="small" style={{ marginTop: space.s }}>
        {t('clause.rule', { base: moneyShort(base) })}
      </Txt>
      <Button label={t('common.cancel')} kind="quiet" onPress={onClose} style={{ marginTop: space.s }} />
    </Sheet>
  );
}

const styles = StyleSheet.create({
  headline: { flexDirection: 'row', alignItems: 'baseline', gap: space.s, marginBottom: space.xs, flexWrap: 'wrap' },
  sliderRow: { flexDirection: 'row', alignItems: 'center', gap: space.s },
  step: {
    width: 36, height: 36, borderRadius: 18, borderWidth: 1.5, borderColor: colors.line, alignItems: 'center',
    justifyContent: 'center', backgroundColor: colors.paper,
  },
  ends: { flexDirection: 'row', justifyContent: 'space-between', marginHorizontal: 44, marginBottom: space.m },
  amount: {
    fontFamily: fonts.number, fontSize: type.title, color: colors.ink, borderBottomWidth: 2,
    borderBottomColor: colors.ink, paddingVertical: space.xs, marginBottom: space.s,
  },
});

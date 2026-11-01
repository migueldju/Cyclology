import { useEffect, useState } from 'react';
import { StyleSheet, TextInput, View } from 'react-native';
import { t } from '../i18n';
import { api } from '../lib/api';
import { money, moneyShort, parseAmount } from '../lib/format';
import { clauseChange, clauseMin } from '../lib/rosterActions';
import type { RosterRow } from '../lib/types';
import { colors, fonts, space, type } from '../theme';
import { Button } from './Button';
import { Sheet } from './Modal';
import { ErrorText } from './Section';
import { Txt } from './Txt';

/**
 * Cambiar la cláusula de uno de mis ciclistas: cualquier cantidad desde el 130 % de su base (lo que pagó o, si es
 * mayor, su valor de mercado), sin máximo. Subir cuesta la mitad de lo que sube; bajar devuelve un cuarto.
 */
export function ClauseSheet({ row, available, visible, onClose, onDone }: {
  row: RosterRow | null; available: number | null | undefined; visible: boolean; onClose: () => void; onDone?: () => void;
}) {
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => { if (visible && row) { setText(String(row.clause)); setError(null); } }, [visible, row]);

  if (!row) return null;
  const min = clauseMin(row);
  const amount = parseAmount(text);
  const valid = amount != null && amount >= min;
  const change = valid ? clauseChange(row.clause, amount) : 0;     // > 0 pago, < 0 me devuelven
  const same = !valid || amount === row.clause;
  const after = available != null ? available - change : null;
  const short = change > 0 && after != null && after < 0;
  const set = (v: number) => setText(String(Math.max(min, Math.round(v / 1000) * 1000)));

  async function confirm() {
    if (!row || !valid || same) return;
    setBusy(true);
    setError(null);
    try {
      await api.setClause(row.ownership_id, amount);
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
      <Txt variant="small">{t('clause.current', { amount: money(row.clause) })}</Txt>
      <TextInput
        value={amount != null ? money(amount).replace(' €', '') : ''}
        onChangeText={setText}
        keyboardType="number-pad"
        style={styles.amount}
        accessibilityLabel={t('sheet.amountLabel')}
        placeholder="0"
        placeholderTextColor={colors.inkSoft}
      />
      <View style={styles.quick}>
        <Button small kind="secondary" label={t('clause.minimum')} onPress={() => set(min)} />
        {[0.1, 0.25, 0.5].map((p) => (
          <Button key={p} small kind="secondary" label={`+${p * 100} %`} onPress={() => set((amount ?? row.clause) * (1 + p))} />
        ))}
      </View>
      <Txt style={{ marginBottom: space.m }}>
        {!valid ? <Txt style={{ color: colors.red }}>{t('sheet.minimum', { amount: money(min) })}</Txt>
          : same ? t('clause.hint')
          : change > 0 ? <>{t('clause.pay')} <Txt variant="number">{money(change)}</Txt></>
          : <>{t('clause.receive')} <Txt variant="number" style={{ color: colors.green }}>{money(-change)}</Txt></>}
        {valid && !same && after != null ? (
          <Txt variant="small" style={short ? { color: colors.red } : undefined}>{'  ·  '}{t('clause.balanceAfter', { amount: money(after) })}</Txt>
        ) : null}
      </Txt>

      <ErrorText error={error} />
      <Button onPress={confirm} busy={busy} disabled={same || short}
              label={same ? t('clause.chooseOther') : change > 0
                ? t('clause.raiseTo', { clause: moneyShort(amount!), amount: money(change) })
                : t('clause.lowerTo', { clause: moneyShort(amount!), amount: money(-change) })} />
      <Txt variant="small" style={{ marginTop: space.s }}>
        {t('clause.rule', { base: moneyShort(Math.max(row.price_paid, row.market_value)) })}
      </Txt>
      <Button label={t('common.cancel')} kind="quiet" onPress={onClose} style={{ marginTop: space.s }} />
    </Sheet>
  );
}

const styles = StyleSheet.create({
  amount: {
    fontFamily: fonts.number, fontSize: type.hero, color: colors.ink, borderBottomWidth: 2,
    borderBottomColor: colors.ink, paddingVertical: space.s, marginBottom: space.m,
  },
  quick: { flexDirection: 'row', gap: space.s, marginBottom: space.m, flexWrap: 'wrap' },
});

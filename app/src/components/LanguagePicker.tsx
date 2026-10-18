import { Pressable, StyleSheet, View } from 'react-native';
import Svg, { Path, Rect } from 'react-native-svg';
import type { Lang } from '../i18n';
import { colors, fonts, space, type } from '../theme';
import { Flag } from './Flag';
import { Txt } from './Txt';

// Bandera de cada idioma: la del país; el árabe, la de Arabia Saudí. Catalán, euskera y gallego, dibujadas aquí
// (flagcdn.com no tiene las de las comunidades)
const COUNTRY: Partial<Record<Lang, string>> = {
  es: 'es', fr: 'fr', pt: 'pt', it: 'it', nl: 'nl', de: 'de', pl: 'pl', ru: 'ru', ar: 'sa', ja: 'jp', da: 'dk',
  sl: 'si', cs: 'cz',
};

const H = 14;            // alto de la bandera (caja 3:2, como Flag)
const W = H * 1.5;

function RegionFlag({ lang }: { lang: Lang }) {
  return (
    <Svg width={W} height={H} viewBox="0 0 18 12">
      {lang === 'ca' ? (
        // senyera: cuatro barras rojas sobre amarillo
        <>
          <Rect width={18} height={12} fill="#FCDD09" />
          {[1, 3, 5, 7].map((i) => <Rect key={i} y={(i * 12) / 9} width={18} height={12 / 9} fill="#DA121A" />)}
        </>
      ) : lang === 'eu' ? (
        // ikurriña: aspa verde y cruz blanca sobre rojo
        <>
          <Rect width={18} height={12} fill="#D52B1E" />
          <Path d="M0 0 L18 12 M18 0 L0 12" stroke="#009B48" strokeWidth={2} />
          <Path d="M9 0 V12 M0 6 H18" stroke="#FFFFFF" strokeWidth={1.6} />
        </>
      ) : (
        // gallega: banda azul en diagonal sobre blanco
        <>
          <Rect width={18} height={12} fill="#FFFFFF" />
          <Path d="M0 0 L18 12" stroke="#0099CC" strokeWidth={2.4} />
          <Rect width={18} height={12} fill="none" stroke={colors.line} strokeWidth={0.5} />
        </>
      )}
    </Svg>
  );
}

export function LangFlag({ lang }: { lang: Lang }) {
  const cc = COUNTRY[lang];
  return cc ? <Flag code={cc} height={H} /> : <RegionFlag lang={lang} />;
}

/** Elección del idioma: botones con la bandera y el nombre de cada idioma */
export function LanguagePicker({ label, languages, value, onChange }: {
  label: string; languages: { code: Lang; name: string }[]; value: Lang; onChange: (l: Lang) => void;
}) {
  return (
    <View style={{ marginBottom: space.l }}>
      <Txt variant="label" style={{ marginBottom: 6 }}>{label}</Txt>
      <View style={styles.grid}>
        {languages.map((l) => {
          const on = l.code === value;
          return (
            <Pressable key={l.code} onPress={() => onChange(l.code)} accessibilityRole="radio"
                       accessibilityState={{ selected: on }}
                       style={({ pressed }) => [styles.chip, on && styles.chipOn, pressed && !on && { backgroundColor: colors.road }]}>
              <View style={styles.flag}><LangFlag lang={l.code} /></View>
              <Txt style={[styles.name, on && styles.nameOn]} numberOfLines={1}>{l.name}</Txt>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: space.s },
  chip: {
    flexDirection: 'row', alignItems: 'center', gap: space.s, paddingHorizontal: space.m, paddingVertical: 8,
    borderRadius: 18, borderWidth: 1.5, borderColor: colors.line, backgroundColor: colors.paper,
  },
  chipOn: { borderColor: colors.jersey, backgroundColor: colors.asphalt },
  flag: { borderRadius: 2, overflow: 'hidden' },
  name: { fontFamily: fonts.bodyMedium, fontSize: type.small, color: colors.ink, letterSpacing: 0.2 },
  nameOn: { color: colors.paper },
});

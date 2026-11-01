import { useEffect, useId, useState } from 'react';
import { View } from 'react-native';
import Svg, { ClipPath, Defs, G, Image as SvgImage, Path, Rect } from 'react-native-svg';
import { api } from '../lib/api';
import { t } from '../i18n';

export interface Title { rider_id: number; level: 'nc' | 'cc' | 'wc'; discipline: 'rr' | 'itt'; scope: string }

// Títulos vigentes (fecha del juego): se piden una vez y se comparten entre todas las filas
let cache: Promise<Map<number, Title[]>> | null = null;
function loadTitles() {
  if (!cache) {
    cache = api.titles().then((list) => {
      const m = new Map<number, Title[]>();
      list.forEach((x) => m.set(x.rider_id, [...(m.get(x.rider_id) ?? []), x]));
      return m;
    }).catch(() => { cache = null; return new Map(); });
  }
  return cache;
}

const ORDER = { wc: 0, cc: 1, nc: 2 } as const;
export function useRiderTitles(riderId: number | null | undefined): Title[] {
  const [titles, setTitles] = useState<Title[]>([]);
  useEffect(() => {
    if (riderId == null) return;
    let alive = true;
    loadTitles().then((m) => {
      if (!alive) return;
      const list = [...(m.get(riderId) ?? [])];
      // el más importante primero: mundial, continental, nacional; ruta antes que contrarreloj
      list.sort((a, b) => ORDER[a.level] - ORDER[b.level] || (a.discipline === 'rr' ? -1 : 1));
      setTitles(list);
    });
    return () => { alive = false; };
  }, [riderId]);
  return titles;
}

// Silueta del maillot (la misma que PositionJersey), en una caja de 40×40
const JERSEY = 'M14 4 L8 6 L2 13 L7 18 L10 15 L10 37 L30 37 L30 15 L33 18 L38 13 L32 6 L26 4 Q20 9 14 4 Z';
const STAR = 'M20 15 L21.8 19.6 L26.7 19.9 L22.9 23 L24.1 27.8 L20 25.1 L15.9 27.8 L17.1 23 L13.3 19.9 L18.2 19.6 Z';
const RAINBOW = ['#0081C8', '#EE334E', '#111111', '#FCB131', '#00A651'];

export function titleLabel(x: Title): string {
  const what = x.level === 'wc' ? t('title.world') : x.level === 'cc'
    ? t('title.continental', { scope: t(`title.continent.${x.scope}` as 'title.continent.europe') }) : t('title.national');
  return x.discipline === 'itt' ? `${what} · ${t('title.itt')}` : what;
}

/** Maillot de campeón: nacional (con la bandera), continental (Europa, azul con estrella) o del mundo (arcoíris) */
export function ChampionJersey({ title, size = 16 }: { title: Title; size?: number }) {
  const id = `j${useId().replace(/[^a-zA-Z0-9]/g, '')}`;
  return (
    <View accessible accessibilityLabel={titleLabel(title)} style={{ width: size, height: size }}>
      <Svg width={size} height={size} viewBox="0 0 40 40">
        <Defs><ClipPath id={id}><Path d={JERSEY} /></ClipPath></Defs>
        <G clipPath={`url(#${id})`}>
          {title.level === 'nc' ? (
            <SvgImage href={{ uri: `https://flagcdn.com/w80/${title.scope}.png` }} x={0} y={4} width={40} height={34}
                      preserveAspectRatio="xMidYMid slice" />
          ) : title.level === 'wc' ? (
            <>
              <Rect width={40} height={40} fill="#FFFFFF" />
              {RAINBOW.map((c, i) => <Rect key={c} y={16 + i * 2.6} width={40} height={2.6} fill={c} />)}
            </>
          ) : (
            <>
              <Rect width={40} height={40} fill={title.scope === 'europe' ? '#003399' : '#1E272C'} />
              <Path d={STAR} fill="#FFCC00" />
            </>
          )}
        </G>
        <Path d={JERSEY} fill="none" stroke="#5E6B71" strokeWidth={2} strokeLinejoin="round" />
        {/* contrarreloj: un cronómetro pequeño en la esquina */}
        {title.discipline === 'itt' ? (
          <>
            <Path d="M33 26 m-6 0 a6 6 0 1 0 12 0 a6 6 0 1 0 -12 0" fill="#FFFFFF" stroke="#1E272C" strokeWidth={1.8} />
            <Path d="M33 22.5 L33 26 L35.5 27.5" stroke="#1E272C" strokeWidth={1.8} fill="none" strokeLinecap="round" />
          </>
        ) : null}
      </Svg>
    </View>
  );
}

/** Los maillots de campeón de un ciclista (si tiene alguno), para poner junto a su bandera */
export function ChampionBadges({ riderId, size }: { riderId: number | null | undefined; size?: number }) {
  const titles = useRiderTitles(riderId);
  if (!titles.length) return null;
  return (
    <View style={{ flexDirection: 'row', gap: 2, alignItems: 'center' }}>
      {titles.map((x) => <ChampionJersey key={`${x.level}-${x.discipline}-${x.scope}`} title={x} size={size} />)}
    </View>
  );
}

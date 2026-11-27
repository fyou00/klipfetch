import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const assetsFontsDir = path.join(root, 'assets', 'fonts');
const fontsDir = fs.existsSync(assetsFontsDir)
  ? assetsFontsDir
  : path.join(root, 'design', 'fonts');
const rendersDir = path.join(root, 'design', 'renders');
const seoulPhotoPath = path.join(root, 'design', 'assets', 'seoul_golden_hour.jpg');

const cmds = [];
let seq = 0;

function nextId(prefix) {
  seq += 1;
  return `${prefix}_${seq}`;
}

function cmd(command, params, as) {
  const step = { command, params };
  if (as) step.as = as;
  cmds.push(step);
  return as ? { $ref: as } : undefined;
}

// ---------------------------------------------------------------------------
// 1. Load custom SIL OFL fonts into headless session
// ---------------------------------------------------------------------------
for (const file of [
  'BricolageGrotesque[opsz,wdth,wght].ttf',
  'IBMPlexSans[wdth,wght].ttf',
  'IBMPlexSans-Regular.ttf',
  'IBMPlexSans-SemiBold.ttf',
  'IBMPlexMono-Regular.ttf',
]) {
  const fontPath = path.join(fontsDir, file);
  if (fs.existsSync(fontPath)) {
    cmd('text.loadFont', { path: fontPath });
  }
}

// ---------------------------------------------------------------------------
// 2. Design Tokens (Variables + Text Styles)
// Strict 3-weight system (F19): 400 (IBM Plex Sans / Mono), 600 (IBM Plex Sans), 800 (Bricolage)
// ---------------------------------------------------------------------------
const COLORS = {
  'color/paper': '#F5F2EC',
  'color/paper-elevated': '#FFFCF7',
  'color/paper-well': '#ECE7DD',
  'color/paper-pressed': '#E2DBD0',
  'color/ink': '#1A1715',
  'color/ink-secondary': '#4A433C',
  'color/ink-muted': '#6B635B',
  'color/rule': '#D8D0C4',
  'color/rule-strong': '#877D71',
  'color/accent': '#BF3909',
  'color/accent-ink': '#FFFDF9',
  'color/accent-well': '#F8E5DC',
  'color/accent-deep': '#7D2605',
  'color/focus': '#BF3909',
  'color/status-ok': '#166835',
  'color/status-ok-well': '#E4F2E8',
  'color/status-warn': '#8C5200',
  'color/status-warn-well': '#FAF0DA',
  'color/status-error': '#B81D1D',
  'color/status-error-well': '#FBE8E8',
  'color/status-error-rule': '#DFB2B2',
  'color/platform-tiktok': '#006B72',
  'color/platform-instagram': '#B31E52',
  'color/platform-youtube': '#C41E1E',
};

const NUMBERS = {
  'space/xs': 8,
  'space/sm': 12,
  'space/md': 16,
  'space/lg': 24,
  'radius/tag': 2,
  'radius/control': 4,
  'radius/dialog': 6,
  'rule/hair': 1,
  'rule/heavy': 2,
};

const colRef = cmd(
  'variable.createCollection',
  { name: 'KlipFetch Tokens', modes: ['Light'] },
  'tokCol'
);

for (const [name, value] of Object.entries(COLORS)) {
  cmd('variable.create', {
    collection: colRef,
    name,
    type: 'color',
    value,
  });
}

for (const [name, value] of Object.entries(NUMBERS)) {
  cmd('variable.create', {
    collection: colRef,
    name,
    type: 'number',
    value,
  });
}

const TEXT_STYLES = [
  {
    name: 'Display/Wordmark',
    value: {
      fontFamily: 'Bricolage Grotesque',
      fontSize: 26,
      lineHeight: 28,
      letterSpacing: -0.4,
      fontVariations: { wdth: 75, wght: 800, opsz: 96 },
    },
  },
  {
    name: 'Display/MediaTitle',
    value: {
      fontFamily: 'Bricolage Grotesque',
      fontSize: 20,
      lineHeight: 24,
      letterSpacing: -0.2,
      fontVariations: { wdth: 85, wght: 800, opsz: 48 },
    },
  },
  {
    name: 'UI/RowTitle',
    value: {
      fontFamily: 'IBM Plex Sans',
      fontSize: 15,
      lineHeight: 20,
      fontVariations: { wght: 600, wdth: 100 },
    },
  },
  {
    name: 'UI/Body',
    value: {
      fontFamily: 'IBM Plex Sans',
      fontSize: 14,
      lineHeight: 20,
      fontVariations: { wght: 400, wdth: 100 },
    },
  },
  {
    name: 'UI/Control',
    value: {
      fontFamily: 'IBM Plex Sans',
      fontSize: 13,
      lineHeight: 18,
      fontVariations: { wght: 600, wdth: 100 },
    },
  },
  {
    name: 'UI/Caption',
    value: {
      fontFamily: 'IBM Plex Sans',
      fontSize: 12,
      lineHeight: 16,
      fontVariations: { wght: 400, wdth: 100 },
    },
  },
  {
    name: 'Tech/Mono',
    value: {
      fontFamily: 'IBM Plex Mono',
      fontStyle: 'Regular',
      fontSize: 12,
      lineHeight: 16,
    },
  },
];

for (const st of TEXT_STYLES) {
  cmd('style.create', { type: 'text', name: st.name, value: st.value });
}

// ---------------------------------------------------------------------------
// 3. Primitives & Component Builders
// ---------------------------------------------------------------------------
function tok(name) {
  if (!COLORS[name] && NUMBERS[name] === undefined) {
    throw new Error(`Unknown token referenced: ${name}`);
  }
  return { $var: name };
}

function frame(parent, opts) {
  const as = opts.as || nextId('fr');
  const props = { fill: 'none', ...(opts.props || {}) };
  return cmd(
    'node.create',
    {
      type: 'frame',
      parent,
      x: opts.x ?? 0,
      y: opts.y ?? 0,
      width: opts.width,
      height: opts.height,
      name: opts.name,
      props,
      select: false,
    },
    as
  );
}

function rect(parent, opts) {
  const as = opts.as || nextId('rc');
  return cmd(
    'node.create',
    {
      type: 'rectangle',
      parent,
      x: opts.x ?? 0,
      y: opts.y ?? 0,
      width: opts.width ?? 100,
      height: opts.height ?? 10,
      name: opts.name || 'Rect',
      props: opts.props || {},
      select: false,
    },
    as
  );
}

function ellipse(parent, opts) {
  const as = opts.as || nextId('el');
  return cmd(
    'node.create',
    {
      type: 'ellipse',
      parent,
      x: opts.x ?? 0,
      y: opts.y ?? 0,
      width: opts.width ?? 24,
      height: opts.height ?? 24,
      name: opts.name || 'Ellipse',
      props: opts.props || {},
      select: false,
    },
    as
  );
}

function vec(parent, opts) {
  const as = opts.as || nextId('vc');
  return cmd(
    'vector.create',
    {
      parent,
      path: opts.path,
      closed: opts.closed ?? true,
      x: opts.x ?? 0,
      y: opts.y ?? 0,
      width: opts.width,
      height: opts.height,
      name: opts.name || 'Vector',
      props: opts.props || {},
      select: false,
    },
    as
  );
}

function txt(parent, content, opts = {}) {
  const as = opts.as || nextId('tx');
  const family = opts.family || 'IBM Plex Sans';
  // Enforce strictly 3 weights (400, 600, 800) across the entire system
  const requestedWeight = opts.wght ?? (family === 'Bricolage Grotesque' ? 800 : 400);
  const normalizedWeight =
    family === 'Bricolage Grotesque'
      ? 800
      : family === 'IBM Plex Mono'
      ? 400
      : requestedWeight >= 550
      ? 600
      : 400;

  const props = {
    fontFamily: family,
    fontSize: opts.size ?? 14,
    fill: opts.fill ?? tok('color/ink'),
    textAutoResize: opts.autoResize ?? (opts.width ? 'height' : 'widthAndHeight'),
    ...(opts.lineHeight ? { lineHeight: opts.lineHeight } : {}),
    ...(opts.letterSpacing !== undefined ? { letterSpacing: opts.letterSpacing } : {}),
    ...(opts.align ? { textAlign: opts.align } : {}),
    ...(opts.maxLines ? { maxLines: opts.maxLines } : {}),
    ...(opts.opacity !== undefined ? { opacity: opts.opacity } : {}),
    ...(opts.sizingH ? { sizingH: opts.sizingH } : {}),
    ...(opts.sizingV ? { sizingV: opts.sizingV } : {}),
    ...(opts.features ? { features: opts.features } : {}),
  };

  if (family === 'Bricolage Grotesque') {
    props.fontVariations = {
      wdth: opts.wdth ?? 75,
      wght: normalizedWeight,
      opsz: opts.opsz ?? 96,
    };
  } else if (family === 'IBM Plex Sans') {
    props.fontVariations = {
      wght: normalizedWeight,
      wdth: opts.wdth ?? 100,
    };
  } else if (family === 'IBM Plex Mono') {
    props.fontStyle = 'Regular';
  }

  return cmd(
    'text.create',
    {
      parent,
      text: content,
      x: opts.x ?? 0,
      y: opts.y ?? 0,
      ...(opts.width ? { width: opts.width } : {}),
      name: opts.name || content.slice(0, 32),
      props,
      select: false,
    },
    as
  );
}

function divider(parent, height = 1, color = tok('color/rule'), name = 'Divider') {
  return rect(parent, {
    width: 100,
    height,
    name,
    props: { fill: color, sizingH: 'fill', sizingV: 'fixed' },
  });
}

// Simple crisp vector icons (zero emoji)
const ICONS = {
  home: 'M 2 8 L 9 2 L 16 8 V 16 H 11 V 11 H 7 V 16 H 2 Z',
  download: 'M 8 2 H 10 V 10.5 L 13 7.5 L 14.4 8.9 L 9 14.3 L 3.6 8.9 L 5 7.5 L 8 10.5 Z M 3 15.5 H 15 V 17 H 3 Z',
  settings: 'M 7.5 1.5 H 10.5 L 11 3.7 L 13 4.5 L 14.9 3.3 L 16.7 5.1 L 15.5 7 L 16.3 9 L 18.5 9.5 V 12.5 L 16.3 13 L 15.5 15 L 16.7 16.9 L 14.9 18.7 L 13 17.5 L 11 18.3 L 10.5 20.5 H 7.5 L 7 18.3 L 5 17.5 L 3.1 18.7 L 1.3 16.9 L 2.5 15 L 1.7 13 L -0.5 12.5 V 9.5 L 1.7 9 L 2.5 7 L 1.3 5.1 L 3.1 3.3 L 5 4.5 L 7 3.7 Z M 9 7.8 A 3.2 3.2 0 1 0 9 14.2 A 3.2 3.2 0 1 0 9 7.8 Z',
  link: 'M 7 12 H 4.5 A 3.5 3.5 0 0 1 4.5 5 H 7 V 6.8 H 4.5 A 1.7 1.7 0 0 0 4.5 10.2 H 7 Z M 11 5 H 13.5 A 3.5 3.5 0 0 1 13.5 12 H 11 V 10.2 H 13.5 A 1.7 1.7 0 0 0 13.5 6.8 H 11 Z M 5.8 7.7 H 12.2 V 9.3 H 5.8 Z',
  paste: 'M 5 3 H 13 V 5 H 15 V 16 H 3 V 5 H 5 Z M 6.5 2.5 H 11.5 V 4.5 H 6.5 Z M 5 6.5 V 14.2 H 13 V 6.5 H 11.8 V 7.5 H 6.2 V 6.5 Z',
  search: 'M 7.5 2 A 5.5 5.5 0 1 1 7.49 2 Z M 7.5 3.8 A 3.7 3.7 0 1 0 7.5 11.2 A 3.7 3.7 0 1 0 7.5 3.8 Z M 11.8 10.6 L 16 14.8 L 14.7 16.1 L 10.5 11.9 Z',
  clear: 'M 4.2 3 L 9 7.8 L 13.8 3 L 15 4.2 L 10.2 9 L 15 13.8 L 13.8 15 L 9 10.2 L 4.2 15 L 3 13.8 L 7.8 9 L 3 4.2 Z',
  back: 'M 14 8.2 H 5.4 L 9.2 4.4 L 8 3.2 L 2.2 9 L 8 14.8 L 9.2 13.6 L 5.4 9.8 H 14 Z',
  chevron: 'M 6 3.5 L 11.5 9 L 6 14.5 L 4.8 13.3 L 9.1 9 L 4.8 4.7 Z',
  lock: 'M 5 8 V 6 A 4 4 0 0 1 13 6 V 8 H 14.5 V 16 H 3.5 V 8 Z M 6.8 8 H 11.2 V 6 A 2.2 2.2 0 0 0 6.8 6 Z',
  check: 'M 3.2 8.8 L 7 12.6 L 14.8 4.8 L 16 6 L 7 15 L 2 10 Z',
  shield: 'M 9 1.5 L 15.5 4.2 V 8.8 C 15.5 12.8 12.7 15.7 9 16.8 C 5.3 15.7 2.5 12.8 2.5 8.8 V 4.2 Z M 9 3.4 L 4.3 5.4 V 8.8 C 4.3 11.8 6.3 14.1 9 15 C 11.7 14.1 13.7 11.8 13.7 8.8 V 5.4 Z',
  refresh: 'M 14.5 8.5 A 5.5 5.5 0 1 1 13 4.7 L 11 4.7 V 6.4 H 16 V 1.4 H 14.3 V 3.4 A 7.3 7.3 0 1 0 16.2 8.5 Z',
  trash: 'M 6 2.5 H 12 V 4 H 15.5 V 5.6 H 2.5 V 4 H 6 Z M 4.2 6.8 H 13.8 L 13 15.8 H 5 Z',
  alert: 'M 9 1.8 L 16.5 15 H 1.5 Z M 8.1 6.5 V 10.6 H 9.9 V 6.5 Z M 8.1 11.9 V 13.7 H 9.9 V 11.9 Z',
  key: 'M 6.5 5 A 3.5 3.5 0 1 0 9.8 9.6 H 16 V 8 H 14.2 V 6.2 H 12.4 V 8 H 9.8 A 3.5 3.5 0 0 0 6.5 5 Z M 6.5 6.8 A 1.7 1.7 0 1 1 6.49 6.8 Z',
};

function icon(parent, key, size = 16, fill = tok('color/ink'), name) {
  return vec(parent, {
    path: ICONS[key],
    closed: true,
    width: size,
    height: size,
    name: name || `Icon/${key}`,
    props: { fill, sizingH: 'fixed', sizingV: 'fixed' },
  });
}

function platformMarker(parent, platform, colorVar, compact = false) {
  const row = frame(parent, {
    width: 80,
    height: compact ? 18 : 20,
    name: `Platform/${platform}`,
    props: {
      layout: 'horizontal',
      gap: 6,
      crossAlign: 'center',
      sizingH: 'hug',
      sizingV: 'hug',
    },
  });
  rect(row, {
    width: 3,
    height: compact ? 12 : 14,
    name: 'Bar',
    props: { fill: tok(colorVar), cornerRadius: 1, sizingH: 'fixed', sizingV: 'fixed' },
  });
  txt(row, platform, {
    size: compact ? 12 : 13,
    wght: 600,
    fill: tok('color/ink'),
  });
  return row;
}

function squareTag(parent, label, fillVar, inkVar, borderVar = null, mono = false) {
  const f = frame(parent, {
    width: 60,
    height: 22,
    name: `Tag/${label}`,
    props: {
      fill: tok(fillVar),
      ...(borderVar ? { stroke: tok(borderVar), strokeWeight: 1, strokeAlign: 'inside' } : {}),
      cornerRadius: 2,
      layout: 'horizontal',
      padding: [3, 7, 3, 7],
      crossAlign: 'center',
      sizingH: 'hug',
      sizingV: 'hug',
    },
  });
  txt(f, label, {
    family: mono ? 'IBM Plex Mono' : 'IBM Plex Sans',
    size: 11,
    wght: mono ? 400 : 600,
    fill: tok(inkVar),
  });
  return f;
}

// Single Primary Filled Recipe (#BF3909 terracotta); secondaries are Ink-Outlined or Ghost; Disabled uses high-contrast #ECE7DD/#6B635B
function button(parent, label, variant = 'primary', opts = {}) {
  const h = opts.height ?? (variant === 'primary' ? 48 : 34);
  const padH = opts.padH ?? (variant === 'primary' ? 18 : 12);
  const isDisabled = opts.disabled === true;

  const fill = isDisabled
    ? tok('color/paper-well')
    : variant === 'primary'
    ? tok('color/accent')
    : variant === 'outlined' || variant === 'outlinedInk' || variant === 'outlinedDanger' || variant === 'outlinedMuted'
    ? tok('color/paper-elevated')
    : 'none';

  const textColor = isDisabled
    ? tok('color/ink-muted')
    : variant === 'primary'
    ? tok('color/accent-ink')
    : variant === 'outlinedDanger' || variant === 'ghostDanger'
    ? tok('color/status-error')
    : variant === 'ghostMuted'
    ? tok('color/ink-secondary')
    : tok('color/ink');

  const strokeProps = isDisabled
    ? { stroke: tok('color/rule'), strokeWeight: 1, strokeAlign: 'inside' }
    : variant === 'outlined'
    ? { stroke: tok('color/rule-strong'), strokeWeight: 1, strokeAlign: 'inside' }
    : variant === 'outlinedInk'
    ? { stroke: tok('color/ink'), strokeWeight: 1, strokeAlign: 'inside' }
    : variant === 'outlinedDanger'
    ? { stroke: tok('color/status-error'), strokeWeight: 1, strokeAlign: 'inside' }
    : variant === 'outlinedMuted'
    ? { stroke: tok('color/rule'), strokeWeight: 1, strokeAlign: 'inside' }
    : {};

  const btn = frame(parent, {
    width: opts.width ?? 120,
    height: h,
    name: `Button/${label}`,
    props: {
      fill,
      ...strokeProps,
      cornerRadius: 4,
      layout: 'horizontal',
      gap: 8,
      padding: [0, padH, 0, padH],
      mainAlign: 'center',
      crossAlign: 'center',
      sizingH: opts.fillWidth ? 'fill' : 'hug',
      sizingV: 'fixed',
    },
  });
  if (opts.icon) {
    icon(btn, opts.icon, 15, textColor);
  }
  txt(btn, label, {
    size: opts.fontSize ?? (variant === 'primary' ? 14 : 12.5),
    wght: 600,
    fill: textColor,
  });
  return btn;
}

function toggleSwitch(parent, on = false) {
  const track = frame(parent, {
    width: 42,
    height: 24,
    name: on ? 'Switch/On' : 'Switch/Off',
    props: {
      fill: on ? tok('color/accent') : tok('color/paper-well'),
      ...(on ? {} : { stroke: tok('color/rule-strong'), strokeWeight: 1, strokeAlign: 'inside' }),
      cornerRadius: 4,
      padding: 3,
      layout: 'horizontal',
      mainAlign: on ? 'max' : 'min',
      crossAlign: 'center',
      sizingH: 'fixed',
      sizingV: 'fixed',
    },
  });
  rect(track, {
    width: 18,
    height: 18,
    name: 'Thumb',
    props: {
      fill: on ? tok('color/accent-ink') : tok('color/ink-muted'),
      cornerRadius: 2,
      sizingH: 'fixed',
      sizingV: 'fixed',
    },
  });
  return track;
}

// Authentic Android AOSP Status Bar (36px: 12:30 left, Wi-Fi + Signal triangle + vertical battery right)
function statusBar(parent, fillVar = 'color/paper') {
  const bar = frame(parent, {
    width: 412,
    height: 36,
    name: 'AndroidStatusBar',
    props: {
      fill: typeof fillVar === 'string' && fillVar.startsWith('#') ? fillVar : tok(fillVar),
      layout: 'horizontal',
      padding: [0, 20, 0, 20],
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  txt(bar, '12:30', { size: 13, wght: 600, fill: tok('color/ink'), features: { tnum: true } });

  const right = frame(bar, {
    width: 58,
    height: 14,
    name: 'AndroidSysIcons',
    props: {
      layout: 'horizontal',
      gap: 7,
      crossAlign: 'center',
      sizingH: 'hug',
      sizingV: 'hug',
    },
  });
  // Android Wi-Fi fan wedge
  vec(right, {
    path: 'M 7.5 11.5 L 0.5 3.6 C 2.4 1.9 4.8 1 7.5 1 C 10.2 1 12.6 1.9 14.5 3.6 Z',
    width: 14,
    height: 11,
    name: 'Wifi',
    props: { fill: tok('color/ink') },
  });
  // Android solid cellular signal triangle
  vec(right, {
    path: 'M 11 0 L 0 11 H 11 Z',
    width: 11,
    height: 11,
    name: 'Cellular',
    props: { fill: tok('color/ink') },
  });
  // Android vertical battery
  const batWrap = frame(right, {
    width: 9,
    height: 13,
    name: 'AndroidBattery',
    props: { layout: 'vertical', crossAlign: 'center', gap: 0, sizingH: 'fixed', sizingV: 'fixed' },
  });
  rect(batWrap, {
    width: 4,
    height: 2,
    name: 'Cap',
    props: { fill: tok('color/ink'), sizingH: 'fixed', sizingV: 'fixed' },
  });
  rect(batWrap, {
    width: 9,
    height: 11,
    name: 'Cell',
    props: { fill: tok('color/ink'), cornerRadius: 1, sizingH: 'fixed', sizingV: 'fixed' },
  });
  return bar;
}

// Editorial Bottom Navigation Bar (68px; Downloads count badge placed beside icon with clean 6px clearance)
function bottomNav(parent, activeIndex = 0, activeCount = 2) {
  const nav = frame(parent, {
    width: 412,
    height: 68,
    name: 'BottomNavigation',
    props: {
      fill: tok('color/paper-elevated'),
      stroke: tok('color/rule'),
      strokeTopWeight: 1,
      strokeBottomWeight: 0,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      layout: 'horizontal',
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });

  const tabs = [
    { label: 'Home', iconKey: 'home' },
    { label: 'Downloads', iconKey: 'download', count: activeCount },
    { label: 'Settings', iconKey: 'settings' },
  ];

  for (let i = 0; i < tabs.length; i += 1) {
    const t = tabs[i];
    const isActive = i === activeIndex;
    const item = frame(nav, {
      width: 137,
      height: 68,
      name: `Tab/${t.label}`,
      props: {
        layout: 'vertical',
        padding: [0, 8, 10, 8],
        mainAlign: 'spaceBetween',
        crossAlign: 'center',
        sizingH: 'fill',
        sizingV: 'fixed',
      },
    });
    rect(item, {
      width: 56,
      height: 2,
      name: 'ActiveRule',
      props: {
        fill: isActive ? tok('color/accent') : 'none',
        sizingH: 'fixed',
        sizingV: 'fixed',
      },
    });

    const iconWrap = frame(item, {
      width: 60,
      height: 24,
      name: 'IconSlot',
      props: {
        layout: 'horizontal',
        mainAlign: 'center',
        crossAlign: 'center',
        gap: 6,
        sizingH: 'hug',
        sizingV: 'fixed',
      },
    });
    icon(
      iconWrap,
      t.iconKey,
      18,
      isActive ? tok('color/accent') : tok('color/ink-muted'),
      `Icon/${t.iconKey}`
    );
    if (t.count && t.count > 0) {
      const badge = frame(iconWrap, {
        width: 18,
        height: 16,
        name: 'QueueCountBadge',
        props: {
          fill: tok('color/accent'),
          cornerRadius: 2,
          padding: [1, 5, 1, 5],
          mainAlign: 'center',
          crossAlign: 'center',
          layout: 'horizontal',
          sizingH: 'hug',
          sizingV: 'hug',
        },
      });
      txt(badge, String(t.count), {
        family: 'IBM Plex Mono',
        size: 10,
        wght: 400,
        fill: tok('color/accent-ink'),
      });
    }

    txt(item, t.label, {
      size: 12,
      wght: isActive ? 600 : 400,
      fill: isActive ? tok('color/ink') : tok('color/ink-muted'),
    });
  }
  return nav;
}

// Geometric Brand Mark strictly inside 108dp adaptive safe-zone (x: 31..77, y: 31..77 -> r <= 32.5dp < 33dp!)
// True 45-degree parallel upper arm & fetch leg; crisp 5dp baseline gap so 24px never blurs shut; clip: false (no redundant clip-path in XML).
function drawBrandMark(parent, size = 108, opts = {}) {
  const mono = opts.mono ?? false;
  const fgPrimary = opts.primaryColor || tok('color/paper-elevated');
  const fgAccent = mono ? fgPrimary : opts.accentColor || tok('color/accent');
  const s = size / 108;

  const g = frame(parent, {
    width: size,
    height: size,
    name: opts.name || 'KlipFetch Icon Vector',
    as: opts.as,
    props: { fill: 'none', clip: false, sizingH: 'fixed', sizingV: 'fixed' },
  });

  // 1. Left vertical K-spine (x: 31..43, y: 31..77)
  vec(g, {
    path: 'M 0 0 H 12 V 46 H 0 Z',
    x: 31 * s,
    y: 31 * s,
    width: 12 * s,
    height: 46 * s,
    name: 'Spine',
    props: { fill: fgPrimary },
  });

  // 2. Upper diagonal K-arm (exact 45-degree parallel: (60,31)->(43,48) and (74,31)->(43,62))
  vec(g, {
    path: 'M 17 0 H 31 L 0 31 V 17 Z',
    x: 43 * s,
    y: 31 * s,
    width: 31 * s,
    height: 31 * s,
    name: 'UpperArm',
    props: { fill: fgPrimary },
  });

  // 3. Lower terracotta fetch leg (exact 45-degree parallel: (52,55)->(66,55)->(77,66)->(63,66))
  vec(g, {
    path: 'M 0 0 H 14 L 25 11 H 11 Z',
    x: 52 * s,
    y: 55 * s,
    width: 25 * s,
    height: 11 * s,
    name: 'FetchStroke',
    props: { fill: fgAccent },
  });

  // 4. Precision extraction baseline (5dp open gap y: 66..71, bar y: 71..77)
  vec(g, {
    path: 'M 0 0 H 30 V 6 H 0 Z',
    x: 47 * s,
    y: 71 * s,
    width: 30 * s,
    height: 6 * s,
    name: 'FetchBaseline',
    props: { fill: fgAccent },
  });

  return g;
}

// ===========================================================================
// PAGE 1: 01 · Design System & Brand
// ===========================================================================
cmd('page.rename', { name: '01 · Design System & Brand' });
cmd('page.setBackground', { color: '#DDD6CB' });

// --- Frame 1: Color & Surface Ladder (960 x 720) ---
const fColor = frame(undefined, {
  as: 'sysColorFrame',
  x: 0,
  y: 0,
  width: 960,
  height: 760,
  name: '01 · Color & Surface Ladder',
  props: {
    fill: tok('color/paper'),
    layout: 'vertical',
    padding: 36,
    gap: 24,
    clip: true,
  },
});

const cHeader = frame(fColor, {
  width: 888,
  height: 68,
  name: 'Header',
  props: {
    layout: 'vertical',
    padding: [0, 0, 12, 0],
    gap: 4,
    sizingH: 'fill',
    sizingV: 'hug',
  },
});
txt(cHeader, 'KlipFetch Color & Surface Ladder', {
  family: 'Bricolage Grotesque',
  size: 28,
  wdth: 75,
  wght: 800,
  letterSpacing: -0.4,
});
txt(cHeader, 'Editorial app scope, Light Mode locked, terracotta accent strictly under 5%', {
  family: 'IBM Plex Mono',
  size: 12,
  fill: tok('color/ink-muted'),
});
divider(fColor, 2, tok('color/ink'), 'HeaderRule');

const cBody = frame(fColor, {
  width: 888,
  height: 540,
  name: 'Columns',
  props: {
    layout: 'horizontal',
    gap: 32,
    sizingH: 'fill',
    sizingV: 'fill',
  },
});

const cLeft = frame(cBody, {
  width: 440,
  height: 540,
  name: 'Swatches',
  props: { layout: 'vertical', gap: 16, sizingH: 'fill', sizingV: 'hug' },
});

function swatchGroup(parent, title, items) {
  const grp = frame(parent, {
    width: 440,
    height: 100,
    name: `Group/${title}`,
    props: { layout: 'vertical', gap: 8, sizingH: 'fill', sizingV: 'hug' },
  });
  txt(grp, title, { size: 13, wght: 600, fill: tok('color/ink') });
  const grid = frame(grp, {
    width: 440,
    height: 70,
    name: 'Grid',
    props: {
      layout: 'horizontal',
      wrap: true,
      gap: 10,
      crossGap: 10,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  for (const item of items) {
    const cell = frame(grid, {
      width: 136,
      height: 52,
      name: item.name,
      props: {
        fill: tok('color/paper-elevated'),
        stroke: tok('color/rule'),
        strokeWeight: 1,
        strokeAlign: 'inside',
        cornerRadius: 4,
        layout: 'horizontal',
        gap: 8,
        padding: 8,
        crossAlign: 'center',
        sizingH: 'fixed',
        sizingV: 'fixed',
      },
    });
    rect(cell, {
      width: 32,
      height: 34,
      name: 'Chip',
      props: {
        fill: tok(item.varName),
        stroke: tok('color/rule'),
        strokeWeight: 1,
        cornerRadius: 2,
        sizingH: 'fixed',
        sizingV: 'fixed',
      },
    });
    const meta = frame(cell, {
      width: 80,
      height: 34,
      name: 'Meta',
      props: { layout: 'vertical', gap: 2, sizingH: 'fill', sizingV: 'hug' },
    });
    txt(meta, item.label, { size: 11, wght: 600, fill: tok('color/ink') });
    txt(meta, item.hex, {
      family: 'IBM Plex Mono',
      size: 10,
      fill: tok('color/ink-muted'),
    });
  }
}

swatchGroup(cLeft, 'Paper & Ink', [
  { name: 'Paper', label: 'Paper', hex: '#F5F2EC', varName: 'color/paper' },
  { name: 'Elevated', label: 'Elevated', hex: '#FFFCF7', varName: 'color/paper-elevated' },
  { name: 'Well', label: 'Well', hex: '#ECE7DD', varName: 'color/paper-well' },
  { name: 'Ink', label: 'Ink', hex: '#1A1715', varName: 'color/ink' },
  { name: 'Secondary', label: 'Ink 2', hex: '#4A433C', varName: 'color/ink-secondary' },
  { name: 'Muted', label: 'Muted', hex: '#6B635B', varName: 'color/ink-muted' },
]);

swatchGroup(cLeft, 'Brand Signal & Rules', [
  { name: 'Terracotta', label: 'Accent', hex: '#BF3909', varName: 'color/accent' },
  { name: 'AccentWell', label: 'Accent Well', hex: '#F8E5DC', varName: 'color/accent-well' },
  { name: 'Hairline', label: 'Rule 1px', hex: '#D8D0C4', varName: 'color/rule' },
  { name: 'StrongRule', label: 'Control Edge', hex: '#877D71', varName: 'color/rule-strong' },
]);

swatchGroup(cLeft, 'Semantics & Supported Platforms', [
  { name: 'Success', label: 'Success', hex: '#166835', varName: 'color/status-ok' },
  { name: 'Warning', label: 'Warning', hex: '#8C5200', varName: 'color/status-warn' },
  { name: 'Error', label: 'Error', hex: '#B81D1D', varName: 'color/status-error' },
  { name: 'TikTok', label: 'TikTok', hex: '#006B72', varName: 'color/platform-tiktok' },
  { name: 'Instagram', label: 'Instagram', hex: '#B31E52', varName: 'color/platform-instagram' },
  { name: 'YouTube', label: 'YouTube', hex: '#C41E1E', varName: 'color/platform-youtube' },
]);

const cRight = frame(cBody, {
  width: 416,
  height: 540,
  name: 'SurfaceLadder',
  props: { layout: 'vertical', gap: 14, sizingH: 'fill', sizingV: 'hug' },
});
txt(cRight, 'Editorial Surface Ladder (Zero Card-Soup)', {
  size: 13,
  wght: 600,
  fill: tok('color/ink'),
});

const ladderSteps = [
  {
    title: '1. Canvas + Whitespace',
    desc: 'Warm archival paper #F5F2EC carries lists flat without outer card boxes.',
    fill: 'color/paper',
    border: 'color/rule',
    bw: 0,
    topW: 0,
  },
  {
    title: '2. Heavy Ink Rule (2px) & Hairline (1px)',
    desc: '2px #1A1715 anchors major regions; 1px #D8D0C4 divides queue and settings rows.',
    fill: 'color/paper',
    border: 'color/ink',
    bw: 0,
    topW: 2,
  },
  {
    title: '3. Recessed Well (#ECE7DD)',
    desc: 'Uniform 1px hairline well for clipboard alert, privacy notice, checklist, and tracks.',
    fill: 'color/paper-well',
    border: 'color/rule',
    bw: 1,
    radius: 4,
  },
  {
    title: '4. Elevated Sheet (#FFFCF7)',
    desc: 'Reserved strictly for inputs, navigation chrome, dialogs, and outlined controls.',
    fill: 'color/paper-elevated',
    border: 'color/rule-strong',
    bw: 1,
    radius: 4,
  },
];

for (const step of ladderSteps) {
  const box = frame(cRight, {
    width: 416,
    height: 82,
    name: step.title,
    props: {
      fill: tok(step.fill),
      stroke: tok(step.border),
      ...(step.bw
        ? { strokeWeight: step.bw }
        : {
            strokeTopWeight: step.topW ?? 0,
            strokeBottomWeight: 0,
            strokeLeftWeight: 0,
            strokeRightWeight: 0,
          }),
      strokeAlign: 'inside',
      cornerRadius: step.radius ?? 0,
      padding: [12, 14, 12, 14],
      layout: 'vertical',
      gap: 4,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  txt(box, step.title, { size: 14, wght: 600, fill: tok('color/ink') });
  txt(box, step.desc, {
    size: 12,
    fill: tok('color/ink-secondary'),
    width: 384,
  });
}

// --- Frame 2: Typography & Controls (960 x 720) ---
const fType = frame(undefined, {
  as: 'sysTypeFrame',
  x: 1020,
  y: 0,
  width: 960,
  height: 760,
  name: '02 · Typography & Controls',
  props: {
    fill: tok('color/paper'),
    layout: 'vertical',
    padding: 36,
    gap: 24,
    clip: true,
  },
});

const tHeader = frame(fType, {
  width: 888,
  height: 68,
  name: 'Header',
  props: {
    layout: 'vertical',
    padding: [0, 0, 12, 0],
    gap: 4,
    sizingH: 'fill',
    sizingV: 'hug',
  },
});
txt(tHeader, 'Typography & Architectural Controls', {
  family: 'Bricolage Grotesque',
  size: 28,
  wdth: 75,
  wght: 800,
  letterSpacing: -0.4,
});
txt(tHeader, 'Three weights only (400, 600, 800): Bricolage Grotesque, IBM Plex Sans, IBM Plex Mono', {
  family: 'IBM Plex Mono',
  size: 12,
  fill: tok('color/ink-muted'),
});
divider(fType, 2, tok('color/ink'), 'HeaderRule');

const tBody = frame(fType, {
  width: 888,
  height: 540,
  name: 'Columns',
  props: { layout: 'horizontal', gap: 32, sizingH: 'fill', sizingV: 'fill' },
});

const tLeft = frame(tBody, {
  width: 420,
  height: 540,
  name: 'TypeSpecimen',
  props: { layout: 'vertical', gap: 14, sizingH: 'fixed', sizingV: 'hug' },
});

const typeRows = [
  {
    meta: 'Display Wordmark (Bricolage 28px, wdth 75, wght 800)',
    sample: 'KlipFetch Downloads',
    family: 'Bricolage Grotesque',
    size: 28,
    wdth: 75,
    wght: 800,
    opsz: 96,
  },
  {
    meta: 'Media Title (Bricolage 20px, wdth 85, wght 800)',
    sample: 'Golden Hour Walk Through Gyedong-gil, Seoul',
    family: 'Bricolage Grotesque',
    size: 20,
    lineHeight: 24,
    wdth: 85,
    wght: 800,
    opsz: 48,
  },
  {
    meta: 'Row Title (IBM Plex Sans 15px, wght 600)',
    sample: 'Default Video Quality & Subtitle Muxing',
    family: 'IBM Plex Sans',
    size: 15,
    wght: 600,
  },
  {
    meta: 'Body (IBM Plex Sans 14px, wght 400)',
    sample: 'Paste a TikTok, Instagram, or YouTube URL to inspect formats.',
    family: 'IBM Plex Sans',
    size: 14,
    wght: 400,
  },
  {
    meta: 'Controls & Section Labels (IBM Plex Sans 13px, wght 600)',
    sample: 'Fetch Media, Download 1080p, Sign in to Instagram',
    family: 'IBM Plex Sans',
    size: 13,
    wght: 600,
  },
  {
    meta: 'Technical Outlier (IBM Plex Mono 12px, tabular numerals)',
    sample: '68%  4.8 MB/s  18s left  142.4 MB  01:35  2026.11.01',
    family: 'IBM Plex Mono',
    size: 12,
    wght: 400,
    features: { tnum: true },
  },
];

for (const r of typeRows) {
  const row = frame(tLeft, {
    width: 420,
    height: 60,
    name: r.meta.split('(')[0].trim(),
    props: {
      stroke: tok('color/rule'),
      strokeBottomWeight: 1,
      strokeTopWeight: 0,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      padding: [0, 0, 10, 0],
      layout: 'vertical',
      gap: 4,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  txt(row, r.meta, { size: 11, wght: 400, fill: tok('color/ink-muted') });
  txt(row, r.sample, {
    family: r.family,
    size: r.size,
    lineHeight: r.lineHeight,
    wdth: r.wdth,
    wght: r.wght,
    opsz: r.opsz,
    features: r.features,
    width: 416,
  });
}

const tRight = frame(tBody, {
  width: 436,
  height: 540,
  name: 'ControlGallery',
  props: { layout: 'vertical', gap: 14, sizingH: 'fill', sizingV: 'hug' },
});

txt(tRight, 'Button Hierarchy (Single filled terracotta CTA recipe)', {
  size: 13,
  wght: 600,
});
const btnRow1 = frame(tRight, {
  width: 436,
  height: 44,
  name: 'ButtonsPrimary',
  props: { layout: 'horizontal', gap: 10, crossAlign: 'center', sizingH: 'fill', sizingV: 'hug' },
});
button(btnRow1, 'Fetch Media', 'primary', { icon: 'search', height: 44 });
button(btnRow1, 'Sign In', 'outlinedInk', { icon: 'key', height: 44 });
button(btnRow1, 'Cancel', 'outlined', { height: 44 });

const btnRow2 = frame(tRight, {
  width: 436,
  height: 36,
  name: 'ButtonsSecondary',
  props: { layout: 'horizontal', gap: 10, crossAlign: 'center', sizingH: 'fill', sizingV: 'hug' },
});
button(btnRow2, 'Sign in to Instagram', 'outlinedDanger', { height: 34 });
button(btnRow2, 'Clear', 'ghostDanger', { height: 34, padH: 10 });
button(btnRow2, 'Disabled', 'primary', { height: 34, disabled: true });

txt(tRight, 'Input States (Default and Focused 2px Ring)', { size: 13, wght: 600 });
const inpDefault = frame(tRight, {
  width: 436,
  height: 44,
  name: 'Input/Default',
  props: {
    fill: tok('color/paper-elevated'),
    stroke: tok('color/rule-strong'),
    strokeWeight: 1,
    strokeAlign: 'inside',
    cornerRadius: 4,
    padding: [0, 12, 0, 12],
    layout: 'horizontal',
    gap: 8,
    crossAlign: 'center',
    sizingH: 'fill',
    sizingV: 'fixed',
  },
});
icon(inpDefault, 'link', 16, tok('color/ink-muted'));
txt(inpDefault, 'https://tiktok.com/… or youtu.be/…', {
  family: 'IBM Plex Mono',
  size: 12,
  fill: tok('color/ink-muted'),
  sizingH: 'fill',
});
icon(inpDefault, 'paste', 16, tok('color/ink-secondary'));

const inpFocus = frame(tRight, {
  width: 436,
  height: 44,
  name: 'Input/Focus',
  props: {
    fill: tok('color/paper-elevated'),
    stroke: tok('color/focus'),
    strokeWeight: 2,
    strokeAlign: 'inside',
    cornerRadius: 4,
    padding: [0, 12, 0, 12],
    layout: 'horizontal',
    gap: 8,
    crossAlign: 'center',
    sizingH: 'fill',
    sizingV: 'fixed',
  },
});
icon(inpFocus, 'link', 16, tok('color/accent'));
txt(inpFocus, 'https://youtu.be/aqz-KE-bpKQ', {
  family: 'IBM Plex Mono',
  size: 12,
  fill: tok('color/ink'),
  sizingH: 'fill',
});
icon(inpFocus, 'clear', 14, tok('color/ink-muted'));

txt(tRight, 'Segmented Control, Spec Chips & Platform Markers', { size: 13, wght: 600 });
const segEx = frame(tRight, {
  width: 436,
  height: 40,
  name: 'SegmentedExample',
  props: {
    fill: tok('color/paper-well'),
    stroke: tok('color/rule'),
    strokeWeight: 1,
    strokeAlign: 'inside',
    cornerRadius: 4,
    padding: 3,
    layout: 'horizontal',
    gap: 3,
    sizingH: 'fill',
    sizingV: 'fixed',
  },
});
const segA = frame(segEx, {
  width: 210,
  height: 34,
  name: 'Active',
  props: {
    fill: tok('color/ink'),
    cornerRadius: 2,
    layout: 'horizontal',
    mainAlign: 'center',
    crossAlign: 'center',
    sizingH: 'fill',
    sizingV: 'fill',
  },
});
txt(segA, 'Video', { size: 13, wght: 600, fill: tok('color/accent-ink') });
const segB = frame(segEx, {
  width: 210,
  height: 34,
  name: 'Inactive',
  props: {
    layout: 'horizontal',
    mainAlign: 'center',
    crossAlign: 'center',
    sizingH: 'fill',
    sizingV: 'fill',
  },
});
txt(segB, 'Audio Only', { size: 13, wght: 400, fill: tok('color/ink-secondary') });

// Quality chips strictly in IBM Plex Sans (Gate 64)
const chipRow = frame(tRight, {
  width: 436,
  height: 32,
  name: 'SpecChips',
  props: { layout: 'horizontal', gap: 8, crossAlign: 'center', sizingH: 'fill', sizingV: 'hug' },
});
for (const c of [
  { t: '2160p 4K', sel: false },
  { t: '1080p HD', sel: true },
  { t: '720p HD', sel: false },
]) {
  const ch = frame(chipRow, {
    width: 90,
    height: 30,
    name: `Chip/${c.t}`,
    props: {
      fill: c.sel ? tok('color/ink') : tok('color/paper-elevated'),
      ...(c.sel ? {} : { stroke: tok('color/rule-strong'), strokeWeight: 1, strokeAlign: 'inside' }),
      cornerRadius: 4,
      padding: [0, 12, 0, 12],
      layout: 'horizontal',
      mainAlign: 'center',
      crossAlign: 'center',
      sizingH: 'hug',
      sizingV: 'fixed',
    },
  });
  txt(ch, c.t, {
    family: 'IBM Plex Sans',
    size: 12,
    wght: c.sel ? 600 : 400,
    features: { tnum: true },
    fill: c.sel ? tok('color/accent-ink') : tok('color/ink'),
  });
}

const markerRow = frame(tRight, {
  width: 436,
  height: 24,
  name: 'Markers',
  props: { layout: 'horizontal', gap: 14, crossAlign: 'center', sizingH: 'fill', sizingV: 'hug' },
});
platformMarker(markerRow, 'TikTok', 'color/platform-tiktok', true);
platformMarker(markerRow, 'Instagram', 'color/platform-instagram', true);
platformMarker(markerRow, 'YouTube', 'color/platform-youtube', true);
squareTag(markerRow, 'Rust Core', 'color/paper-well', 'color/ink-secondary', 'color/rule', true);
squareTag(markerRow, 'Connected', 'color/status-ok-well', 'color/status-ok');

txt(tRight, 'Editorial Bottom Navigation (Top 2px rule, badge clear of icon)', {
  size: 12,
  wght: 600,
  fill: tok('color/ink-muted'),
});
const navSampleWrap = frame(tRight, {
  width: 412,
  height: 68,
  name: 'NavPreview',
  props: {
    layout: 'vertical',
    stroke: tok('color/rule'),
    strokeWeight: 1,
    clip: true,
    sizingH: 'fixed',
    sizingV: 'fixed',
  },
});
bottomNav(navSampleWrap, 1, 2);

// --- Frame 3: KlipFetch Launcher Icon (960 x 720) ---
const fIcon = frame(undefined, {
  as: 'sysIconFrame',
  x: 2040,
  y: 0,
  width: 960,
  height: 760,
  name: '03 · KlipFetch Launcher Icon',
  props: {
    fill: tok('color/paper'),
    layout: 'vertical',
    padding: 36,
    gap: 24,
    clip: true,
  },
});

const iHeader = frame(fIcon, {
  width: 888,
  height: 68,
  name: 'Header',
  props: {
    layout: 'vertical',
    padding: [0, 0, 12, 0],
    gap: 4,
    sizingH: 'fill',
    sizingV: 'hug',
  },
});
txt(iHeader, 'KlipFetch Brand Mark & Adaptive Icon', {
  family: 'Bricolage Grotesque',
  size: 28,
  wdth: 75,
  wght: 800,
  letterSpacing: -0.4,
});
txt(iHeader, 'Kiln Aperture K and Terracotta Fetch Leg, centered within 66dp Android adaptive safe zone', {
  family: 'IBM Plex Mono',
  size: 12,
  fill: tok('color/ink-muted'),
});
divider(fIcon, 2, tok('color/ink'), 'HeaderRule');

const iBody = frame(fIcon, {
  width: 888,
  height: 540,
  name: 'IconShowcase',
  props: { layout: 'horizontal', gap: 40, sizingH: 'fill', sizingV: 'fill' },
});

const iMasterCol = frame(iBody, {
  width: 360,
  height: 560,
  name: 'MasterColumn',
  props: { layout: 'vertical', gap: 16, sizingH: 'fixed', sizingV: 'hug' },
});
txt(iMasterCol, 'Master Adaptive Icon (108dp grid, 66dp safe circle)', { size: 14, wght: 600 });

const masterCanvas = frame(iMasterCol, {
  width: 280,
  height: 280,
  name: 'MasterAdaptiveCanvas',
  props: {
    fill: tok('color/ink'),
    cornerRadius: 56,
    clip: true,
    sizingH: 'fixed',
    sizingV: 'fixed',
  },
});
// 66/108 * 280 = 171px diameter, offset = (280 - 171) / 2 = 54.5
ellipse(masterCanvas, {
  x: 54,
  y: 54,
  width: 172,
  height: 172,
  name: 'SafeZone66dpGuide',
  props: {
    fill: 'none',
    stroke: '#4A433C',
    strokeWeight: 1,
    dashes: [4, 4],
  },
});
drawBrandMark(masterCanvas, 280, { name: 'MasterKlipFetchMark' });

txt(
  iMasterCol,
  'Exact 45-degree K geometry bounded inside x/y 31..77 (r = 32.5dp inside 33dp safe radius) with 5dp open baseline gap.',
  { size: 13, fill: tok('color/ink-secondary'), width: 320 }
);

const exportRow = frame(iMasterCol, {
  width: 360,
  height: 130,
  name: 'VectorExportBox',
  props: {
    fill: tok('color/paper-well'),
    stroke: tok('color/rule'),
    strokeWeight: 1,
    cornerRadius: 4,
    padding: 12,
    layout: 'horizontal',
    gap: 14,
    crossAlign: 'center',
    sizingH: 'fill',
    sizingV: 'hug',
  },
});
const exportBg = frame(exportRow, {
  width: 108,
  height: 108,
  name: 'ExportPreviewPlate',
  props: {
    fill: tok('color/ink'),
    cornerRadius: 8,
    sizingH: 'fixed',
    sizingV: 'fixed',
  },
});
drawBrandMark(exportBg, 108, {
  name: 'KlipFetch Icon Vector',
  as: 'iconVectorFrame',
});
const exportMeta = frame(exportRow, {
  width: 210,
  height: 90,
  name: 'ExportMeta',
  props: { layout: 'vertical', gap: 4, sizingH: 'fill', sizingV: 'hug' },
});
txt(exportMeta, 'XML Vector Sources', { size: 13, wght: 600 });
txt(exportMeta, '108 × 108 dp, 4 paths', {
  size: 12,
  fill: tok('color/ink-secondary'),
  width: 204,
});
txt(exportMeta, 'ic_klipfetch_foreground.xml\nic_klipfetch_monochrome.xml', {
  family: 'IBM Plex Mono',
  size: 10.5,
  fill: tok('color/ink'),
  width: 204,
});

const iMaskCol = frame(iBody, {
  width: 508,
  height: 540,
  name: 'MasksAndSizes',
  props: { layout: 'vertical', gap: 24, sizingH: 'fill', sizingV: 'hug' },
});
txt(iMaskCol, 'Android Adaptive Launcher Masks (Exact 108dp scale)', { size: 14, wght: 600 });

const masksRow = frame(iMaskCol, {
  width: 480,
  height: 150,
  name: 'MasksRow',
  props: { layout: 'horizontal', gap: 16, sizingH: 'fill', sizingV: 'hug' },
});

const maskSpecs = [
  { name: 'Squircle', radius: 32, bg: 'color/ink', mono: false },
  { name: 'Circle', radius: 54, bg: 'color/ink', mono: false },
  { name: 'Rounded', radius: 18, bg: 'color/ink', mono: false },
  { name: 'Monochrome', radius: 32, bg: 'color/paper-well', mono: true, fg: 'color/ink' },
];

for (const m of maskSpecs) {
  const col = frame(masksRow, {
    width: 108,
    height: 140,
    name: `Mask/${m.name}`,
    props: { layout: 'vertical', gap: 8, crossAlign: 'center', sizingH: 'hug', sizingV: 'hug' },
  });
  const tile = frame(col, {
    width: 108,
    height: 108,
    name: 'Tile',
    props: {
      fill: tok(m.bg),
      cornerRadius: m.radius,
      clip: true,
      ...(m.mono ? { stroke: tok('color/rule-strong'), strokeWeight: 1, strokeAlign: 'inside' } : {}),
      sizingH: 'fixed',
      sizingV: 'fixed',
    },
  });
  drawBrandMark(tile, 108, {
    name: m.mono ? 'KlipFetch Icon Monochrome' : `Mark/${m.name}`,
    as: m.mono ? 'iconMonoFrame' : undefined,
    mono: m.mono,
    primaryColor: m.fg ? tok(m.fg) : tok('color/paper-elevated'),
  });
  txt(col, m.name, { size: 12, wght: 400, fill: tok('color/ink-secondary') });
}

divider(iMaskCol, 1, tok('color/rule'));
txt(iMaskCol, 'Optical Legibility at Notification & Launcher Sizes', { size: 14, wght: 600 });

const sizesRow = frame(iMaskCol, {
  width: 508,
  height: 110,
  name: 'SizesRow',
  props: { layout: 'horizontal', gap: 24, crossAlign: 'max', sizingH: 'fill', sizingV: 'hug' },
});

for (const sz of [64, 48, 32, 24]) {
  const col = frame(sizesRow, {
    width: sz,
    height: sz + 26,
    name: `Size/${sz}`,
    props: { layout: 'vertical', gap: 8, crossAlign: 'center', sizingH: 'hug', sizingV: 'hug' },
  });
  const tile = frame(col, {
    width: sz,
    height: sz,
    name: 'Icon',
    props: {
      fill: tok('color/ink'),
      cornerRadius: Math.max(4, Math.round(sz * 0.22)),
      clip: true,
      sizingH: 'fixed',
      sizingV: 'fixed',
    },
  });
  drawBrandMark(tile, sz, { name: `Mark/${sz}` });
  txt(col, `${sz}px`, {
    family: 'IBM Plex Mono',
    size: 11,
    fill: tok('color/ink-muted'),
  });
}

// ===========================================================================
// PAGE 2: 02 · App Screens (9 clean, honest screens at 412px Android Compact width)
// ===========================================================================
cmd('page.add', { name: '02 · App Screens' }, 'screensPage');
cmd('page.setBackground', { color: '#DDD6CB' });

const SCREEN_X = [0, 476, 952, 1428, 1904, 2380, 2856, 3332, 3808];
const screenRefs = [];

function phoneFrame(index, title, opts = {}) {
  const height = opts.height ?? 917;
  const f = frame(undefined, {
    as: opts.as,
    x: SCREEN_X[index],
    y: 0,
    width: 412,
    height,
    name: title,
    props: {
      fill: tok('color/paper'),
      clip: true,
      layout: 'vertical',
      mainAlign: 'spaceBetween',
      sizingH: 'fixed',
      sizingV: 'fixed',
    },
  });
  screenRefs.push({ ref: f, title });
  const topGroup = frame(f, {
    width: 412,
    height: height - (opts.hasBottomNav ? 68 : 0),
    name: 'ScreenContent',
    props: {
      layout: 'vertical',
      sizingH: 'fill',
      sizingV: 'fill',
      clip: true,
    },
  });
  statusBar(topGroup, opts.statusFill || 'color/paper');
  const body = frame(topGroup, {
    width: 412,
    height: 700,
    name: 'Body',
    props: {
      layout: 'vertical',
      sizingH: 'fill',
      sizingV: 'fill',
    },
  });
  if (opts.hasBottomNav) {
    bottomNav(f, opts.activeTab ?? 0, opts.activeCount ?? 2);
  }
  return { frame: f, body };
}

// Uniform 2px heavy ink divider under EVERY masthead
function masthead(parent, title, rightLabel = null, rightColor = 'color/ink-muted') {
  const wrap = frame(parent, {
    width: 412,
    height: 54,
    name: 'MastheadWrap',
    props: { layout: 'vertical', gap: 0, sizingH: 'fill', sizingV: 'hug' },
  });
  const row = frame(wrap, {
    width: 412,
    height: 52,
    name: 'Masthead',
    props: {
      padding: [10, 20, 12, 20],
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'max',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  txt(row, title, {
    family: 'Bricolage Grotesque',
    size: 26,
    lineHeight: 28,
    wdth: 75,
    wght: 800,
    letterSpacing: -0.4,
  });
  if (rightLabel) {
    txt(row, rightLabel, {
      size: 13,
      wght: 600,
      fill: tok(rightColor),
    });
  }
  divider(wrap, 2, tok('color/ink'), 'MastheadHeavyRule');
  return wrap;
}

// ---------------------------------------------------------------------------
// Screen 1: 01 · Home — Intake (Calm, honest intake without dev-jargon table)
// ---------------------------------------------------------------------------
{
  const { body } = phoneFrame(0, '01 · Home — Intake', {
    as: 'scrHomeIntake',
    hasBottomNav: true,
    activeTab: 0,
    activeCount: 2,
  });
  masthead(body, 'KlipFetch');

  const platBar = frame(body, {
    width: 412,
    height: 40,
    name: 'SupportedRow',
    props: {
      stroke: tok('color/rule'),
      strokeBottomWeight: 1,
      strokeTopWeight: 0,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      padding: [10, 20, 10, 20],
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  txt(platBar, 'Supported', { size: 12, wght: 400, fill: tok('color/ink-muted') });
  const platList = frame(platBar, {
    width: 240,
    height: 20,
    name: 'Platforms',
    props: { layout: 'horizontal', gap: 14, crossAlign: 'center', sizingH: 'hug', sizingV: 'hug' },
  });
  platformMarker(platList, 'TikTok', 'color/platform-tiktok', true);
  platformMarker(platList, 'Instagram', 'color/platform-instagram', true);
  platformMarker(platList, 'YouTube', 'color/platform-youtube', true);

  const intake = frame(body, {
    width: 412,
    height: 360,
    name: 'IntakeSection',
    props: {
      padding: [18, 20, 20, 20],
      layout: 'vertical',
      gap: 16,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });

  // Clipboard Detection Well (uniform 1px border, NO thick colored side stripe)
  const clipWell = frame(intake, {
    width: 372,
    height: 62,
    name: 'ClipboardSuggestion',
    props: {
      fill: tok('color/paper-well'),
      stroke: tok('color/rule'),
      strokeWeight: 1,
      strokeAlign: 'inside',
      cornerRadius: 4,
      padding: [10, 12, 10, 14],
      layout: 'horizontal',
      gap: 10,
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  const clipText = frame(clipWell, {
    width: 240,
    height: 38,
    name: 'ClipText',
    props: { layout: 'vertical', gap: 2, sizingH: 'fill', sizingV: 'hug' },
  });
  txt(clipText, 'Link found in clipboard', { size: 12, wght: 600 });
  txt(clipText, 'https://youtu.be/aqz-KE-bpKQ', {
    family: 'IBM Plex Mono',
    size: 11.5,
    fill: tok('color/ink-secondary'),
    maxLines: 1,
  });
  button(clipWell, 'Fetch', 'outlinedInk', { height: 34, padH: 14 });

  const form = frame(intake, {
    width: 372,
    height: 132,
    name: 'UrlForm',
    props: { layout: 'vertical', gap: 8, sizingH: 'fill', sizingV: 'hug' },
  });
  txt(form, 'Paste media URL', { size: 13, wght: 600 });
  const input = frame(form, {
    width: 372,
    height: 48,
    name: 'home_url_input',
    props: {
      fill: tok('color/paper-elevated'),
      stroke: tok('color/rule-strong'),
      strokeWeight: 1,
      strokeAlign: 'inside',
      cornerRadius: 4,
      padding: [0, 12, 0, 12],
      layout: 'horizontal',
      gap: 10,
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  icon(input, 'link', 16, tok('color/ink-muted'));
  txt(input, 'https://tiktok.com/… or youtu.be/…', {
    family: 'IBM Plex Mono',
    size: 11.5,
    fill: tok('color/ink-muted'),
    maxLines: 1,
    sizingH: 'fill',
  });
  icon(input, 'paste', 16, tok('color/ink-secondary'));

  const spacerBtn = frame(form, {
    width: 372,
    height: 52,
    name: 'FetchButtonWrap',
    props: { padding: [4, 0, 0, 0], layout: 'vertical', sizingH: 'fill', sizingV: 'hug' },
  });
  button(spacerBtn, 'Fetch Media', 'primary', {
    icon: 'search',
    height: 48,
    fillWidth: true,
  });

  // Clean user-facing guidance ledger (no internal engineering jargon)
  const guideWrap = frame(body, {
    width: 412,
    height: 200,
    name: 'UsageGuidance',
    props: {
      padding: [12, 20, 20, 20],
      layout: 'vertical',
      gap: 0,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  divider(guideWrap, 1, tok('color/rule'), 'GuideTopRule');
  const gRow1 = frame(guideWrap, {
    width: 372,
    height: 64,
    name: 'ShareSheetRow',
    props: {
      stroke: tok('color/rule'),
      strokeBottomWeight: 1,
      strokeTopWeight: 0,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      padding: [12, 0, 12, 0],
      layout: 'vertical',
      gap: 3,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  txt(gRow1, 'Share from other apps', { size: 13, wght: 600 });
  txt(gRow1, 'Send any TikTok, Instagram, or YouTube link straight to KlipFetch via the Android Share menu.', {
    size: 12,
    fill: tok('color/ink-secondary'),
    width: 372,
  });

  const gRow2 = frame(guideWrap, {
    width: 372,
    height: 60,
    name: 'SaveFolderRow',
    props: {
      padding: [12, 0, 12, 0],
      layout: 'vertical',
      gap: 3,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  txt(gRow2, 'Saved downloads folder', { size: 13, wght: 600 });
  txt(gRow2, 'Downloads/KlipFetch/{TikTok,Instagram,YouTube}', {
    family: 'IBM Plex Mono',
    size: 11.5,
    fill: tok('color/ink-secondary'),
  });
}

// ---------------------------------------------------------------------------
// Screen 2: 02 · Home — Media Spec Sheet (Real photo thumbnail + IBM Plex Sans chips)
// ---------------------------------------------------------------------------
{
  const { body } = phoneFrame(1, '02 · Home — Media Spec Sheet', {
    as: 'scrHomeSpec',
    hasBottomNav: true,
    activeTab: 0,
    activeCount: 2,
  });

  const topForm = frame(body, {
    width: 412,
    height: 102,
    name: 'CompactUrlBar',
    props: {
      padding: [8, 20, 10, 20],
      layout: 'vertical',
      gap: 8,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  const inp = frame(topForm, {
    width: 372,
    height: 44,
    name: 'FilledUrlInput',
    props: {
      fill: tok('color/paper-elevated'),
      stroke: tok('color/rule-strong'),
      strokeWeight: 1,
      strokeAlign: 'inside',
      cornerRadius: 4,
      padding: [0, 12, 0, 12],
      layout: 'horizontal',
      gap: 10,
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  icon(inp, 'link', 15, tok('color/ink-secondary'));
  txt(inp, 'https://youtu.be/aqz-KE-bpKQ', {
    family: 'IBM Plex Mono',
    size: 12,
    fill: tok('color/ink'),
    maxLines: 1,
    sizingH: 'fill',
  });
  icon(inp, 'clear', 14, tok('color/ink-muted'));
  icon(inp, 'paste', 15, tok('color/ink-secondary'));

  const subRow = frame(topForm, {
    width: 372,
    height: 32,
    name: 'DetectedActionRow',
    props: {
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  const leftStatus = frame(subRow, {
    width: 160,
    height: 20,
    name: 'LeftStatus',
    props: { layout: 'horizontal', gap: 10, crossAlign: 'center', sizingH: 'hug', sizingV: 'hug' },
  });
  platformMarker(leftStatus, 'YouTube', 'color/platform-youtube', true);
  squareTag(leftStatus, 'yt-dlp', 'color/paper-well', 'color/ink-secondary', 'color/rule', true);
  button(subRow, 'Fetch Media', 'outlinedInk', { height: 32, padH: 12, fontSize: 12 });

  divider(body, 2, tok('color/ink'), 'SpecHeaderRule');

  const sheet = frame(body, {
    width: 412,
    height: 700,
    name: 'MediaSpecSheet',
    props: {
      padding: [14, 20, 16, 20],
      layout: 'vertical',
      gap: 12,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });

  // Real photographic video preview (NO wireframe/waveform fake!)
  const thumb = frame(sheet, {
    as: 'videoThumbFrame',
    width: 372,
    height: 152,
    name: 'MediaPreviewStill',
    props: {
      fill: tok('color/ink'),
      stroke: tok('color/rule-strong'),
      strokeWeight: 1,
      strokeAlign: 'inside',
      cornerRadius: 4,
      clip: true,
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  cmd(
    'image.place',
    {
      path: seoulPhotoPath,
      parent: thumb,
      x: 0,
      y: 0,
      width: 372,
      height: 152,
      mode: 'fill',
      name: 'VideoStillPhoto',
    },
    'seoulPhotoLayer'
  );
  cmd('image.adjust', {
    ids: [{ $ref: 'seoulPhotoLayer' }],
    filters: { saturation: -0.1, contrast: 0.04 },
  });
  const durBadge = frame(thumb, {
    x: 314,
    y: 122,
    width: 48,
    height: 20,
    name: 'DurationStamp',
    props: {
      fill: '#14110FE6',
      cornerRadius: 2,
      layout: 'horizontal',
      mainAlign: 'center',
      crossAlign: 'center',
      sizingH: 'fixed',
      sizingV: 'fixed',
    },
  });
  txt(durBadge, '01:35', { family: 'IBM Plex Mono', size: 11, wght: 400, fill: '#FFFDF9' });

  const titleGrp = frame(sheet, {
    width: 372,
    height: 46,
    name: 'TitleMeta',
    props: { layout: 'vertical', gap: 3, sizingH: 'fill', sizingV: 'hug' },
  });
  txt(titleGrp, 'Golden Hour Walk Through Gyedong-gil, Seoul', {
    family: 'Bricolage Grotesque',
    size: 20,
    lineHeight: 23,
    wdth: 85,
    wght: 800,
    opsz: 48,
    width: 372,
  });
  txt(titleGrp, 'Basile Morin', {
    size: 12,
    fill: tok('color/ink-muted'),
  });

  const modeSeg = frame(sheet, {
    width: 372,
    height: 38,
    name: 'ModeSwitch',
    props: {
      fill: tok('color/paper-well'),
      stroke: tok('color/rule'),
      strokeWeight: 1,
      strokeAlign: 'inside',
      cornerRadius: 4,
      padding: 3,
      layout: 'horizontal',
      gap: 3,
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  const mVid = frame(modeSeg, {
    width: 180,
    height: 32,
    name: 'Video',
    props: {
      fill: tok('color/ink'),
      cornerRadius: 2,
      layout: 'horizontal',
      mainAlign: 'center',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fill',
    },
  });
  txt(mVid, 'Video', { size: 13, wght: 600, fill: tok('color/accent-ink') });
  const mAud = frame(modeSeg, {
    width: 180,
    height: 32,
    name: 'AudioOnly',
    props: {
      layout: 'horizontal',
      mainAlign: 'center',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fill',
    },
  });
  txt(mAud, 'Audio Only', { size: 13, wght: 400, fill: tok('color/ink-secondary') });

  // Quality chips strictly IBM Plex Sans + evenly spanning 372px
  const qBlock = frame(sheet, {
    width: 372,
    height: 60,
    name: 'QualityBlock',
    props: { layout: 'vertical', gap: 6, sizingH: 'fill', sizingV: 'hug' },
  });
  txt(qBlock, 'Quality', { size: 13, wght: 600 });
  const qRow = frame(qBlock, {
    width: 372,
    height: 32,
    name: 'QualityChips',
    props: { layout: 'horizontal', gap: 6, sizingH: 'fill', sizingV: 'hug' },
  });
  for (const q of [
    { label: '2160p 4K', sel: false },
    { label: '1440p 2K', sel: false },
    { label: '1080p HD', sel: true },
    { label: '720p HD', sel: false },
  ]) {
    const qc = frame(qRow, {
      width: 88,
      height: 32,
      name: `Q/${q.label}`,
      props: {
        fill: q.sel ? tok('color/ink') : tok('color/paper-elevated'),
        ...(q.sel ? {} : { stroke: tok('color/rule-strong'), strokeWeight: 1, strokeAlign: 'inside' }),
        cornerRadius: 4,
        padding: [0, 8, 0, 8],
        layout: 'horizontal',
        mainAlign: 'center',
        crossAlign: 'center',
        sizingH: 'fill',
        sizingV: 'fixed',
      },
    });
    txt(qc, q.label, {
      family: 'IBM Plex Sans',
      size: 12,
      wght: q.sel ? 600 : 400,
      features: { tnum: true },
      fill: q.sel ? tok('color/accent-ink') : tok('color/ink'),
    });
  }

  const cRow = frame(sheet, {
    width: 372,
    height: 42,
    name: 'VideoContainerRow',
    props: {
      stroke: tok('color/rule'),
      strokeTopWeight: 1,
      strokeBottomWeight: 1,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  txt(cRow, 'Video Container', { size: 13, wght: 600 });
  const cSeg = frame(cRow, {
    width: 112,
    height: 30,
    name: 'ContainerSeg',
    props: {
      fill: tok('color/paper-well'),
      stroke: tok('color/rule'),
      strokeWeight: 1,
      strokeAlign: 'inside',
      cornerRadius: 4,
      padding: 2,
      layout: 'horizontal',
      gap: 2,
      sizingH: 'fixed',
      sizingV: 'fixed',
    },
  });
  const cMp4 = frame(cSeg, {
    width: 53,
    height: 26,
    name: 'MP4',
    props: {
      fill: tok('color/ink'),
      cornerRadius: 2,
      layout: 'horizontal',
      mainAlign: 'center',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fill',
    },
  });
  txt(cMp4, 'MP4', { family: 'IBM Plex Sans', size: 11.5, wght: 600, fill: tok('color/accent-ink') });
  const cMkv = frame(cSeg, {
    width: 53,
    height: 26,
    name: 'MKV',
    props: {
      layout: 'horizontal',
      mainAlign: 'center',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fill',
    },
  });
  txt(cMkv, 'MKV', { family: 'IBM Plex Sans', size: 11.5, wght: 400, fill: tok('color/ink-secondary') });

  const sw1 = frame(sheet, {
    width: 372,
    height: 44,
    name: 'SubtitlesRow',
    props: {
      stroke: tok('color/rule'),
      strokeBottomWeight: 1,
      strokeTopWeight: 0,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  const sw1L = frame(sw1, {
    width: 260,
    height: 36,
    name: 'SubtitlesText',
    props: { layout: 'vertical', gap: 1, sizingH: 'fill', sizingV: 'hug' },
  });
  txt(sw1L, 'Download subtitles (SRT/VTT)', { size: 13, wght: 400 });
  txt(sw1L, 'Available: en, id', { size: 11, fill: tok('color/ink-muted') });
  toggleSwitch(sw1, false);

  const sw2 = frame(sheet, {
    width: 372,
    height: 38,
    name: 'SponsorBlockRow',
    props: {
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  txt(sw2, 'Remove SponsorBlock segments', { size: 13, wght: 400 });
  toggleSwitch(sw2, true);

  button(sheet, 'Download 1080p', 'primary', {
    icon: 'download',
    height: 48,
    fillWidth: true,
  });
}

// ---------------------------------------------------------------------------
// Screen 3a: 03a · Home — Playlist Picker (Pure YouTube playlist screen)
// ---------------------------------------------------------------------------
{
  const { body } = phoneFrame(2, '03a · Home — Playlist Picker', {
    as: 'scrHomePlaylist',
    hasBottomNav: true,
    activeTab: 0,
    activeCount: 2,
  });

  const topForm = frame(body, {
    width: 412,
    height: 102,
    name: 'CompactUrlBar',
    props: {
      padding: [8, 20, 10, 20],
      layout: 'vertical',
      gap: 8,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  const inp = frame(topForm, {
    width: 372,
    height: 44,
    name: 'PlaylistUrlInput',
    props: {
      fill: tok('color/paper-elevated'),
      stroke: tok('color/rule-strong'),
      strokeWeight: 1,
      strokeAlign: 'inside',
      cornerRadius: 4,
      padding: [0, 12, 0, 12],
      layout: 'horizontal',
      gap: 10,
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  icon(inp, 'link', 15, tok('color/ink-secondary'));
  txt(inp, 'https://youtube.com/playlist?list=PL_SYS04', {
    family: 'IBM Plex Mono',
    size: 11.5,
    fill: tok('color/ink'),
    maxLines: 1,
    sizingH: 'fill',
  });
  icon(inp, 'clear', 14, tok('color/ink-muted'));
  icon(inp, 'paste', 15, tok('color/ink-secondary'));

  const subRow = frame(topForm, {
    width: 372,
    height: 32,
    name: 'DetectedActionRow',
    props: {
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  const leftStatus = frame(subRow, {
    width: 220,
    height: 20,
    name: 'LeftStatus',
    props: { layout: 'horizontal', gap: 8, crossAlign: 'center', sizingH: 'hug', sizingV: 'hug' },
  });
  platformMarker(leftStatus, 'YouTube', 'color/platform-youtube', true);
  squareTag(leftStatus, 'yt-dlp', 'color/paper-well', 'color/ink-secondary', 'color/rule', true);
  squareTag(leftStatus, 'Playlist (3 videos)', 'color/paper-well', 'color/ink', 'color/rule');
  button(subRow, 'Fetch Media', 'outlinedInk', { height: 32, padH: 12, fontSize: 12 });

  divider(body, 2, tok('color/ink'), 'PlaylistHeaderRule');

  const plSheet = frame(body, {
    width: 412,
    height: 680,
    name: 'PlaylistSpecSheet',
    props: {
      padding: [16, 20, 16, 20],
      layout: 'vertical',
      gap: 12,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });

  txt(plSheet, 'Android Systems & Native FFI Lectures', {
    family: 'Bricolage Grotesque',
    size: 20,
    lineHeight: 24,
    wdth: 85,
    wght: 800,
    opsz: 48,
    width: 372,
  });
  txt(plSheet, 'Systems Lecture Archive', { size: 12, fill: tok('color/ink-muted') });

  const plHeader = frame(plSheet, {
    width: 372,
    height: 30,
    name: 'PlaylistHeaderRow',
    props: {
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  txt(plHeader, 'Playlist Videos (2/3)', {
    size: 13,
    wght: 600,
    features: { tnum: true },
  });
  const plBtns = frame(plHeader, {
    width: 96,
    height: 26,
    name: 'SelectBtns',
    props: { layout: 'horizontal', gap: 14, crossAlign: 'center', sizingH: 'hug', sizingV: 'hug' },
  });
  txt(plBtns, 'All', { size: 13, wght: 600, fill: tok('color/ink') });
  txt(plBtns, 'None', { size: 13, wght: 400, fill: tok('color/ink-secondary') });

  const plList = frame(plSheet, {
    width: 372,
    height: 142,
    name: 'PlaylistChecklist',
    props: {
      fill: tok('color/paper-well'),
      stroke: tok('color/rule'),
      strokeWeight: 1,
      strokeAlign: 'inside',
      cornerRadius: 4,
      layout: 'vertical',
      clip: true,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  for (const ep of [
    { idx: 1, title: '1. SELinux W^X Boundaries on Android 10+', checked: true, last: false },
    { idx: 2, title: '2. Zero-Copy Rust FFI Streams via tokio', checked: true, last: false },
    { idx: 3, title: '3. MediaStore Scoped Export Patterns', checked: false, last: true },
  ]) {
    const row = frame(plList, {
      width: 372,
      height: 46,
      name: `playlist_entry_${ep.idx}`,
      props: {
        ...(ep.last
          ? {}
          : {
              stroke: tok('color/rule'),
              strokeBottomWeight: 1,
              strokeTopWeight: 0,
              strokeLeftWeight: 0,
              strokeRightWeight: 0,
              strokeAlign: 'inside',
            }),
        padding: [0, 14, 0, 14],
        layout: 'horizontal',
        gap: 12,
        crossAlign: 'center',
        sizingH: 'fill',
        sizingV: 'fixed',
      },
    });
    const cb = frame(row, {
      width: 18,
      height: 18,
      name: 'Checkbox',
      props: {
        fill: ep.checked ? tok('color/accent') : tok('color/paper-elevated'),
        ...(ep.checked ? {} : { stroke: tok('color/rule-strong'), strokeWeight: 1, strokeAlign: 'inside' }),
        cornerRadius: 2,
        layout: 'horizontal',
        mainAlign: 'center',
        crossAlign: 'center',
        sizingH: 'fixed',
        sizingV: 'fixed',
      },
    });
    if (ep.checked) {
      icon(cb, 'check', 12, tok('color/accent-ink'));
    }
    txt(row, ep.title, {
      size: 13,
      wght: ep.checked ? 600 : 400,
      fill: tok('color/ink'),
      maxLines: 1,
    });
  }

  // Container & YouTube Options
  const cRow = frame(plSheet, {
    width: 372,
    height: 44,
    name: 'VideoContainerRow',
    props: {
      stroke: tok('color/rule'),
      strokeTopWeight: 1,
      strokeBottomWeight: 1,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  txt(cRow, 'Video Container', { size: 13, wght: 600 });
  const cSeg = frame(cRow, {
    width: 112,
    height: 30,
    name: 'ContainerSeg',
    props: {
      fill: tok('color/paper-well'),
      stroke: tok('color/rule'),
      strokeWeight: 1,
      strokeAlign: 'inside',
      cornerRadius: 4,
      padding: 2,
      layout: 'horizontal',
      gap: 2,
      sizingH: 'fixed',
      sizingV: 'fixed',
    },
  });
  const cMp4 = frame(cSeg, {
    width: 53,
    height: 26,
    name: 'MP4',
    props: {
      fill: tok('color/ink'),
      cornerRadius: 2,
      layout: 'horizontal',
      mainAlign: 'center',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fill',
    },
  });
  txt(cMp4, 'MP4', { size: 11.5, wght: 600, fill: tok('color/accent-ink') });
  const cMkv = frame(cSeg, {
    width: 53,
    height: 26,
    name: 'MKV',
    props: {
      layout: 'horizontal',
      mainAlign: 'center',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fill',
    },
  });
  txt(cMkv, 'MKV', { size: 11.5, wght: 400, fill: tok('color/ink-secondary') });

  const plSubRow = frame(plSheet, {
    width: 372,
    height: 42,
    name: 'home_subtitles_switch',
    props: {
      stroke: tok('color/rule'),
      strokeBottomWeight: 1,
      strokeTopWeight: 0,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  txt(plSubRow, 'Download subtitles (SRT/VTT)', { size: 13, wght: 400 });
  toggleSwitch(plSubRow, false);

  const plSbRow = frame(plSheet, {
    width: 372,
    height: 42,
    name: 'home_sponsorblock_switch',
    props: {
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  txt(plSbRow, 'Remove SponsorBlock segments', { size: 13, wght: 400 });
  toggleSwitch(plSbRow, true);

  button(plSheet, 'Download 2 Selected', 'primary', {
    icon: 'download',
    height: 48,
    fillWidth: true,
  });
}

// ---------------------------------------------------------------------------
// Screen 3b: 03b · Home — Auth Recovery (Clean Instagram Auth Error state)
// ---------------------------------------------------------------------------
{
  const { body } = phoneFrame(3, '03b · Home — Auth Recovery', {
    as: 'scrHomeAuthError',
    hasBottomNav: true,
    activeTab: 0,
    activeCount: 2,
  });
  masthead(body, 'KlipFetch');

  const platBar = frame(body, {
    width: 412,
    height: 40,
    name: 'SupportedRow',
    props: {
      stroke: tok('color/rule'),
      strokeBottomWeight: 1,
      strokeTopWeight: 0,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      padding: [10, 20, 10, 20],
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  txt(platBar, 'Supported', { size: 12, wght: 400, fill: tok('color/ink-muted') });
  const platList = frame(platBar, {
    width: 240,
    height: 20,
    name: 'Platforms',
    props: { layout: 'horizontal', gap: 14, crossAlign: 'center', sizingH: 'hug', sizingV: 'hug' },
  });
  platformMarker(platList, 'TikTok', 'color/platform-tiktok', true);
  platformMarker(platList, 'Instagram', 'color/platform-instagram', true);
  platformMarker(platList, 'YouTube', 'color/platform-youtube', true);

  const section = frame(body, {
    width: 412,
    height: 360,
    name: 'AuthErrorFlow',
    props: {
      padding: [18, 20, 20, 20],
      layout: 'vertical',
      gap: 12,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });

  txt(section, 'Paste media URL', { size: 13, wght: 600 });
  const inp = frame(section, {
    width: 372,
    height: 48,
    name: 'ErrorUrlInput',
    props: {
      fill: tok('color/paper-elevated'),
      stroke: tok('color/status-error'),
      strokeWeight: 1,
      strokeAlign: 'inside',
      cornerRadius: 4,
      padding: [0, 12, 0, 12],
      layout: 'horizontal',
      gap: 10,
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  icon(inp, 'link', 16, tok('color/status-error'));
  txt(inp, 'https://instagram.com/stories/studio_user/', {
    family: 'IBM Plex Mono',
    size: 11.5,
    fill: tok('color/ink'),
    maxLines: 1,
    sizingH: 'fill',
  });
  icon(inp, 'clear', 14, tok('color/ink-muted'));
  icon(inp, 'paste', 16, tok('color/ink-secondary'));

  platformMarker(section, 'Instagram', 'color/platform-instagram', true);

  button(section, 'Fetch Media', 'primary', {
    icon: 'search',
    height: 48,
    fillWidth: true,
  });

  // Uniform 1px error well (no thick left stripe)
  const errWell = frame(section, {
    width: 372,
    height: 110,
    name: 'AuthErrorBanner',
    props: {
      fill: tok('color/status-error-well'),
      stroke: tok('color/status-error-rule'),
      strokeWeight: 1,
      strokeAlign: 'inside',
      cornerRadius: 4,
      padding: [14, 14, 14, 14],
      layout: 'vertical',
      gap: 12,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  const errRow = frame(errWell, {
    width: 344,
    height: 38,
    name: 'ErrorMsgRow',
    props: { layout: 'horizontal', gap: 10, crossAlign: 'min', sizingH: 'fill', sizingV: 'hug' },
  });
  icon(errRow, 'alert', 16, tok('color/status-error'));
  txt(errRow, 'Login cookies required to access this private story or post.', {
    size: 13,
    fill: tok('color/ink'),
    width: 314,
  });
  const errActionRow = frame(errWell, {
    width: 344,
    height: 34,
    name: 'ErrorActionRight',
    props: { layout: 'horizontal', mainAlign: 'max', sizingH: 'fill', sizingV: 'hug' },
  });
  button(errActionRow, 'Sign in to Instagram', 'outlinedDanger', {
    icon: 'key',
    height: 34,
    padH: 14,
    fontSize: 12,
  });
}

// ---------------------------------------------------------------------------
// Screen 4a: 04a · Downloads — Active (Strictly active transfers)
// ---------------------------------------------------------------------------
function renderDownloadsHeader(body, showClear, activeSelected, activeCount, historyCount) {
  masthead(body, 'Downloads', showClear ? 'Clear' : null, 'color/status-error');
  const segWrap = frame(body, {
    width: 412,
    height: 62,
    name: 'QueueFilterWrap',
    props: { padding: [12, 20, 10, 20], layout: 'vertical', sizingH: 'fill', sizingV: 'hug' },
  });
  const seg = frame(segWrap, {
    width: 372,
    height: 40,
    name: 'ActiveHistoryToggle',
    props: {
      fill: tok('color/paper-well'),
      stroke: tok('color/rule'),
      strokeWeight: 1,
      strokeAlign: 'inside',
      cornerRadius: 4,
      padding: 3,
      layout: 'horizontal',
      gap: 3,
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  const sAct = frame(seg, {
    width: 180,
    height: 34,
    name: 'ActiveTab',
    props: {
      fill: activeSelected ? tok('color/ink') : 'none',
      cornerRadius: 2,
      layout: 'horizontal',
      mainAlign: 'center',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fill',
    },
  });
  txt(sAct, `Active (${activeCount})`, {
    size: 13,
    wght: activeSelected ? 600 : 400,
    fill: activeSelected ? tok('color/accent-ink') : tok('color/ink-secondary'),
    features: { tnum: true },
  });
  const sHis = frame(seg, {
    width: 180,
    height: 34,
    name: 'HistoryTab',
    props: {
      fill: !activeSelected ? tok('color/ink') : 'none',
      cornerRadius: 2,
      layout: 'horizontal',
      mainAlign: 'center',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fill',
    },
  });
  txt(sHis, `History (${historyCount})`, {
    size: 13,
    wght: !activeSelected ? 600 : 400,
    fill: !activeSelected ? tok('color/accent-ink') : tok('color/ink-secondary'),
    features: { tnum: true },
  });
}

function renderTransferRow(ledger, opts) {
  const row = frame(ledger, {
    width: 372,
    height: 110,
    name: `QueueRow/${opts.name}`,
    props: {
      stroke: tok('color/rule'),
      strokeBottomWeight: 1,
      strokeTopWeight: 0,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      padding: [14, 0, 14, 0],
      layout: 'vertical',
      gap: 8,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  const top = frame(row, {
    width: 372,
    height: 22,
    name: 'TopMeta',
    props: {
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  const leftM = frame(top, {
    width: 180,
    height: 22,
    name: 'LeftBadges',
    props: { layout: 'horizontal', gap: 8, crossAlign: 'center', sizingH: 'hug', sizingV: 'hug' },
  });
  platformMarker(leftM, opts.platform, opts.platformColor, true);
  squareTag(
    leftM,
    opts.engine,
    opts.fallback ? 'color/status-warn-well' : 'color/paper-well',
    opts.fallback ? 'color/status-warn' : 'color/ink-secondary',
    opts.fallback ? null : 'color/rule',
    !opts.fallback
  );
  txt(top, opts.phase, { size: 12, wght: 600, fill: tok(opts.phaseColor) });

  txt(row, opts.title, { size: 15, wght: 600, width: 372 });

  if (opts.progress !== undefined) {
    const rail = frame(row, {
      width: 372,
      height: 4,
      name: 'ProgressRail',
      props: {
        fill: tok('color/paper-well'),
        layout: 'horizontal',
        sizingH: 'fill',
        sizingV: 'fixed',
      },
    });
    rect(rail, {
      width: Math.round((372 * opts.progress) / 100),
      height: 4,
      name: 'ProgressFill',
      props: { fill: tok('color/accent') },
    });
  }

  if (opts.subline) {
    txt(row, opts.subline, {
      family: opts.subMono ? 'IBM Plex Mono' : 'IBM Plex Sans',
      size: 11.5,
      fill: tok(opts.subColor || 'color/ink-muted'),
      width: 372,
    });
  }

  const foot = frame(row, {
    width: 372,
    height: 24,
    name: 'FooterRow',
    props: {
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  txt(foot, opts.metrics || '', {
    family: 'IBM Plex Mono',
    size: 11.5,
    fill: tok('color/ink-secondary'),
    features: { tnum: true },
  });
  const acts = frame(foot, {
    width: 120,
    height: 24,
    name: 'Actions',
    props: { layout: 'horizontal', gap: 16, crossAlign: 'center', sizingH: 'hug', sizingV: 'hug' },
  });
  for (const a of opts.actions) {
    txt(acts, a.label, { size: 12.5, wght: 600, fill: tok(a.color) });
  }
  if (opts.trashIcon) {
    icon(acts, 'trash', 15, tok('color/status-error'));
  }
}

{
  const { body } = phoneFrame(4, '04a · Downloads — Active', {
    as: 'scrDownloadsActive',
    hasBottomNav: true,
    activeTab: 1,
    activeCount: 2,
  });
  renderDownloadsHeader(body, false, true, 2, 3);

  const ledger = frame(body, {
    width: 412,
    height: 600,
    name: 'ActiveTransferLedger',
    props: { padding: [0, 20, 16, 20], layout: 'vertical', gap: 0, sizingH: 'fill', sizingV: 'hug' },
  });

  renderTransferRow(ledger, {
    name: 'YT_Active',
    platform: 'YouTube',
    platformColor: 'color/platform-youtube',
    engine: 'yt-dlp',
    phase: 'Downloading',
    phaseColor: 'color/accent',
    title: 'Rust FFI on Android: Architecture Deep Dive',
    progress: 68,
    metrics: '68%  4.8 MB/s  18s left  142.4 MB',
    actions: [{ label: 'Cancel', color: 'color/ink-secondary' }],
  });

  renderTransferRow(ledger, {
    name: 'TT_Saving',
    platform: 'TikTok',
    platformColor: 'color/platform-tiktok',
    engine: 'Rust Core',
    phase: 'Saving to Downloads',
    phaseColor: 'color/accent',
    title: 'Kyoto Morning Pour-Over Slideshow',
    progress: 92,
    metrics: '92%  4 files  Best',
    actions: [{ label: 'Cancel', color: 'color/ink-secondary' }],
  });

  const bgNote = frame(ledger, {
    width: 372,
    height: 48,
    name: 'ForegroundNote',
    props: { padding: [14, 0, 0, 0], layout: 'vertical', sizingH: 'fill', sizingV: 'hug' },
  });
  txt(bgNote, 'Active downloads run in a foreground service so transfers continue when the screen turns off.', {
    size: 12,
    fill: tok('color/ink-muted'),
    width: 372,
  });
}

// ---------------------------------------------------------------------------
// Screen 4b: 04b · Downloads — History (Completed, Failed with IG yt-dlp fallback, Cancelled)
// ---------------------------------------------------------------------------
{
  const { body } = phoneFrame(5, '04b · Downloads — History', {
    as: 'scrDownloadsHistory',
    hasBottomNav: true,
    activeTab: 1,
    activeCount: 2,
  });
  renderDownloadsHeader(body, true, false, 2, 3);

  const ledger = frame(body, {
    width: 412,
    height: 600,
    name: 'HistoryTransferLedger',
    props: { padding: [0, 20, 16, 20], layout: 'vertical', gap: 0, sizingH: 'fill', sizingV: 'hug' },
  });

  renderTransferRow(ledger, {
    name: 'IG_Completed',
    platform: 'Instagram',
    platformColor: 'color/platform-instagram',
    engine: 'Rust Core',
    phase: 'Completed',
    phaseColor: 'color/status-ok',
    title: 'Studio Lighting Reel',
    subline: 'Downloads/KlipFetch/Instagram/reel_04.mp4',
    subMono: true,
    subColor: 'color/status-ok',
    metrics: '28.4 MB  1080p',
    actions: [
      { label: 'Open', color: 'color/ink' },
      { label: 'Share', color: 'color/ink-secondary' },
    ],
    trashIcon: true,
  });

  renderTransferRow(ledger, {
    name: 'IG_Failed',
    platform: 'Instagram',
    platformColor: 'color/platform-instagram',
    engine: 'yt-dlp fallback',
    fallback: true,
    phase: 'Failed',
    phaseColor: 'color/status-error',
    title: 'Private Story Archive Clip',
    subline: 'Login cookies required to access this private post.',
    subColor: 'color/status-error',
    metrics: 'Best  MP4',
    actions: [
      { label: 'Retry', color: 'color/accent' },
      { label: 'Remove', color: 'color/status-error' },
    ],
  });

  renderTransferRow(ledger, {
    name: 'TT_Cancelled',
    platform: 'TikTok',
    platformColor: 'color/platform-tiktok',
    engine: 'Rust Core',
    phase: 'Cancelled',
    phaseColor: 'color/ink-muted',
    title: 'Acoustic Guitar Session Clip',
    metrics: 'Audio M4A',
    actions: [
      { label: 'Retry', color: 'color/ink' },
      { label: 'Remove', color: 'color/status-error' },
    ],
  });
}

// ---------------------------------------------------------------------------
// Screen 5: 05 · Settings — Control Ledger (412 x 1220)
// ---------------------------------------------------------------------------
{
  const { body } = phoneFrame(6, '05 · Settings — Control Ledger', {
    as: 'scrSettings',
    height: 1200,
    hasBottomNav: true,
    activeTab: 2,
    activeCount: 2,
  });
  masthead(body, 'Settings', 'v0.1.1', 'color/ink-muted');

  const sList = frame(body, {
    width: 412,
    height: 1060,
    name: 'SettingsSections',
    props: { padding: [14, 20, 24, 20], layout: 'vertical', gap: 16, sizingH: 'fill', sizingV: 'hug' },
  });

  // 1. Appearance (Locked Light Mode kept for widget test contract; styled with uniform #1A1715 active fill)
  const appSec = frame(sList, {
    width: 372,
    height: 98,
    name: 'AppearanceSection',
    props: { layout: 'vertical', gap: 8, sizingH: 'fill', sizingV: 'hug' },
  });
  txt(appSec, 'Appearance', { size: 13, wght: 600 });
  const themeSeg = frame(appSec, {
    width: 372,
    height: 38,
    name: 'ThemeLockSegmented',
    props: {
      fill: tok('color/paper-well'),
      stroke: tok('color/rule'),
      strokeWeight: 1,
      strokeAlign: 'inside',
      cornerRadius: 4,
      padding: 3,
      layout: 'horizontal',
      gap: 3,
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  for (const m of [
    { label: 'System', sel: false },
    { label: 'Dark', sel: false },
    { label: 'Light', sel: true },
  ]) {
    const cell = frame(themeSeg, {
      width: 118,
      height: 32,
      name: `Mode/${m.label}`,
      props: {
        fill: m.sel ? tok('color/ink') : 'none',
        cornerRadius: 2,
        layout: 'horizontal',
        mainAlign: 'center',
        crossAlign: 'center',
        sizingH: 'fill',
        sizingV: 'fill',
      },
    });
    txt(cell, m.label, {
      size: 13,
      wght: m.sel ? 600 : 400,
      fill: m.sel ? tok('color/accent-ink') : tok('color/ink-muted'),
    });
  }
  const lockRow = frame(appSec, {
    width: 372,
    height: 20,
    name: 'settings_theme_locked_caption',
    props: { layout: 'horizontal', gap: 6, crossAlign: 'center', sizingH: 'fill', sizingV: 'hug' },
  });
  icon(lockRow, 'lock', 13, tok('color/ink-muted'));
  txt(lockRow, 'Light Mode is locked. Theme switching is currently disabled.', {
    size: 12,
    fill: tok('color/ink-muted'),
  });

  // 2. Accounts & Cookies row flat on paper (obeys Surface Ladder; synced "1 of 3 platforms connected")
  const accRow = frame(sList, {
    width: 372,
    height: 58,
    name: 'settings_accounts_tile',
    props: {
      stroke: tok('color/rule'),
      strokeTopWeight: 1,
      strokeBottomWeight: 1,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      padding: [10, 0, 10, 0],
      layout: 'horizontal',
      gap: 12,
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  icon(accRow, 'key', 18, tok('color/ink'));
  const accTxt = frame(accRow, {
    width: 280,
    height: 36,
    name: 'AccountsText',
    props: { layout: 'vertical', gap: 2, sizingH: 'fill', sizingV: 'hug' },
  });
  txt(accTxt, 'Accounts & Cookies', { size: 15, wght: 600 });
  txt(accTxt, '1 of 3 platforms connected', {
    size: 12,
    fill: tok('color/ink-muted'),
    features: { tnum: true },
  });
  icon(accRow, 'chevron', 16, tok('color/ink-secondary'));

  // 3. Downloads Ledger
  const dlSec = frame(sList, {
    width: 372,
    height: 460,
    name: 'DownloadsSettingsSection',
    props: {
      stroke: tok('color/ink'),
      strokeTopWeight: 2,
      strokeBottomWeight: 0,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      padding: [12, 0, 0, 0],
      layout: 'vertical',
      gap: 10,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  txt(dlSec, 'Downloads', { size: 14, wght: 600 });
  txt(dlSec, 'Default Video Quality', { size: 12, wght: 400, fill: tok('color/ink-secondary') });

  // 6 quality chips in IBM Plex Sans filling full 372px width evenly
  const qualGrid = frame(dlSec, {
    width: 372,
    height: 30,
    name: 'DefaultQualityChips',
    props: { layout: 'horizontal', gap: 5, sizingH: 'fill', sizingV: 'hug' },
  });
  for (const q of ['2160p', '1440p', '1080p', '720p', '480p', 'Best']) {
    const sel = q === '1080p';
    const c = frame(qualGrid, {
      width: 57,
      height: 30,
      name: `Qual/${q}`,
      props: {
        fill: sel ? tok('color/ink') : tok('color/paper-elevated'),
        ...(sel ? {} : { stroke: tok('color/rule-strong'), strokeWeight: 1, strokeAlign: 'inside' }),
        cornerRadius: 4,
        padding: [0, 4, 0, 4],
        layout: 'horizontal',
        mainAlign: 'center',
        crossAlign: 'center',
        sizingH: 'fill',
        sizingV: 'fixed',
      },
    });
    txt(c, q, {
      family: 'IBM Plex Sans',
      size: 11.5,
      wght: sel ? 600 : 400,
      features: { tnum: true },
      fill: sel ? tok('color/accent-ink') : tok('color/ink'),
    });
  }

  function inlineSegRow(parent, label, options, activeVal) {
    const r = frame(parent, {
      width: 372,
      height: 42,
      name: label,
      props: {
        stroke: tok('color/rule'),
        strokeBottomWeight: 1,
        strokeTopWeight: 0,
        strokeLeftWeight: 0,
        strokeRightWeight: 0,
        strokeAlign: 'inside',
        layout: 'horizontal',
        mainAlign: 'spaceBetween',
        crossAlign: 'center',
        sizingH: 'fill',
        sizingV: 'fixed',
      },
    });
    txt(r, label, { size: 13, wght: 400 });
    const box = frame(r, {
      width: 120,
      height: 28,
      name: 'MiniSeg',
      props: {
        fill: tok('color/paper-well'),
        stroke: tok('color/rule'),
        strokeWeight: 1,
        strokeAlign: 'inside',
        cornerRadius: 4,
        padding: 2,
        layout: 'horizontal',
        gap: 2,
        sizingH: 'hug',
        sizingV: 'fixed',
      },
    });
    for (const opt of options) {
      const active = opt === activeVal;
      const cell = frame(box, {
        width: 44,
        height: 24,
        name: opt,
        props: {
          fill: active ? tok('color/ink') : 'none',
          cornerRadius: 2,
          padding: [0, 8, 0, 8],
          layout: 'horizontal',
          mainAlign: 'center',
          crossAlign: 'center',
          sizingH: 'hug',
          sizingV: 'fill',
        },
      });
      txt(cell, opt, {
        family: 'IBM Plex Sans',
        size: 11.5,
        wght: active ? 600 : 400,
        features: { tnum: true },
        fill: active ? tok('color/accent-ink') : tok('color/ink-secondary'),
      });
    }
  }

  inlineSegRow(dlSec, 'Default Video Container', ['MP4', 'MKV'], 'MP4');
  inlineSegRow(dlSec, 'Default Audio Format', ['M4A', 'MP3', 'OPUS'], 'M4A');
  inlineSegRow(dlSec, 'Concurrent Downloads', ['1', '2', '3'], '2');

  function toggleRow(parent, title, sub, on) {
    const r = frame(parent, {
      width: 372,
      height: 52,
      name: title,
      props: {
        stroke: tok('color/rule'),
        strokeBottomWeight: 1,
        strokeTopWeight: 0,
        strokeLeftWeight: 0,
        strokeRightWeight: 0,
        strokeAlign: 'inside',
        layout: 'horizontal',
        mainAlign: 'spaceBetween',
        crossAlign: 'center',
        gap: 10,
        sizingH: 'fill',
        sizingV: 'fixed',
      },
    });
    const col = frame(r, {
      width: 300,
      height: 36,
      name: 'Txt',
      props: { layout: 'vertical', gap: 2, sizingH: 'fill', sizingV: 'hug' },
    });
    txt(col, title, { size: 13, wght: 400 });
    txt(col, sub, { size: 11.5, fill: tok('color/ink-muted'), maxLines: 1 });
    toggleSwitch(r, on);
  }

  toggleRow(dlSec, 'Auto-retry failed downloads', 'Retries transient errors with backoff', true);
  toggleRow(dlSec, 'Download subtitles (SRT/VTT)', 'Preferred languages: en,id', false);
  toggleRow(dlSec, 'SponsorBlock skip (YouTube)', 'Removes sponsor and self-promo segments', false);
  toggleRow(dlSec, 'Include TikTok slideshow audio', 'Saves background music alongside slideshows', true);

  // 4. yt-dlp Engine (single consolidated Check & Update control)
  const engSec = frame(sList, {
    width: 372,
    height: 120,
    name: 'YtDlpEngineSection',
    props: {
      stroke: tok('color/ink'),
      strokeTopWeight: 2,
      strokeBottomWeight: 0,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      padding: [12, 0, 0, 0],
      layout: 'vertical',
      gap: 10,
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  const engTop = frame(engSec, {
    width: 372,
    height: 22,
    name: 'EngineVerRow',
    props: {
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  txt(engTop, 'yt-dlp Engine', { size: 14, wght: 600 });
  txt(engTop, 'Installed 2026.11.01', { family: 'IBM Plex Mono', size: 11.5, fill: tok('color/ink-secondary') });

  inlineSegRow(engSec, 'Update channel', ['Stable', 'Nightly'], 'Stable');
  button(engSec, 'Update yt-dlp', 'outlinedInk', { height: 40, fillWidth: true });

  const sysSec = frame(sList, {
    width: 372,
    height: 180,
    name: 'StorageAndAbout',
    props: { layout: 'vertical', gap: 10, sizingH: 'fill', sizingV: 'hug' },
  });
  const permRow = frame(sysSec, {
    width: 372,
    height: 48,
    name: 'NotificationPerm',
    props: {
      stroke: tok('color/rule'),
      strokeBottomWeight: 1,
      strokeTopWeight: 0,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  const pCol = frame(permRow, {
    width: 260,
    height: 36,
    name: 'PermTxt',
    props: { layout: 'vertical', gap: 1, sizingH: 'fill', sizingV: 'hug' },
  });
  txt(pCol, 'Notification Permission', { size: 13, wght: 400 });
  txt(pCol, 'Required on Android 13+ for foreground progress', { size: 11, fill: tok('color/ink-muted') });
  button(permRow, 'Grant', 'outlinedInk', { height: 30, padH: 12, fontSize: 12 });

  const locRow = frame(sysSec, {
    width: 372,
    height: 48,
    name: 'SaveLocation',
    props: {
      stroke: tok('color/rule'),
      strokeBottomWeight: 1,
      strokeTopWeight: 0,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      strokeAlign: 'inside',
      layout: 'vertical',
      gap: 2,
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  txt(locRow, 'Saved Downloads Location', { size: 13, wght: 400 });
  txt(locRow, 'Downloads/KlipFetch/{TikTok,Instagram,YouTube}', {
    family: 'IBM Plex Mono',
    size: 11,
    fill: tok('color/ink-secondary'),
  });

  txt(
    sysSec,
    'KlipFetch v0.1.1 (GNU GPL v3.0). Powered by libreget-core, yt-dlp, youtubedl-android, FFmpeg, and Flutter Rust Bridge.',
    { size: 11.5, lineHeight: 16, fill: tok('color/ink-muted'), width: 372 }
  );
}

// ---------------------------------------------------------------------------
// Screen 6a: 06a · Accounts & Cookies
// ---------------------------------------------------------------------------
{
  const { body } = phoneFrame(7, '06a · Accounts & Cookies', {
    as: 'scrAccounts',
    hasBottomNav: false,
  });

  const appBarWrap = frame(body, {
    width: 412,
    height: 54,
    name: 'AccountsAppBarWrap',
    props: { layout: 'vertical', gap: 0, sizingH: 'fill', sizingV: 'hug' },
  });
  const appBar = frame(appBarWrap, {
    width: 412,
    height: 52,
    name: 'AccountsAppBar',
    props: {
      padding: [10, 20, 12, 16],
      layout: 'horizontal',
      gap: 12,
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  icon(appBar, 'back', 18, tok('color/ink'));
  txt(appBar, 'Accounts & Cookies', {
    family: 'Bricolage Grotesque',
    size: 23,
    lineHeight: 26,
    wdth: 78,
    wght: 800,
    letterSpacing: -0.3,
  });
  divider(appBarWrap, 2, tok('color/ink'), 'AccountsHeavyRule');

  const content = frame(body, {
    width: 412,
    height: 780,
    name: 'AccountsBody',
    props: { padding: [16, 20, 20, 20], layout: 'vertical', gap: 14, sizingH: 'fill', sizingV: 'hug' },
  });

  // Uniform 1px hairline well (no thick left stripe)
  const priv = frame(content, {
    width: 372,
    height: 74,
    name: 'PrivacyNotice',
    props: {
      fill: tok('color/paper-well'),
      stroke: tok('color/rule'),
      strokeWeight: 1,
      strokeAlign: 'inside',
      cornerRadius: 4,
      padding: [12, 14, 12, 14],
      layout: 'horizontal',
      gap: 10,
      crossAlign: 'min',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  icon(priv, 'shield', 16, tok('color/ink'));
  txt(
    priv,
    'Sign in via Android WebView to capture HttpOnly session cookies for Stories, private posts, and age-restricted videos. Stored only in app-private storage.',
    { size: 12, fill: tok('color/ink-secondary'), width: 314 }
  );

  function authRow(opts) {
    const r = frame(content, {
      width: 372,
      height: 120,
      name: `auth_card_${opts.id}`,
      props: {
        stroke: tok('color/rule'),
        strokeBottomWeight: 1,
        strokeTopWeight: 0,
        strokeLeftWeight: 0,
        strokeRightWeight: 0,
        strokeAlign: 'inside',
        padding: [8, 0, 16, 0],
        layout: 'vertical',
        gap: 8,
        sizingH: 'fill',
        sizingV: 'hug',
      },
    });
    const head = frame(r, {
      width: 372,
      height: 24,
      name: 'Head',
      props: {
        layout: 'horizontal',
        mainAlign: 'spaceBetween',
        crossAlign: 'center',
        sizingH: 'fill',
        sizingV: 'hug',
      },
    });
    platformMarker(head, opts.label, opts.colorVar, false);
    squareTag(head, opts.status, opts.statusFill, opts.statusInk);

    txt(r, opts.note, {
      family: opts.noteMono ? 'IBM Plex Mono' : 'IBM Plex Sans',
      size: 12,
      fill: tok('color/ink-secondary'),
      width: 372,
    });

    if (opts.testMsg) {
      txt(r, opts.testMsg, { size: 12, wght: 600, fill: tok('color/status-ok') });
    }

    // Uniform aligned 34px bordered button row (no mixed borderless text links vs boxes, no competing black fill)
    const acts = frame(r, {
      width: 372,
      height: 34,
      name: 'Actions',
      props: { layout: 'horizontal', gap: 8, crossAlign: 'center', sizingH: 'fill', sizingV: 'hug' },
    });
    button(acts, opts.primaryLabel, opts.primaryStyle, { height: 34, padH: 14, fontSize: 12 });
    button(acts, 'Test', 'outlined', { height: 34, padH: 12, fontSize: 12, disabled: opts.disableTest });
    button(acts, 'Import', 'outlinedMuted', { height: 34, padH: 12, fontSize: 12 });
    if (opts.hasClear) {
      button(acts, 'Clear', 'outlinedDanger', { height: 34, padH: 12, fontSize: 12 });
    }
  }

  authRow({
    id: 'instagram',
    label: 'Instagram',
    colorVar: 'color/platform-instagram',
    status: 'Connected',
    statusFill: 'color/status-ok-well',
    statusInk: 'color/status-ok',
    note: '14 cookies saved in instagram.com',
    noteMono: true,
    testMsg: 'Session verified (14 cookies active)',
    primaryLabel: 'Re-auth',
    primaryStyle: 'outlinedInk',
    disableTest: false,
    hasClear: true,
  });

  authRow({
    id: 'tiktok',
    label: 'TikTok',
    colorVar: 'color/platform-tiktok',
    status: 'Incomplete',
    statusFill: 'color/status-warn-well',
    statusInk: 'color/status-warn',
    note: '3 cookies saved in tiktok.com',
    noteMono: true,
    primaryLabel: 'Sign In',
    primaryStyle: 'outlinedInk',
    disableTest: false,
    hasClear: true,
  });

  authRow({
    id: 'youtube',
    label: 'YouTube',
    colorVar: 'color/platform-youtube',
    status: 'Not signed in',
    statusFill: 'color/paper-well',
    statusInk: 'color/ink-muted',
    note: 'Helps with age-restricted videos and signed-in YouTube feeds.',
    primaryLabel: 'Sign In',
    primaryStyle: 'primary',
    disableTest: true,
    hasClear: false,
  });
}

// ---------------------------------------------------------------------------
// Screen 6b: 06b · Native Auth WebView (AuthWebViewActivity.kt)
// Authentic white third-party web viewport + consistent logged-in state + separated progress rule
// ---------------------------------------------------------------------------
{
  const { body } = phoneFrame(8, '06b · Native Auth WebView', {
    as: 'scrWebView',
    hasBottomNav: false,
    statusFill: 'color/paper-elevated',
  });

  const toolbarWrap = frame(body, {
    width: 412,
    height: 62,
    name: 'NativeToolbarWrap',
    props: { layout: 'vertical', gap: 0, sizingH: 'fill', sizingV: 'hug' },
  });
  const toolbar = frame(toolbarWrap, {
    width: 412,
    height: 60,
    name: 'NativeWebViewToolbar',
    props: {
      fill: tok('color/paper-elevated'),
      padding: [8, 12, 8, 10],
      layout: 'horizontal',
      gap: 8,
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'fixed',
    },
  });
  const closeBtn = frame(toolbar, {
    width: 32,
    height: 32,
    name: 'CloseBtn',
    props: { layout: 'horizontal', mainAlign: 'center', crossAlign: 'center', sizingH: 'fixed', sizingV: 'fixed' },
  });
  icon(closeBtn, 'clear', 16, tok('color/ink-secondary'));

  const tCol = frame(toolbar, {
    width: 196,
    height: 40,
    name: 'TitleAndStatus',
    props: { layout: 'vertical', gap: 1, sizingH: 'fill', sizingV: 'hug' },
  });
  txt(tCol, 'Sign in to Instagram', { size: 15, wght: 600, maxLines: 1 });
  txt(tCol, '14 cookies ready. Tap Save Session.', {
    size: 11.5,
    wght: 600,
    fill: tok('color/status-ok'),
    maxLines: 1,
  });

  const reloadBtn = frame(toolbar, {
    width: 32,
    height: 32,
    name: 'ReloadBtn',
    props: { layout: 'horizontal', mainAlign: 'center', crossAlign: 'center', sizingH: 'fixed', sizingV: 'fixed' },
  });
  icon(reloadBtn, 'refresh', 16, tok('color/ink-secondary'));

  button(toolbar, 'Save Session', 'primary', { height: 36, padH: 12, fontSize: 12 });
  divider(toolbarWrap, 2, tok('color/ink'), 'ToolbarHeavyRule');

  // 3dp progress bar separated cleanly BELOW the 2px toolbar rule
  const prog = frame(body, {
    width: 412,
    height: 3,
    name: 'WebViewProgressBar',
    props: { fill: tok('color/paper-well'), layout: 'horizontal', sizingH: 'fill', sizingV: 'fixed' },
  });
  rect(prog, { width: 412, height: 3, name: 'ProgressComplete', props: { fill: tok('color/accent') } });

  // Authentic third-party white mobile web viewport (post-login session state matching "14 cookies ready")
  const webCanvas = frame(body, {
    width: 412,
    height: 816,
    name: 'EmbeddedMobileWebView',
    props: {
      fill: '#FFFFFF',
      padding: [24, 24, 24, 24],
      layout: 'vertical',
      gap: 20,
      sizingH: 'fill',
      sizingV: 'fill',
    },
  });

  const webHeader = frame(webCanvas, {
    width: 364,
    height: 36,
    name: 'ThirdPartyWebBar',
    props: {
      stroke: '#EFEFEF',
      strokeBottomWeight: 1,
      strokeTopWeight: 0,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
      padding: [0, 0, 12, 0],
      layout: 'horizontal',
      mainAlign: 'spaceBetween',
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  txt(webHeader, 'Instagram', {
    family: 'Helvetica Neue',
    size: 20,
    fill: '#262626',
  });
  txt(webHeader, '@studio_archive', {
    family: 'Helvetica Neue',
    size: 13,
    fill: '#737373',
  });

  const signedInCard = frame(webCanvas, {
    width: 364,
    height: 150,
    name: 'WebSessionConfirmation',
    props: {
      fill: '#FAFAFA',
      stroke: '#DBDBDB',
      strokeWeight: 1,
      cornerRadius: 6,
      padding: [24, 20, 24, 20],
      layout: 'vertical',
      gap: 10,
      crossAlign: 'center',
      sizingH: 'fill',
      sizingV: 'hug',
    },
  });
  txt(signedInCard, 'Signed in as @studio_archive', {
    family: 'Helvetica Neue',
    size: 16,
    fill: '#262626',
    align: 'center',
  });
  txt(signedInCard, 'Your mobile session is active inside this page. Tap Save Session in the bar above to finish.', {
    family: 'Helvetica Neue',
    size: 13,
    fill: '#737373',
    align: 'center',
    width: 310,
  });
}

// ---------------------------------------------------------------------------
// 4. In-session Exports (guarantees Bricolage Grotesque, IBM Plex Sans, IBM Plex Mono render cleanly!)
// ---------------------------------------------------------------------------
cmd('page.select', { index: 0 });
for (const [refName, fileName] of [
  ['sysColorFrame', '01 · Color & Surface Ladder.png'],
  ['sysTypeFrame', '02 · Typography & Controls.png'],
  ['sysIconFrame', '03 · KlipFetch Launcher Icon.png'],
]) {
  cmd('file.export', {
    ids: [{ $ref: refName }],
    format: 'png',
    scale: 2,
    path: path.join(rendersDir, 'system', fileName),
  });
}
cmd('file.export', {
  ids: [{ $ref: 'iconVectorFrame' }],
  format: 'xml',
  path: path.join(rendersDir, 'ic_klipfetch_foreground.xml'),
});
cmd('file.export', {
  ids: [{ $ref: 'iconMonoFrame' }],
  format: 'xml',
  path: path.join(rendersDir, 'ic_klipfetch_monochrome.xml'),
});

cmd('page.select', { index: 1 });
for (const s of screenRefs) {
  cmd('file.export', {
    ids: [s.ref],
    format: 'png',
    scale: 2,
    path: path.join(rendersDir, 'screens', `${s.title}.png`),
  });
}
cmd('file.export', {
  format: 'png',
  scale: 1,
  path: path.join(rendersDir, 'all_screens_overview.png'),
});

const outPath = path.join(root, 'design', 'klipfetch_commands.json');
fs.writeFileSync(outPath, JSON.stringify(cmds, null, 2));
console.log(`Generated ${cmds.length} FigCraft commands -> ${outPath}`);

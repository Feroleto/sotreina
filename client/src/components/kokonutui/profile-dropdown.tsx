/**
 * @author: @dorianbaffier
 * @description: Account Menu
 * @version: 2.0.0
 * @date: 2026-10-14
 * @license: MIT
 * @website: https://kokonutui.com
 * @github: https://github.com/kokonut-labs/kokonutui
 *
 * Adapted for SoTreina (.plans/profile-dropdown-mobile-spec.md): a single
 * account (no status, account switching or billing), an avatar-only
 * trigger, theme + language rows, one Settings entry, Monolito tokens
 * instead of zinc, and no `layoutId` — the app's LazyMotion only loads
 * `domAnimation`, so the avatar's trip from trigger to header is a manual
 * FLIP on motion values and the segmented indicators slide in CSS
 */

import {
  ChevronRight,
  LogOut,
  Monitor,
  Moon,
  Settings,
  Sun,
} from 'lucide-react';
import {
  animate,
  m,
  type Transition,
  useMotionTemplate,
  useMotionValue,
  useReducedMotion,
} from 'motion/react';
import {
  type KeyboardEvent,
  type MouseEvent,
  type PointerEvent,
  type ReactNode,
  useEffect,
  useId,
  useLayoutEffect,
  useRef,
  useState,
} from 'react';
import { cn } from '@/lib/utils';
import type { ThemePref } from '@/lib/theme';
import type { AppLanguage } from '@/i18n';
import { ProfileAvatar, TRIGGER_CLASS } from './profile-avatar';

export interface ProfileDropdownLabels {
  menu: string;
  theme: string;
  themeAuto: string;
  themeLight: string;
  themeDark: string;
  language: string;
  settings: string;
  signOut: string;
  hold: string;
  keepHolding: string;
  /** screen-reader suffix on Sign out, e.g. ", press and hold to confirm" */
  holdHint: string;
}

interface ProfileDropdownProps {
  name: string;
  /** second header line: the email, or a fallback for email-less accounts */
  secondary: string;
  avatarUrl?: string | null;
  initials: string;
  theme: ThemePref;
  onThemeChange: (theme: ThemePref) => void;
  language: AppLanguage;
  onLanguageChange: (language: AppLanguage) => void;
  onSettings: () => void;
  /** called once Sign out has been held for `holdDuration` ms */
  onSignOut: () => void;
  labels: ProfileDropdownLabels;
  /** open on mount — the header mounts this lazily on the first tap */
  defaultOpen?: boolean;
  holdDuration?: number;
  className?: string;
}

const PANEL_W = 288;
const RADIUS = 16;
const TRIGGER_AVATAR = 34;
const HEAD_AVATAR = 40;
const SEG_W = 36;
const SPRING: Transition = { type: 'spring', duration: 0.3, bounce: 0 };
const EASE_OUT = [0.23, 1, 0.32, 1] as const;
const NAV_KEYS = new Set([
  'ArrowDown',
  'ArrowUp',
  'ArrowLeft',
  'ArrowRight',
  'Home',
  'End',
]);

const ITEM_CLASS =
  'flex w-full cursor-pointer items-center gap-2.5 rounded-[10px] px-2.5 py-2 text-left text-sm text-foreground/80 outline-none transition-colors duration-100 focus:bg-chip focus:text-foreground';

type Phase = 'closed' | 'open' | 'closing';
type Via = 'pointer' | 'keyboard';

function viaOf(event: MouseEvent): Via {
  // a click fired by Enter or Space carries no pointer detail
  return event.detail === 0 ? 'keyboard' : 'pointer';
}

function menuItems(root: HTMLElement | null) {
  if (!root) return [];
  return Array.from(root.querySelectorAll<HTMLElement>('[data-menu-item]'));
}

function sideTarget(items: HTMLElement[], current: HTMLElement, step: number) {
  const row = items.filter((item) => item.dataset.row === current.dataset.row);
  if (row.length < 2) return;
  const index = row.indexOf(current);
  return row[(index + step + row.length) % row.length];
}

function rowTarget(items: HTMLElement[], current: HTMLElement, step: number) {
  const rows = [...new Set(items.map((item) => item.dataset.row))];
  const index = rows.indexOf(current.dataset.row);
  const next = rows[(index + step + rows.length) % rows.length];
  const candidates = items.filter((item) => item.dataset.row === next);
  return (
    candidates.find((item) => item.getAttribute('aria-checked') === 'true') ??
    candidates[0]
  );
}

/** where arrow keys move focus: rows go up and down, radios left and right */
function nextTarget(
  items: HTMLElement[],
  active: Element | null,
  key: string,
): HTMLElement | undefined {
  if (key === 'Home') return items[0];
  if (key === 'End') return items.at(-1);
  const current = items.find((item) => item === active);
  if (!current) return key === 'ArrowUp' ? items.at(-1) : items[0];
  if (key === 'ArrowLeft' || key === 'ArrowRight') {
    return sideTarget(items, current, key === 'ArrowRight' ? 1 : -1);
  }
  return rowTarget(items, current, key === 'ArrowDown' ? 1 : -1);
}

function Separator() {
  return <hr className="mx-2.5 my-1.5 h-px border-0 bg-border" />;
}

function HoldSignOut({
  duration,
  labels,
  onComplete,
}: {
  duration: number;
  labels: ProfileDropdownLabels;
  onComplete: (via: Via) => void;
}) {
  const [holding, setHolding] = useState(false);
  const [done, setDone] = useState(false);
  const [nudge, setNudge] = useState(false);
  const timer = useRef<number | undefined>(undefined);
  const nudgeTimer = useRef<number | undefined>(undefined);

  useEffect(
    () => () => {
      window.clearTimeout(timer.current);
      window.clearTimeout(nudgeTimer.current);
    },
    [],
  );

  const start = (via: Via) => {
    if (timer.current !== undefined || done) return;
    window.clearTimeout(nudgeTimer.current);
    setNudge(false);
    setHolding(true);
    timer.current = window.setTimeout(() => {
      timer.current = undefined;
      setHolding(false);
      setDone(true);
      onComplete(via);
    }, duration);
  };

  const cancel = () => {
    if (timer.current === undefined) return;
    window.clearTimeout(timer.current);
    timer.current = undefined;
    setHolding(false);
    setNudge(true);
    nudgeTimer.current = window.setTimeout(() => setNudge(false), 1400);
  };

  const label = (
    <>
      <LogOut className="size-4" strokeWidth={1.8} />
      <span className="flex-1">{labels.signOut}</span>
      <span className="text-xs opacity-60">
        {nudge ? labels.keepHolding : labels.hold}
      </span>
    </>
  );

  return (
    <button
      className={cn(
        ITEM_CLASS,
        'relative touch-none select-none [-webkit-touch-callout:none]',
      )}
      data-menu-item=""
      data-row="sign-out"
      onBlur={cancel}
      onClick={(event) => event.preventDefault()}
      onContextMenu={(event) => event.preventDefault()}
      onKeyDown={(event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          if (!event.repeat) start('keyboard');
        }
      }}
      onKeyUp={(event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          cancel();
        }
      }}
      onPointerCancel={cancel}
      onPointerDown={(event) => {
        if (event.button !== 0) return;
        event.currentTarget.setPointerCapture(event.pointerId);
        start('pointer');
      }}
      onPointerUp={cancel}
      role="menuitem"
      tabIndex={-1}
      type="button"
    >
      {label}
      <span className="sr-only">{labels.holdHint}</span>
      {/* the fill: an inverted copy of the row, revealed left to right. The
          linear fill while holding is the gesture's feedback and stays under
          reduced motion; only the snap-back is gated */}
      <span
        aria-hidden="true"
        className={cn(
          'absolute inset-0 flex items-center gap-2.5 rounded-[10px] bg-foreground px-2.5 text-background',
          !holding && 'motion-reduce:!transition-none',
        )}
        style={{
          clipPath:
            holding || done
              ? 'inset(0 0 0 0 round 10px)'
              : 'inset(0 100% 0 0 round 10px)',
          transition: holding
            ? `clip-path ${duration}ms linear`
            : 'clip-path 240ms cubic-bezier(0.23, 1, 0.32, 1)',
        }}
      >
        {label}
      </span>
    </button>
  );
}

/**
 * label + segmented radios (theme icons, language codes). The indicator is
 * one span sliding by the checked index — equal-width buttons make that a
 * plain translateX
 */
function SegmentRow<T extends string>({
  label,
  row,
  options,
  value,
  onChange,
}: {
  label: string;
  row: string;
  options: { id: T; label: string; content: ReactNode }[];
  value: T;
  onChange: (next: T) => void;
}) {
  const index = Math.max(
    0,
    options.findIndex((o) => o.id === value),
  );
  return (
    <fieldset
      aria-label={label}
      className="m-0 flex min-w-0 items-center justify-between border-0 py-1 pr-1 pl-2.5"
    >
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className="relative flex rounded-[10px] bg-chip p-0.5">
        <span
          aria-hidden="true"
          className="absolute top-0.5 left-0.5 h-7 rounded-lg bg-card shadow-[0_1px_2px_rgb(0_0_0/0.08)] motion-safe:transition-transform motion-safe:duration-[250ms] motion-safe:ease-[cubic-bezier(0.23,1,0.32,1)]"
          style={{ width: SEG_W, transform: `translateX(${index * SEG_W}px)` }}
        />
        {options.map((option) => {
          const checked = option.id === value;
          return (
            <button
              aria-checked={checked}
              aria-label={option.label}
              className="relative grid h-7 cursor-pointer place-items-center rounded-lg text-xs font-medium text-muted-foreground outline-none transition-colors duration-150 hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring aria-checked:text-foreground"
              style={{ width: SEG_W }}
              data-menu-item=""
              data-row={row}
              key={option.id}
              onClick={() => onChange(option.id)}
              role="menuitemradio"
              tabIndex={-1}
              type="button"
            >
              {option.content}
            </button>
          );
        })}
      </span>
    </fieldset>
  );
}

export default function ProfileDropdown({
  name,
  secondary,
  avatarUrl,
  initials,
  theme,
  onThemeChange,
  language,
  onLanguageChange,
  onSettings,
  onSignOut,
  labels,
  defaultOpen = false,
  holdDuration = 1200,
  className,
}: ProfileDropdownProps) {
  const uid = useId();
  const reduced = useReducedMotion() === true;
  const [phase, setPhase] = useState<Phase>('closed');
  const [openSeq, setOpenSeq] = useState(0);

  const wrapperRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const trigAvatarRef = useRef<HTMLSpanElement>(null);
  const headAvatarRef = useRef<HTMLSpanElement>(null);
  const mainRef = useRef<HTMLDivElement>(null);
  // mirrors `phase` for handlers and observers; written only through `go`
  const phaseRef = useRef<Phase>('closed');
  const openIntent = useRef<{
    via: Via;
    focus: 'first' | 'last' | 'menu';
    resume: boolean;
  }>({ via: 'pointer', focus: 'menu', resume: false });
  const closeSeq = useRef(0);
  const targetH = useRef(0);

  // the panel's visible box. Both surface layers (border and fill) and the
  // content clip to it, so the menu grows out of the trigger avatar's own
  // circle without any layout work per frame. `top`/`r` start at the
  // avatar's offset/radius inside the 44px trigger
  const w = useMotionValue(0);
  const h = useMotionValue(0);
  const top = useMotionValue(0);
  const r = useMotionValue(RADIUS);
  const bodyOpacity = useMotionValue(1);
  // the header avatar's FLIP: from the trigger avatar's box to its own
  const ax = useMotionValue(0);
  const ay = useMotionValue(0);
  const aScale = useMotionValue(1);
  const outerClip = useMotionTemplate`inset(${top}px 0px calc(100% - ${h}px) calc(100% - ${w}px) round ${r}px)`;
  const innerClip = useMotionTemplate`inset(calc(${top}px + 1px) 1px calc(100% - ${h}px + 1px) calc(100% - ${w}px + 1px) round calc(${r}px - 1px))`;

  const go = (next: Phase) => {
    phaseRef.current = next;
    setPhase(next);
  };

  const menuId = `${uid}-menu`;
  const open = phase === 'open';

  /** the trigger avatar's box, in the panel's (= wrapper's) coordinates */
  const startBox = () => {
    const avatar = trigAvatarRef.current;
    if (!avatar) return { top: 0, w: 44, h: 44, r: 22 };
    return {
      top: avatar.offsetTop,
      w: avatar.offsetWidth,
      h: avatar.offsetTop + avatar.offsetHeight,
      r: avatar.offsetWidth / 2,
    };
  };

  /** translate/scale that puts the header avatar over the trigger avatar */
  const avatarDelta = () => {
    const from = trigAvatarRef.current?.getBoundingClientRect();
    const to = headAvatarRef.current?.getBoundingClientRect();
    if (!from || !to || to.width === 0) return { x: 0, y: 0, s: 1 };
    return {
      x: from.left - to.left,
      y: from.top - to.top,
      s: from.width / to.width,
    };
  };

  const openMenu = (via: Via, focus: 'first' | 'last' | 'menu') => {
    if (phaseRef.current === 'open') return;
    openIntent.current = { via, focus, resume: phaseRef.current === 'closing' };
    closeSeq.current += 1;
    go('open');
    setOpenSeq((seq) => seq + 1);
  };

  const closeMenu = (via: Via, returnFocus: boolean) => {
    if (phaseRef.current !== 'open') return;
    if (returnFocus) triggerRef.current?.focus({ preventScroll: true });
    if (via === 'keyboard' || reduced) {
      go('closed');
      return;
    }
    go('closing');
    const seq = ++closeSeq.current;
    const box = startBox();
    const delta = avatarDelta();
    animate(bodyOpacity, 0, { duration: 0.12, ease: EASE_OUT });
    animate(ax, delta.x, SPRING);
    animate(ay, delta.y, SPRING);
    animate(aScale, delta.s, SPRING);
    animate(top, box.top, SPRING);
    animate(r, box.r, SPRING);
    animate(w, box.w, SPRING);
    animate(h, box.h, SPRING).then(() => {
      if (closeSeq.current === seq) go('closed');
    });
  };

  // opening: size the clip to the trigger avatar, then spring it out to the
  // menu. A keyboard (or reduced-motion) open skips straight to the end
  // runs once per open
  useLayoutEffect(() => {
    const main = mainRef.current;
    if (openSeq === 0 || phaseRef.current !== 'open' || !main) return;
    targetH.current = main.offsetHeight;
    const instant = openIntent.current.via === 'keyboard' || reduced;
    if (instant) {
      w.jump(PANEL_W);
      h.jump(targetH.current);
      top.jump(0);
      r.jump(RADIUS);
      ax.jump(0);
      ay.jump(0);
      aScale.jump(1);
      bodyOpacity.jump(1);
    } else {
      if (!openIntent.current.resume) {
        const box = startBox();
        const delta = avatarDelta();
        w.jump(box.w);
        h.jump(box.h);
        top.jump(box.top);
        r.jump(box.r);
        ax.jump(delta.x);
        ay.jump(delta.y);
        aScale.jump(delta.s);
        bodyOpacity.jump(0);
      }
      animate(w, PANEL_W, SPRING);
      animate(h, targetH.current, SPRING);
      animate(top, 0, SPRING);
      animate(r, RADIUS, SPRING);
      animate(ax, 0, SPRING);
      animate(ay, 0, SPRING);
      animate(aScale, 1, SPRING);
      animate(bodyOpacity, 1, { duration: 0.2, delay: 0.05, ease: EASE_OUT });
    }
    const list = menuItems(main);
    const targets = {
      first: list[0],
      last: list.at(-1),
      menu: main.querySelector<HTMLElement>('[role=menu]'),
    };
    targets[openIntent.current.focus]?.focus({ preventScroll: true });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [openSeq]);

  // mounted lazily by the first tap on the header's placeholder avatar:
  // finish that tap by opening right away
  // mount only
  useEffect(() => {
    if (defaultOpen) openMenu('pointer', 'menu');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // keep the height in step when the content resizes while open — switching
  // the language re-flows every label
  // observer reads refs
  useEffect(() => {
    if (phase !== 'open') return;
    const observer = new ResizeObserver(() => {
      const el = mainRef.current;
      if (!el || phaseRef.current !== 'open') return;
      const next = el.offsetHeight;
      if (Math.abs(next - targetH.current) < 0.5) return;
      targetH.current = next;
      if (reduced) h.jump(next);
      else animate(h, next, SPRING);
    });
    if (mainRef.current) observer.observe(mainRef.current);
    return () => observer.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase]);

  // a press anywhere outside closes, with the morph
  // closeMenu reads refs
  useEffect(() => {
    if (phase !== 'open') return;
    const onDown = (event: globalThis.PointerEvent) => {
      if (!wrapperRef.current?.contains(event.target as Node)) {
        closeMenu('pointer', false);
      }
    };
    document.addEventListener('pointerdown', onDown, true);
    return () => document.removeEventListener('pointerdown', onDown, true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase]);

  const onPanelKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.key === 'Escape' || event.key === 'Tab') {
      event.preventDefault();
      closeMenu('keyboard', true);
      return;
    }
    if (!NAV_KEYS.has(event.key)) return;
    event.preventDefault();
    const target = nextTarget(
      menuItems(mainRef.current),
      document.activeElement,
      event.key,
    );
    target?.focus({ preventScroll: true });
  };

  // hovering an item focuses it, so pointer and keyboard share one highlight
  const onPanelPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    if (event.pointerType !== 'mouse') return;
    const item = (event.target as HTMLElement).closest<HTMLElement>(
      '[data-menu-item]',
    );
    if (item && document.activeElement !== item) {
      item.focus({ preventScroll: true });
    }
  };

  return (
    <div
      className={cn(
        'relative isolate inline-block',
        phase !== 'closed' && 'z-50',
        className,
      )}
      ref={wrapperRef}
    >
      <button
        aria-controls={open ? menuId : undefined}
        aria-expanded={open}
        aria-haspopup="menu"
        aria-label={labels.menu}
        className={TRIGGER_CLASS}
        onClick={(event) => {
          const via = viaOf(event);
          openMenu(via, via === 'keyboard' ? 'first' : 'menu');
        }}
        onKeyDown={(event) => {
          if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
            event.preventDefault();
            openMenu('keyboard', event.key === 'ArrowDown' ? 'first' : 'last');
          }
        }}
        ref={triggerRef}
        type="button"
      >
        {/* hidden while the header's copy stands in for it */}
        <span
          ref={trigAvatarRef}
          className={cn('block', phase !== 'closed' && 'invisible')}
        >
          <ProfileAvatar
            url={avatarUrl}
            initials={initials}
            className="text-[12px]"
            size={TRIGGER_AVATAR}
          />
        </span>
      </button>

      {phase === 'closed' ? null : (
        <div
          className="pointer-events-none absolute top-0 right-0 z-10"
          style={{ width: PANEL_W }}
        >
          <div
            aria-hidden="true"
            className="absolute inset-0 [filter:drop-shadow(0_12px_24px_rgb(0_0_0/0.08))_drop-shadow(0_2px_4px_rgb(0_0_0/0.04))] dark:[filter:drop-shadow(0_12px_28px_rgb(0_0_0/0.5))]"
          >
            <m.div
              className="absolute inset-0 bg-border"
              style={{ clipPath: outerClip }}
            />
            <m.div
              className="absolute inset-0 bg-card"
              style={{ clipPath: innerClip }}
            />
          </div>
          <m.div
            className={cn('relative', open && 'pointer-events-auto')}
            onKeyDown={onPanelKeyDown}
            onPointerMove={onPanelPointerMove}
            style={{ clipPath: innerClip }}
          >
            <div className="p-1.5" ref={mainRef} style={{ width: PANEL_W }}>
              <div className="flex min-w-0 flex-col items-start gap-3 px-2.5 pt-2.5 pb-3">
                {/* measured untransformed; the inner span carries the FLIP */}
                <span ref={headAvatarRef} className="block">
                  <m.span
                    className="relative z-20 block"
                    style={{
                      x: ax,
                      y: ay,
                      scale: aScale,
                      transformOrigin: '0 0',
                    }}
                  >
                    <ProfileAvatar
                      url={avatarUrl}
                      initials={initials}
                      className="text-[14px]"
                      size={HEAD_AVATAR}
                    />
                  </m.span>
                </span>
                <m.span
                  className="flex w-full min-w-0 flex-col text-left"
                  style={{ opacity: bodyOpacity }}
                >
                  <span className="block truncate text-sm leading-5 font-semibold text-foreground">
                    {name}
                  </span>
                  <span className="block truncate text-xs leading-4 text-muted-foreground">
                    {secondary}
                  </span>
                </m.span>
              </div>
              <m.div
                aria-label={name}
                className="outline-none"
                id={menuId}
                role="menu"
                style={{ opacity: bodyOpacity }}
                tabIndex={-1}
              >
                <SegmentRow<ThemePref>
                  label={labels.theme}
                  row="theme"
                  value={theme}
                  onChange={onThemeChange}
                  options={[
                    {
                      id: 'auto',
                      label: labels.themeAuto,
                      content: <Monitor className="size-3.5" />,
                    },
                    {
                      id: 'light',
                      label: labels.themeLight,
                      content: <Sun className="size-3.5" />,
                    },
                    {
                      id: 'dark',
                      label: labels.themeDark,
                      content: <Moon className="size-3.5" />,
                    },
                  ]}
                />
                <SegmentRow<AppLanguage>
                  label={labels.language}
                  row="language"
                  value={language}
                  onChange={onLanguageChange}
                  options={[
                    { id: 'pt', label: 'Português', content: 'PT' },
                    { id: 'en', label: 'English', content: 'EN' },
                  ]}
                />
                <Separator />
                <button
                  className={ITEM_CLASS}
                  data-menu-item=""
                  data-row="settings"
                  onClick={() => {
                    // the page is about to change: no return focus, no morph
                    go('closed');
                    onSettings();
                  }}
                  role="menuitem"
                  tabIndex={-1}
                  type="button"
                >
                  <Settings
                    className="size-4 text-muted-foreground"
                    strokeWidth={1.8}
                  />
                  <span className="flex-1">{labels.settings}</span>
                  <ChevronRight className="size-4 text-muted-foreground" />
                </button>
                <Separator />
                <HoldSignOut
                  duration={holdDuration}
                  labels={labels}
                  onComplete={(via) => {
                    onSignOut();
                    closeMenu(via, true);
                  }}
                />
              </m.div>
            </div>
          </m.div>
        </div>
      )}
    </div>
  );
}

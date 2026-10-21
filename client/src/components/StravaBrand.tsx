import type { MouseEventHandler } from 'react';
import connectOrange from '@/assets/strava/btn_strava_connect_with_orange.svg';
import poweredByBlack from '@/assets/strava/api_logo_pwrdBy_strava_horiz_black.svg';
import poweredByWhite from '@/assets/strava/api_logo_pwrdBy_strava_horiz_white.svg';

// Strava's brand guidelines (developers.strava.com/guidelines) require the
// official assets unmodified: the "Connect with Strava" button at 48px tall
// and the "Powered by Strava" logo, never more prominent than our own mark.
// The SVGs are vendored as-is from Strava's download kit.

interface ConnectWithStravaProps {
  // link form for full-page OAuth redirects, button form when the caller
  // wants to track a pending state first (LoginPage)
  href?: string;
  onClick?: MouseEventHandler<HTMLButtonElement>;
  disabled?: boolean;
  className?: string;
}

export function ConnectWithStrava({ href, onClick, disabled, className = '' }: ConnectWithStravaProps) {
  const img = (
    <img
      src={connectOrange}
      alt="Connect with Strava"
      width={237}
      height={48}
      className="block h-12 w-auto"
    />
  );
  const base = `inline-block shrink-0 cursor-pointer rounded-[4px] ${className}`;

  if (href) {
    return (
      <a href={href} className={base}>
        {img}
      </a>
    );
  }
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-busy={disabled}
      className={`${base} disabled:cursor-default disabled:opacity-60`}
    >
      {img}
    </button>
  );
}

export function PoweredByStrava({ className = '' }: { className?: string }) {
  return (
    <div className={`flex ${className}`}>
      <img
        src={poweredByBlack}
        alt="Powered by Strava"
        width={365}
        height={37}
        className="h-[14px] w-auto dark:hidden"
      />
      <img
        src={poweredByWhite}
        alt="Powered by Strava"
        width={365}
        height={37}
        className="hidden h-[14px] w-auto dark:block"
      />
    </div>
  );
}

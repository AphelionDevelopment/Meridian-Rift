import { useAtom, useSetAtom } from 'jotai';
import type { PropsWithChildren } from 'react';
import { Icon } from 'tgui-core/components';
import { UI_DISABLED, UI_INTERACTIVE, UI_UPDATE } from 'tgui-core/constants';
import { type BooleanLike, classes } from 'tgui-core/react';
import { toTitleCase } from 'tgui-core/string';
import {
  debugThemeAtom,
  kitchenSinkAtom,
  meridianThemeAtom,
} from '../events/store';
import { MeridianThemePicker } from './MeridianThemePicker';

type TitleBarProps = Partial<{
  className: string;
  title: string;
  status: number;
  canClose: BooleanLike;
  onClose: (e) => void;
  onDragStart: (e) => void;
}> &
  PropsWithChildren;

function statusToColor(status: number): string {
  switch (status) {
    case UI_INTERACTIVE:
      return 'good';
    case UI_UPDATE:
      return 'average';
    default:
      return 'bad';
  }
}

export function TitleBar(props: TitleBarProps) {
  const { className, title, status, canClose, onDragStart, onClose, children } =
    props;

  const [kitchenSink, setKitchenSink] = useAtom(kitchenSinkAtom);
  const setDebugTheme = useSetAtom(debugThemeAtom);
  const [meridianTheme, setMeridianTheme] = useAtom(meridianThemeAtom);

  const finalTitle =
    (typeof title === 'string' &&
      title === title.toLowerCase() &&
      toTitleCase(title)) ||
    title;

  return (
    <div className={classes(['TitleBar', className])}>
      <div
        className="TitleBar__dragZone"
        onMouseDown={(e) => onDragStart?.(e)}
      />
      {status === undefined ? (
        <Icon className="TitleBar__statusIcon" name="tools" opacity={0.5} />
      ) : (
        <Icon
          className="TitleBar__statusIcon"
          color={statusToColor(status)}
          name={status === UI_DISABLED ? 'eye-slash' : 'eye'}
        />
      )}
      <div className="TitleBar__title">{finalTitle}</div>
      {!!children && <div className="TitleBar__buttons">{children}</div>}
      <div className="TitleBar__utilities">
        <MeridianThemePicker
          className="TitleBar__themePicker"
          onChange={(theme) => {
            setDebugTheme(null);
            setMeridianTheme(theme);
            Byond.sendMessage('setMeridianTheme', { theme });
          }}
          value={meridianTheme}
        />
        {process.env.NODE_ENV !== 'production' && (
          <button
            aria-label="Toggle development showcase"
            aria-pressed={kitchenSink}
            className="TitleBar__utilityButton TitleBar__KitchenSink"
            onClick={() => setKitchenSink((prev) => !prev)}
            type="button"
          >
            <Icon aria-hidden="true" name="bug" />
          </button>
        )}
      </div>
      {!!canClose && (
        <button
          aria-label="Close window"
          className="TitleBar__close"
          onClick={onClose}
          type="button"
        >
          <Icon
            aria-hidden="true"
            className="TitleBar__close--icon"
            name="times"
          />
        </button>
      )}
    </div>
  );
}

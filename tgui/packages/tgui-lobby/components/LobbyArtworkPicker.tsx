// THIS IS AN APHELION UI FILE

import {
  type AriaAttributes,
  type ComponentProps,
  type ComponentRef,
  type HTMLAttributes,
  type KeyboardEvent,
  useEffect,
  useId,
  useRef,
  useState,
} from 'react';
import { Button, Floating, Icon } from 'tgui-core/components';
import { classes } from 'tgui-core/react';
import type {
  LobbyTitleArtVariant,
  LobbyTitleScreenOption,
  LobbyTitleTexture,
} from './TitleArtwork';

/**
 * tgui-core's CheckProps covers Button's own options and nothing else, but
 * Button funnels every prop it does not recognise through computeBoxProps onto
 * the <div> it renders -- so the menu semantics and the ref really do land on
 * the element. Declaring that once keeps the call site type-checked rather than
 * casting at the use, and the roving-focus test covers the behaviour.
 */
const OverlayCheckbox = Button.Checkbox as (
  props: ComponentProps<typeof Button.Checkbox> &
    AriaAttributes &
    Pick<HTMLAttributes<HTMLElement>, 'role' | 'tabIndex' | 'title'> & {
      ref?: (node: HTMLElement | null) => void;
    },
) => ReturnType<typeof Button.Checkbox>;

export type LobbyArtworkPickerValue = {
  classicAlt: boolean;
  texture: LobbyTitleTexture;
  variant: LobbyTitleArtVariant;
  /// Whether the server rotates screens each round or stays on the pinned one.
  rotate: boolean;
  /// Pinned screen file name, or null for the neutral Meridian Rift master.
  selected: string | null;
  /// Screens available in the server's title screen config directory.
  screens: readonly LobbyTitleScreenOption[];
};

/**
 * One admin change. A discriminated union rather than a whole-value onChange so
 * each edit maps to exactly one server message and cannot smuggle along a stale
 * copy of the other fields.
 */
export type LobbyArtworkAction =
  | { type: 'screen'; name: string | null }
  | { type: 'rotate'; rotate: boolean }
  | { type: 'overlay'; name: string; overlay: boolean }
  | {
      type: 'presentation';
      classicAlt: boolean;
      texture: LobbyTitleTexture;
      variant: LobbyTitleArtVariant;
    };

export type LobbyArtworkPickerProps = {
  onAction: (action: LobbyArtworkAction) => void;
  value: LobbyArtworkPickerValue;
} & Partial<{
  className: string;
  placement: ComponentProps<typeof Floating>['placement'];
}>;

type ArtworkOption = {
  description: string;
  label: string;
  texture: LobbyTitleTexture;
  variant: LobbyTitleArtVariant;
};

export const LOBBY_ARTWORK_OPTIONS: readonly ArtworkOption[] = [
  {
    label: 'Original - A Flat',
    description: 'Flat screen without edge shading',
    texture: 'original',
    variant: 'flat',
  },
  {
    label: 'Original - B Edge',
    description: 'Flat screen with subtle edge shading',
    texture: 'original',
    variant: 'edge',
  },
  {
    label: 'Original - C Convex',
    description: 'Convex CRT glass without a bezel',
    texture: 'original',
    variant: 'convex',
  },
  {
    label: 'Original - D Convex + bezel',
    description: 'Convex CRT glass with a physical bezel',
    texture: 'original',
    variant: 'convex-bezel',
  },
  {
    label: 'NavaroBL - A Flat',
    description: 'Licensed scanlines on a flat screen',
    texture: 'navarobl',
    variant: 'flat',
  },
  {
    label: 'NavaroBL - B Edge',
    description: 'Licensed scanlines with subtle edge shading',
    texture: 'navarobl',
    variant: 'edge',
  },
  {
    label: 'NavaroBL - C Convex',
    description: 'Licensed scanlines on convex CRT glass',
    texture: 'navarobl',
    variant: 'convex',
  },
  {
    label: 'NavaroBL - D Convex + bezel',
    description: 'Licensed scanlines, convex glass, and a bezel',
    texture: 'navarobl',
    variant: 'convex-bezel',
  },
] as const;

const CLASSIC_ALT_LABEL = 'Classic Alt';
const DEFAULT_SCREEN_LABEL = 'Meridian Rift (default)';

/**
 * Config screen names are long enough to crowd the row out, so the extension is
 * dropped for display and the full file name is carried in the title tooltip.
 */
function abbreviateScreenName(name: string): string {
  return name.replace(/\.[a-z0-9]+$/i, '');
}

const ROTATE_LABEL = 'Rotate title screens';

function getSelectedOptionIndex(value: LobbyArtworkPickerValue): number {
  return Math.max(
    LOBBY_ARTWORK_OPTIONS.findIndex(
      (option) =>
        option.texture === value.texture && option.variant === value.variant,
    ),
    0,
  );
}

export function LobbyArtworkPicker(props: LobbyArtworkPickerProps) {
  const { className, onAction, placement = 'bottom-end', value } = props;
  const [isOpen, setIsOpen] = useState(false);
  const floatingRef = useRef<ComponentRef<typeof Floating>>(null);
  const itemRefs = useRef<Array<HTMLElement | null>>([]);
  const openFocus = useRef<'first' | 'last' | 'selected'>('selected');
  const typeahead = useRef('');
  const typeaheadTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const triggerId = useId();
  const menuId = useId();
  const screens = value.screens;
  // One flat, ordered list of focusable items drives both roving focus and
  // typeahead. Every index below is derived from it so the two cannot drift.
  const screenRadioIndex = (index: number) => index * 2;
  const screenOverlayIndex = (index: number) => index * 2 + 1;
  // The default is listed after the config screens: it is the fallback rather than
  // one of the pictures rotation picks so it goes last
  const defaultScreenIndex = screens.length * 2;
  const rotateIndex = defaultScreenIndex + 1;
  const artworkStartIndex = rotateIndex + 1;
  const classicAltIndex = artworkStartIndex + LOBBY_ARTWORK_OPTIONS.length;
  const selectedIndex =
    artworkStartIndex + getSelectedOptionIndex(value);
  const selectedOption = LOBBY_ARTWORK_OPTIONS[getSelectedOptionIndex(value)];
  const itemLabels = [
    ...screens.flatMap((screen) => [
      abbreviateScreenName(screen.name),
      `${screen.name} overlay`,
    ]),
    DEFAULT_SCREEN_LABEL,
    ROTATE_LABEL,
    ...LOBBY_ARTWORK_OPTIONS.map(({ label }) => label),
    CLASSIC_ALT_LABEL,
  ];

  useEffect(
    () => () => {
      if (typeaheadTimer.current) {
        clearTimeout(typeaheadTimer.current);
      }
    },
    [],
  );

  const focusItem = (index: number) => {
    const item = itemRefs.current[index];
    item?.focus();
    item?.scrollIntoView?.({ block: 'nearest' });
  };

  const closeAndFocusTrigger = () => {
    typeahead.current = '';
    if (typeaheadTimer.current) {
      clearTimeout(typeaheadTimer.current);
      typeaheadTimer.current = null;
    }
    floatingRef.current?.close();
    queueMicrotask(() => document.getElementById(triggerId)?.focus());
  };

  const selectArtwork = (option: ArtworkOption) => {
    onAction({
      type: 'presentation',
      classicAlt: value.classicAlt,
      texture: option.texture,
      variant: option.variant,
    });
    closeAndFocusTrigger();
  };

  const toggleClassicAlt = () => {
    onAction({
      type: 'presentation',
      classicAlt: !value.classicAlt,
      texture: value.texture,
      variant: value.variant,
    });
    closeAndFocusTrigger();
  };

  const selectScreen = (name: string | null) => {
    onAction({ type: 'screen', name });
    closeAndFocusTrigger();
  };

  // Overlay and rotation are toggles an admin is likely to flip more than once,
  // so they leave the menu open rather than closing on every click.
  const toggleOverlay = (screen: LobbyTitleScreenOption) => {
    onAction({ type: 'overlay', name: screen.name, overlay: !screen.overlay });
  };

  const toggleRotate = () => {
    onAction({ type: 'rotate', rotate: !value.rotate });
  };

  const handleTriggerKeyDown = (event: KeyboardEvent<HTMLButtonElement>) => {
    if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') {
      if (event.key === 'Enter' || event.key === ' ') {
        openFocus.current = 'selected';
      }
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    openFocus.current = event.key === 'ArrowUp' ? 'last' : 'first';
    if (isOpen) {
      focusItem(openFocus.current === 'last' ? itemLabels.length - 1 : 0);
    } else {
      event.currentTarget.click();
    }
  };

  const handleMenuKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const itemCount = itemLabels.length;
    const currentIndex = itemRefs.current.indexOf(
      document.activeElement as HTMLButtonElement,
    );
    let nextIndex: number | undefined;

    switch (event.key) {
      case 'ArrowDown':
        nextIndex = (Math.max(currentIndex, 0) + 1) % itemCount;
        break;
      case 'ArrowUp':
        nextIndex =
          (currentIndex < 0 ? itemCount : currentIndex - 1 + itemCount) %
          itemCount;
        break;
      case 'Home':
        nextIndex = 0;
        break;
      case 'End':
        nextIndex = itemCount - 1;
        break;
      case 'Escape':
        event.preventDefault();
        event.stopPropagation();
        closeAndFocusTrigger();
        return;
      case 'Tab':
        floatingRef.current?.close();
        return;
      default: {
        if (
          event.key.length !== 1 ||
          event.key === ' ' ||
          event.altKey ||
          event.ctrlKey ||
          event.metaKey
        ) {
          return;
        }
        if (typeaheadTimer.current) {
          clearTimeout(typeaheadTimer.current);
        }
        typeahead.current += event.key.toLocaleLowerCase();
        typeaheadTimer.current = setTimeout(() => {
          typeahead.current = '';
        }, 500);

        let search = typeahead.current;
        let matchFound = false;
        for (let offset = 1; offset <= itemCount; offset++) {
          const index = (Math.max(currentIndex, -1) + offset) % itemCount;
          if (itemLabels[index].toLocaleLowerCase().startsWith(search)) {
            nextIndex = index;
            matchFound = true;
            break;
          }
        }

        // Restart a failed sequence at its latest character. This also lets a
        // repeated initial cycle through the Original and NavaroBL groups.
        if (!matchFound && search.length > 1) {
          search = event.key.toLocaleLowerCase();
          typeahead.current = search;
          for (let offset = 1; offset <= itemCount; offset++) {
            const index = (Math.max(currentIndex, -1) + offset) % itemCount;
            if (itemLabels[index].toLocaleLowerCase().startsWith(search)) {
              nextIndex = index;
              break;
            }
          }
        }
      }
    }

    if (nextIndex !== undefined) {
      event.preventDefault();
      event.stopPropagation();
      focusItem(nextIndex);
    }
  };

  return (
    <Floating
      ref={floatingRef}
      animationDuration={1}
      content={
        <div
          aria-labelledby={triggerId}
          className="MeridianThemePicker__menu LobbyArtworkPicker__menu"
          id={menuId}
          onKeyDown={handleMenuKeyDown}
          role="menu"
        >
          <div
            className="MeridianThemePicker__heading LobbyArtworkPicker__heading"
            role="presentation"
          >
            Change title screen
          </div>
          <div
            className="MeridianThemePicker__options LobbyArtworkPicker__options"
            role="presentation"
          >
            {screens.map((screen, index) => {
              const isSelected = value.selected === screen.name;
              return (
                <div
                  className="LobbyArtworkPicker__screenRow"
                  key={screen.name}
                  role="presentation"
                >
                  <button
                    aria-checked={isSelected}
                    className="MeridianThemePicker__option LobbyArtworkPicker__option LobbyArtworkPicker__option--noSwatch LobbyArtworkPicker__screenChoice"
                    onClick={() => selectScreen(screen.name)}
                    ref={(node) => {
                      itemRefs.current[screenRadioIndex(index)] = node;
                    }}
                    role="menuitemradio"
                    tabIndex={-1}
                    title={screen.name}
                    type="button"
                  >
                    <span
                      aria-hidden="true"
                      className="MeridianThemePicker__check LobbyArtworkPicker__check"
                    >
                      {isSelected ? <Icon name="check" /> : null}
                    </span>
                    <span className="MeridianThemePicker__label LobbyArtworkPicker__label">
                      <strong>{abbreviateScreenName(screen.name)}</strong>
                    </span>
                  </button>
                  <OverlayCheckbox
                    aria-checked={screen.overlay}
                    aria-label={`Overlay Meridian Rift on ${screen.name}`}
                    // The shared checkbox, so it picks up whatever the active
                    // skin uses for a ticked control rather than a fixed colour.
                    checked={screen.overlay}
                    className="LobbyArtworkPicker__overlayToggle"
                    onClick={() => toggleOverlay(screen)}
                    ref={(node) => {
                      itemRefs.current[screenOverlayIndex(index)] = node;
                    }}
                    role="menuitemcheckbox"
                    tabIndex={-1}
                    title={`Overlay the Meridian Rift wordmark on ${screen.name}`}
                  />
                </div>
              );
            })}
            <button
              aria-checked={value.selected === null}
              className="MeridianThemePicker__option LobbyArtworkPicker__option LobbyArtworkPicker__option--noSwatch"
              onClick={() => selectScreen(null)}
              ref={(node) => {
                itemRefs.current[defaultScreenIndex] = node;
              }}
              role="menuitemradio"
              tabIndex={-1}
              type="button"
            >
              <span
                aria-hidden="true"
                className="MeridianThemePicker__check LobbyArtworkPicker__check"
              >
                {value.selected === null ? <Icon name="check" /> : null}
              </span>
              <span className="MeridianThemePicker__label LobbyArtworkPicker__label">
                <strong>{DEFAULT_SCREEN_LABEL}</strong>
                <span>Meridian Rift, tinted by the active theme</span>
              </span>
            </button>
            <button
              aria-checked={value.rotate}
              className="MeridianThemePicker__option LobbyArtworkPicker__option LobbyArtworkPicker__option--noSwatch"
              onClick={toggleRotate}
              ref={(node) => {
                itemRefs.current[rotateIndex] = node;
              }}
              role="menuitemcheckbox"
              tabIndex={-1}
              type="button"
            >
              <span
                aria-hidden="true"
                className="MeridianThemePicker__check LobbyArtworkPicker__check"
              >
                {value.rotate ? <Icon name="check" /> : null}
              </span>
              <span className="MeridianThemePicker__label LobbyArtworkPicker__label">
                <strong>{ROTATE_LABEL}</strong>
                <span>Pick a new screen each round instead of staying put</span>
              </span>
            </button>
          </div>
          <div className="LobbyArtworkPicker__separator" role="separator" />
          <div
            className="MeridianThemePicker__heading LobbyArtworkPicker__heading"
            role="presentation"
          >
            Source × display geometry
          </div>
          <div
            className="MeridianThemePicker__options LobbyArtworkPicker__options"
            role="presentation"
          >
            {LOBBY_ARTWORK_OPTIONS.map((option, index) => {
              const isSelected =
                option.texture === value.texture &&
                option.variant === value.variant;
              return (
                <button
                  aria-checked={isSelected}
                  className="MeridianThemePicker__option LobbyArtworkPicker__option"
                  key={`${option.texture}-${option.variant}`}
                  onClick={() => selectArtwork(option)}
                  ref={(node) => {
                    itemRefs.current[artworkStartIndex + index] = node;
                  }}
                  role="menuitemradio"
                  tabIndex={-1}
                  type="button"
                >
                  <span
                    aria-hidden="true"
                    className="MeridianThemePicker__check LobbyArtworkPicker__check"
                  >
                    {isSelected ? <Icon name="check" /> : null}
                  </span>
                  <span
                    aria-hidden="true"
                    className="MeridianThemePicker__swatch LobbyArtworkPicker__preview"
                    data-texture={option.texture}
                    data-variant={option.variant}
                  />
                  <span className="MeridianThemePicker__label LobbyArtworkPicker__label">
                    <strong>{option.label}</strong>
                    <span>{option.description}</span>
                  </span>
                </button>
              );
            })}
            <div className="LobbyArtworkPicker__separator" role="separator" />
            <div className="LobbyArtworkPicker__subheading" role="presentation">
              Classic NT presentation
            </div>
            <button
              aria-checked={value.classicAlt}
              className="MeridianThemePicker__option LobbyArtworkPicker__option LobbyArtworkPicker__option--classic-alt"
              onClick={toggleClassicAlt}
              ref={(node) => {
                itemRefs.current[classicAltIndex] = node;
              }}
              role="menuitemcheckbox"
              tabIndex={-1}
              type="button"
            >
              <span
                aria-hidden="true"
                className="MeridianThemePicker__check LobbyArtworkPicker__check"
              >
                {value.classicAlt ? <Icon name="check" /> : null}
              </span>
              <span
                aria-hidden="true"
                className="MeridianThemePicker__swatch LobbyArtworkPicker__preview LobbyArtworkPicker__preview--classic-alt"
              />
              <span className="MeridianThemePicker__label LobbyArtworkPicker__label">
                <strong>{CLASSIC_ALT_LABEL}</strong>
                <span>Off: Classic · On: black + gradient wordmark</span>
              </span>
            </button>
          </div>
        </div>
      }
      contentClasses="MeridianThemePicker__floating LobbyArtworkPicker__floating"
      contentOffset={4}
      onMounted={() => {
        focusItem(
          openFocus.current === 'last'
            ? itemLabels.length - 1
            : openFocus.current === 'first'
              ? 0
              : selectedIndex,
        );
      }}
      onOpenChange={setIsOpen}
      placement={placement}
    >
      <span
        className={classes([
          'MeridianThemePicker',
          'LobbyArtworkPicker',
          className,
        ])}
      >
        <button
          aria-controls={menuId}
          aria-expanded={isOpen}
          aria-haspopup="menu"
          aria-label={`Change lobby artwork. Current: ${selectedOption.label}. Classic Alt: ${value.classicAlt ? 'on' : 'off'}`}
          className="MeridianThemePicker__trigger LobbyArtworkPicker__trigger"
          id={triggerId}
          onMouseDown={() => {
            openFocus.current = 'selected';
          }}
          onKeyDown={handleTriggerKeyDown}
          type="button"
        >
          <Icon aria-hidden="true" name="image" />
        </button>
      </span>
    </Floating>
  );
}

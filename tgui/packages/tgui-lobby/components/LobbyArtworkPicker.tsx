// THIS IS AN APHELION UI FILE

import {
  type ComponentProps,
  type ComponentRef,
  type KeyboardEvent,
  useEffect,
  useId,
  useRef,
  useState,
} from 'react';
import { Floating, Icon } from 'tgui-core/components';
import { classes } from 'tgui-core/react';
import type { LobbyTitleArtVariant, LobbyTitleTexture } from './TitleArtwork';

export type LobbyArtworkPickerValue = {
  classicAlt: boolean;
  texture: LobbyTitleTexture;
  variant: LobbyTitleArtVariant;
};

export type LobbyArtworkPickerProps = {
  onChange: (value: LobbyArtworkPickerValue) => void;
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
  const { className, onChange, placement = 'bottom-end', value } = props;
  const [isOpen, setIsOpen] = useState(false);
  const floatingRef = useRef<ComponentRef<typeof Floating>>(null);
  const itemRefs = useRef<Array<HTMLButtonElement | null>>([]);
  const openFocus = useRef<'first' | 'last' | 'selected'>('selected');
  const typeahead = useRef('');
  const typeaheadTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const triggerId = useId();
  const menuId = useId();
  const selectedIndex = getSelectedOptionIndex(value);
  const selectedOption = LOBBY_ARTWORK_OPTIONS[selectedIndex];
  const itemLabels = [
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
    onChange({
      ...value,
      texture: option.texture,
      variant: option.variant,
    });
    closeAndFocusTrigger();
  };

  const toggleClassicAlt = () => {
    onChange({ ...value, classicAlt: !value.classicAlt });
    closeAndFocusTrigger();
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
                    itemRefs.current[index] = node;
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
                itemRefs.current[LOBBY_ARTWORK_OPTIONS.length] = node;
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

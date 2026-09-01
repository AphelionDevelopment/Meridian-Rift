// THIS IS A NOVA SECTOR UI FILE
import {
  type ComponentProps,
  type ReactNode,
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
} from 'react';
import { useBackend } from 'tgui/backend';
import {
  Box,
  Button,
  ColorBox,
  Dropdown,
  Modal,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import {
  type PreferencesCharacterPreviewDecorationMode,
  usePreferencesCharacterPreviewDecoration,
} from '../../common/PreferencesCharacterPreviewFrame';
import {
  AugmentsWorkbench,
  type AugmentsWorkbenchItem,
  getAugmentsPreviewCallouts,
} from './AugmentsWorkbench';
import type {
  AugmentItem,
  AugmentSlot,
  Marking,
  PreferencesMenuData,
  RoboticStyle,
} from '../types';
import { useServerPrefs } from '../useServerPrefs';

/** AugmentSlot with selected augment */
type AugmentData = AugmentSlot & {
  selectedAug: AugmentItem;
};

/** Filtered backend data consumed by the overview/detail workbench. */
type BodypartData = AugmentData & {
  chosen_markings: Marking[] | null;
  chosen_style: RoboticStyle | null;
  marking_choices: string[];
  selectedImplant: AugmentItem | null;
};

type WorkbenchData = {
  bodyparts: BodypartData[];
  internalImplants: AugmentData[];
  filteredMarkingPresets: string[];
};

// On hover, used to display extra_info tooltips.
// Uses visibility/opacity toggle instead of conditional rendering to avoid
// DOM node insertion/removal
export const HoverText = (props: { text: string; children: ReactNode }) => {
  const tooltipId = useId();
  const rootRef = useRef<HTMLDivElement>(null);
  const [hovered, setHovered] = useState(false);
  const [focused, setFocused] = useState(false);
  const [dismissed, setDismissed] = useState(false);
  const visible = Boolean(props.text) && !dismissed && (hovered || focused);

  useEffect(() => {
    const control = rootRef.current?.querySelector<HTMLElement>(
      'input, button, [role="button"], [tabindex]:not([tabindex="-1"])',
    );
    if (!control) return;

    const previousDescription = control.getAttribute('aria-describedby');
    const descriptions = new Set(
      previousDescription?.split(/\s+/).filter(Boolean) ?? [],
    );
    descriptions.add(tooltipId);
    control.setAttribute('aria-describedby', [...descriptions].join(' '));

    return () => {
      if (previousDescription) {
        control.setAttribute('aria-describedby', previousDescription);
      } else {
        control.removeAttribute('aria-describedby');
      }
    };
  }, [tooltipId]);

  return (
    <div
      className="LimbsPage__hover-text"
      role="group"
      ref={rootRef}
      onMouseEnter={() => {
        setHovered(true);
        setDismissed(false);
      }}
      onMouseLeave={() => {
        setHovered(false);
        if (!focused) setDismissed(false);
      }}
      onFocusCapture={() => {
        setFocused(true);
        if (!hovered) setDismissed(false);
      }}
      onBlurCapture={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget as Node | null)) {
          setFocused(false);
          if (!hovered) setDismissed(false);
        }
      }}
      onMouseDown={() => setDismissed(true)}
      onKeyDownCapture={(event) => {
        if (event.key === 'Escape') setDismissed(true);
      }}
    >
      {props.children}
      <div
        className={`LimbsPage__hover-text--tooltip-wrapper${visible ? ' visible' : ''}`}
      >
        <div
          className="LimbsPage__hover-text--tooltip"
          id={tooltipId}
          role="tooltip"
        >
          {props.text}
        </div>
      </div>
    </div>
  );
};

// The dropdown components with fancy HoverText

const LabeledDropdown = (
  props: {
    label: string;
    options: ComponentProps<typeof Dropdown>['options'];
    selected: string | undefined;
    onSelected: (value: any) => void;
  } & Partial<{
    maxItems: number;
    displayText: string;
    searchInput: boolean;
    tooltip: string;
    disabled: boolean;
  }>,
) => {
  const dropdown = (
    <Dropdown
      width="100%"
      options={props.options}
      selected={props.selected}
      displayText={props.displayText}
      disabled={props.disabled}
      onSelected={props.onSelected}
      maxItems={props.maxItems}
      searchInput={props.searchInput}
      styledInput
    />
  );
  return (
    <Stack.Item>
      <Box>{props.label}</Box>
      {props.tooltip ? (
        <HoverText text={props.tooltip}>{dropdown}</HoverText>
      ) : (
        dropdown
      )}
    </Stack.Item>
  );
};

// Popup to stop users from resetting all their markings accidentally via the preset dropdown

const PresetConfirmPopup = (props: {
  preset: string;
  onConfirm: () => void;
  onCancel: () => void;
}) => (
  <Modal>
    <Stack vertical textAlign="center" align="center">
      <Stack.Item>
        <Box fontSize="2em">Replace Markings?</Box>
      </Stack.Item>
      <Stack.Item maxWidth="300px">
        <Box>
          Applying the <b>{props.preset}</b> preset will replace all your
          current markings. Are you sure?
        </Box>
      </Stack.Item>
      <Stack.Item>
        <Stack fill>
          <Stack.Item>
            <Button color="danger" onClick={props.onConfirm}>
              Apply Preset
            </Button>
          </Stack.Item>
          <Stack.Item>
            <Button onClick={props.onCancel}>Cancel</Button>
          </Stack.Item>
        </Stack>
      </Stack.Item>
    </Stack>
  </Modal>
);

export const RotateCharacterButtons = () => {
  const { act } = useBackend<PreferencesMenuData>();
  return (
    <Box mt={1}>
      <Button
        onClick={() => act('rotate', { backwards: false })}
        fontSize="22px"
        icon="redo"
        tooltip="Rotate Clockwise"
        tooltipPosition="bottom"
      />
      <Button
        onClick={() => act('rotate', { backwards: true })}
        fontSize="22px"
        icon="undo"
        tooltip="Rotate Counter-Clockwise"
        tooltipPosition="bottom"
      />
    </Box>
  );
};

// Various helpers

// Slot bitflags -- these must match DM defines in code\__DEFINES\inventory.dm
const SLOT_LEGS = (1 << 3) | (1 << 4); // LEG_LEFT | LEG_RIGHT

// ── Slot predicates ───────────────────────────────────────────────────────────
const isLegSlot = (slot_flag?: number) =>
  !!slot_flag && (slot_flag & SLOT_LEGS) !== 0;
const isBodypart = (item: AugmentSlot) => item.is_bodypart;
const isImplant = (item: AugmentSlot) => !item.is_bodypart;

// ── Display helpers ───────────────────────────────────────────────────────────
const augDisplayName = (aug: AugmentItem, showCost?: boolean) =>
  showCost && aug.cost
    ? `${aug.name} (${aug.cost > 0 ? '+' : ''}${aug.cost})`
    : aug.name;

/** True when the options list has more than just the default "None" entry */
const hasAnyOptions = (options: AugmentItem[] | null | undefined) =>
  (options?.length ?? 0) > 1;

// ── Filtering ─────────────────────────────────────────────────────────────────
const filterBySpecies = <T extends { recommended_species: string | null }>(
  items: T[],
  species: string,
  allowMismatched: boolean,
): T[] => {
  if (allowMismatched) return items;
  return items.filter(
    (item) =>
      !item.recommended_species ||
      item.recommended_species.split(',').includes(species),
  );
};

const isAugAllowed = (
  aug: AugmentItem,
  species: string,
  ckey: string,
  slot_flag?: number,
  digi_legs?: BooleanLike,
  taur_legs?: BooleanLike,
): boolean => {
  if (isLegSlot(slot_flag) && digi_legs && !aug.has_digi) return false;
  if (isLegSlot(slot_flag) && taur_legs) return false;
  if (aug.species_blacklist?.[species]) return false;
  if (aug.species_whitelist && !aug.species_whitelist[species]) return false;
  if (aug.ckey_whitelist && !aug.ckey_whitelist.includes(ckey)) return false;
  return true;
};

const showsInBodyPartsTab = (bodypart: BodypartData, taur_legs: BooleanLike) =>
  hasAnyOptions(bodypart.aug_options) ||
  (!!taur_legs && isLegSlot(bodypart.slot_flag));

/** Resolves internal implant slots into AugmentData with filtered options and selected aug */
const buildInternalImplantData = (
  items: AugmentSlot[],
  augments: Record<string, string>,
  species: string,
  ckey: string,
): AugmentData[] =>
  items.map((item) => {
    const chosen = augments?.[item.slot] ?? null;
    const aug_options = (item.aug_options ?? []).filter((aug) =>
      isAugAllowed(aug, species, ckey),
    );
    return {
      ...item,
      aug_options,
      selectedAug:
        aug_options.find((aug) => aug.path === chosen) ?? aug_options[0],
    };
  });

// Markings

const Markings = (props: {
  body_zone: string;
  chosen_markings: Marking[] | null;
  marking_choices: string[];
  act: (action: string, params?: Record<string, unknown>) => void;
}) => {
  const { body_zone, chosen_markings, marking_choices, act } = props;
  return (
    <Stack fill vertical>
      <Stack.Item>Markings:</Stack.Item>
      {(chosen_markings ?? []).map((marking) => {
        return (
          <Stack.Item key={marking.marking_id}>
            <Stack fill>
              <Stack.Item grow style={{ minWidth: 0, overflow: 'hidden' }}>
                <Dropdown
                  width="100%"
                  options={marking_choices}
                  selected={marking.name}
                  displayText={marking.name}
                  maxItems={7}
                  searchInput
                  styledInput
                  onSelected={(value) =>
                    act('change_marking', {
                      bodypart_slot: body_zone,
                      marking_id: marking.marking_id,
                      marking_name: value,
                    })
                  }
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  onClick={() =>
                    act('color_marking', {
                      bodypart_slot: body_zone,
                      marking_id: marking.marking_id,
                    })
                  }
                >
                  <ColorBox color={marking.color} />
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  color={marking.emissive ? 'good' : 'bad'}
                  tooltip="The 'E' is for 'Emissive' — does it glow? Green = glow, Red = no glow."
                  onClick={() =>
                    act('change_emissive', {
                      bodypart_slot: body_zone,
                      marking_id: marking.marking_id,
                      emissive: marking.emissive,
                    })
                  }
                >
                  E
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  color="bad"
                  onClick={() =>
                    act('remove_marking', {
                      bodypart_slot: body_zone,
                      marking_id: marking.marking_id,
                    })
                  }
                >
                  -
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        );
      })}
      <Stack.Item>
        <Button
          color="good"
          onClick={() => act('add_marking', { bodypart_slot: body_zone })}
        >
          +
        </Button>
      </Stack.Item>
    </Stack>
  );
};

// Limb augment controls for the selected schematic region.

const BodypartAugmentControls = (props: {
  available: boolean;
  limb: BodypartData;
}) => {
  const { act, data } = useBackend<PreferencesMenuData>();
  const server_data = useServerPrefs()?.limbs_and_markings;

  const { limb } = props;
  const showCost = !!data.quirk_points_enabled;
  const displayName = (aug: AugmentItem) => augDisplayName(aug, showCost);
  const balance = -data.quirks_balance;
  const aug_options = limb.aug_options ?? [];
  const implant_options = limb.implant_options ?? [];

  const available_styles = (server_data?.robotic_styles ?? []).filter(
    (style) => {
      const aug = limb.selectedAug;
      if (!aug?.allows_styles && style.name !== 'None') return false;
      if (limb.slot_flag && !(style.supported_slots & limb.slot_flag))
        return false;
      if (isLegSlot(limb.slot_flag) && data.digi_legs && !style.has_digi)
        return false;
      return true;
    },
  );
  const isTaurRestrictedLeg = !!data.taur_legs && isLegSlot(limb.slot_flag);

  if (!server_data) return null;

  if (!props.available && !isTaurRestrictedLeg) {
    return (
      <div className="LimbsPage__emptyRegion">
        No augmentation options are available for this region.
      </div>
    );
  }

  return (
    <Stack fill vertical>
      {isTaurRestrictedLeg ? (
        <LabeledDropdown
          label="Augmentation:"
          options={['Not available']}
          selected="Not available"
          displayText={'Not available'}
          disabled
          searchInput
          maxItems={7}
          onSelected={() => {}}
        />
      ) : (
        <LabeledDropdown
          label="Augmentation:"
          options={aug_options.map((aug) => displayName(aug))}
          selected={
            limb.selectedAug ? displayName(limb.selectedAug) : undefined
          }
          displayText={
            limb.selectedAug ? displayName(limb.selectedAug) : undefined
          }
          tooltip={limb.selectedAug?.extra_info}
          searchInput
          maxItems={7}
          onSelected={(name) => {
            const option = aug_options.find((aug) => displayName(aug) === name);
            if (option?.path === limb.selectedAug?.path) return;
            if (
              showCost &&
              balance - (limb.selectedAug?.cost ?? 0) + (option?.cost ?? 0) > 0
            )
              return;
            act('set_bodypart_aug', {
              slot: limb.slot,
              augment_path: option?.path ?? null,
            });
          }}
        />
      )}
      {limb.selectedAug?.path &&
        limb.selectedAug?.allows_styles !== 0 &&
        (available_styles.length <= 1 ? (
          <LabeledDropdown
            label="Style:"
            options={['No available styles']}
            selected="No available styles"
            displayText="No available styles"
            searchInput
            maxItems={7}
            disabled
            onSelected={() => {}}
          />
        ) : (
          <LabeledDropdown
            label="Style:"
            options={available_styles.map((style) => style.name)}
            selected={limb.chosen_style?.name ?? 'None'}
            displayText={limb.chosen_style?.name ?? 'None'}
            searchInput
            onSelected={(value) => {
              if (value === limb.chosen_style?.name) return;
              act('set_bodypart_aug_style', {
                slot: limb.slot,
                style_name: value,
              });
            }}
          />
        ))}
      {limb.selectedAug?.allows_implants !== 0 &&
        (limb.has_implant ? (
          <LabeledDropdown
            label="Implant slot:"
            options={implant_options.map((aug) => displayName(aug))}
            selected={
              limb.selectedImplant
                ? displayName(limb.selectedImplant)
                : undefined
            }
            displayText={
              limb.selectedImplant
                ? displayName(limb.selectedImplant)
                : undefined
            }
            searchInput
            maxItems={7}
            tooltip={limb.selectedImplant?.extra_info}
            onSelected={(name) => {
              const option = implant_options.find(
                (aug) => displayName(aug) === name,
              );
              if (
                showCost &&
                balance -
                  (limb.selectedImplant?.cost ?? 0) +
                  (option?.cost ?? 0) >
                  0
              )
                return;
              if (option?.path === limb.selectedImplant?.path) return;
              act('set_internal_implant_aug', {
                internal_implant_slot: `${limb.slot} implant`,
                augment_path: option?.path ?? null,
              });
            }}
          />
        ) : (
          <LabeledDropdown
            label="Implant slot:"
            options={['None available']}
            selected="None available"
            displayText="None available"
            searchInput
            maxItems={7}
            disabled
            onSelected={() => {}}
          />
        ))}
    </Stack>
  );
};

// Internal implant controls for the selected schematic region.

const InternalImplantControls = (props: { internal_implant: AugmentData }) => {
  const { act, data } = useBackend<PreferencesMenuData>();
  const { internal_implant } = props;
  const showCost = !!data.quirk_points_enabled;
  const displayName = (aug: AugmentItem) => augDisplayName(aug, showCost);
  const balance = -data.quirks_balance;
  const aug_options = internal_implant.aug_options ?? [];
  return (
    <LabeledDropdown
      label="Implant:"
      options={aug_options.map(displayName)}
      selected={
        internal_implant.selectedAug
          ? displayName(internal_implant.selectedAug)
          : undefined
      }
      displayText={
        internal_implant.selectedAug
          ? displayName(internal_implant.selectedAug)
          : undefined
      }
      searchInput
      maxItems={7}
      onSelected={(name) => {
        const option = aug_options.find((aug) => displayName(aug) === name);
        if (
          showCost &&
          balance -
            (internal_implant.selectedAug?.cost ?? 0) +
            (option?.cost ?? 0) >
            0
        )
          return;
        if (option?.path === internal_implant.selectedAug?.path) return;
        act('set_internal_implant_aug', {
          internal_implant_slot: internal_implant.slot,
          augment_path: option?.path ?? null,
        });
      }}
    />
  );
};

const QuirkBalance = () => {
  const { data } = useBackend<PreferencesMenuData>();
  if (!data.quirk_points_enabled) return null;
  return (
    <div className="LimbsPage__balance">
      <span>Quirk point balance</span>
      <strong>{-data.quirks_balance}</strong>
    </div>
  );
};

// Root page

export enum AugmentsTab {
  Markings = 0,
  BodyParts = 1,
  InternalImplants = 2,
}

export const AUGMENTS_TAB_PREVIEW_DECORATION = {
  [AugmentsTab.Markings]: 'augmentation_markings',
  [AugmentsTab.BodyParts]: 'augmentation_body_parts',
  [AugmentsTab.InternalImplants]: 'augmentation_implants',
} as const satisfies Record<
  AugmentsTab,
  PreferencesCharacterPreviewDecorationMode
>;

export const LimbsPage = ({
  onTabChange,
}: {
  onTabChange?: (tab: AugmentsTab) => void;
}) => {
  const { data, act } = useBackend<PreferencesMenuData>();
  const server_data = useServerPrefs()?.limbs_and_markings;
  const [tab, setTab] = useState<AugmentsTab>(AugmentsTab.Markings);
  const [selectedRegion, setSelectedRegion] = useState<string | null>(null);
  const [pendingPreset, setPendingPreset] = useState<string | null>(null);
  const hasWarnedRef = useRef(false);

  const handleTab = (next: AugmentsTab) => {
    setTab(next);
    onTabChange?.(next);
  };
  const previewDecoration = AUGMENTS_TAB_PREVIEW_DECORATION[tab];

  // Resets the preset warning when a marking is manually changed (e.g. not using the preset dropdown)
  const actAndResetPresetWarning = (
    action: string,
    params?: Record<string, unknown>,
  ) => {
    if (
      [
        'add_marking',
        'remove_marking',
        'change_marking',
        'color_marking',
        'change_emissive',
      ].includes(action)
    ) {
      hasWarnedRef.current = false;
    }
    act(action, params);
  };

  // Filter backend choices once. Presentation order comes from the shared
  // callout schema rather than from English slot names or array midpoints.
  const workbenchData: WorkbenchData | null = useMemo(() => {
    if (!server_data?.augment_items) return null;

    const species = data.character_preferences?.misc?.species ?? '';
    const ckey = data.ckey ?? '';
    const allowMismatched = !!data.allow_mismatched_parts;

    // Filter marking choices and presets by species/mismatched parts
    const markingChoices: Record<string, string[]> = {};
    for (const [slot, choices] of Object.entries(
      server_data.marking_choices ?? {},
    )) {
      markingChoices[slot] = filterBySpecies(
        choices,
        species,
        allowMismatched,
      ).map((choice) => choice.name);
    }
    const filteredMarkingPresets = filterBySpecies(
      server_data.marking_presets ?? [],
      species,
      allowMismatched,
    ).map((preset) => preset.name);

    const styles = server_data.robotic_styles ?? [];

    const limbs: BodypartData[] = server_data.augment_items
      .filter(isBodypart)
      .map((item) => {
        const aug_options = (item.aug_options ?? []).filter((aug) =>
          isAugAllowed(
            aug,
            species,
            ckey,
            item.slot_flag,
            data.digi_legs,
            data.taur_legs,
          ),
        );
        const implant_options = (item.implant_options ?? []).filter((aug) =>
          isAugAllowed(
            aug,
            species,
            ckey,
            item.slot_flag,
            data.digi_legs,
            data.taur_legs,
          ),
        );
        const chosen_style_name = data.augment_styles?.[item.slot] ?? null;
        const augByPath = aug_options.length
          ? Object.fromEntries(aug_options.map((aug) => [aug.path, aug]))
          : {};
        const implantByPath = implant_options.length
          ? Object.fromEntries(implant_options.map((aug) => [aug.path, aug]))
          : {};
        return {
          ...item,
          aug_options,
          implant_options,
          chosen_markings: (data.markings?.[item.body_zone ?? item.slot] ??
            null) as Marking[] | null,
          chosen_style:
            styles.find((style) => style.name === chosen_style_name) ?? null,
          marking_choices: markingChoices[item.body_zone ?? item.slot] ?? [],
          selectedAug:
            augByPath[data.augments?.[item.slot] ?? ''] ?? aug_options[0],
          selectedImplant:
            implantByPath[data.augments?.[`${item.slot} implant`] ?? ''] ??
            implant_options[0] ??
            null,
        };
      });

    const internal_implants = server_data.augment_items.filter(isImplant);

    return {
      bodyparts: limbs,
      internalImplants: buildInternalImplantData(
        internal_implants,
        data.augments ?? {},
        species,
        ckey,
      ),
      filteredMarkingPresets,
    };
  }, [server_data, data]);

  const calloutSpecs = getAugmentsPreviewCallouts(previewDecoration);
  const bodypartsByRegion = new Map(
    (workbenchData?.bodyparts ?? []).map((bodypart) => [
      bodypart.preview_region,
      bodypart,
    ]),
  );
  const implantsByRegion = new Map(
    (workbenchData?.internalImplants ?? []).map((implant) => [
      implant.preview_region,
      implant,
    ]),
  );
  const workbenchItems = calloutSpecs.flatMap<AugmentsWorkbenchItem>(
    (callout) => {
      if (tab === AugmentsTab.InternalImplants) {
        const implant = implantsByRegion.get(callout.region);
        if (!implant) return [];
        return [
          {
            available: true,
            label: implant.slot,
            region: callout.region,
            summary: implant.selectedAug?.name ?? 'None',
          },
        ];
      }

      const bodypart = bodypartsByRegion.get(callout.region);
      if (!bodypart) return [];
      if (tab === AugmentsTab.Markings) {
        const count = bodypart.chosen_markings?.length ?? 0;
        return [
          {
            available: true,
            label: bodypart.slot,
            region: callout.region,
            summary: count === 1 ? '1 marking' : `${count} markings`,
          },
        ];
      }

      const available = showsInBodyPartsTab(bodypart, data.taur_legs);
      return [
        {
          available,
          label: bodypart.slot,
          region: callout.region,
          summary: available
            ? (bodypart.selectedAug?.name ?? 'None')
            : 'Unavailable',
        },
      ];
    },
  );
  const activeItem =
    workbenchItems.find((item) => item.region === selectedRegion) ??
    workbenchItems[0];
  const activeRegion = activeItem?.region ?? '';
  const activeBodypart = bodypartsByRegion.get(activeRegion);
  const activeImplant = implantsByRegion.get(activeRegion);

  usePreferencesCharacterPreviewDecoration(
    act,
    previewDecoration,
    activeRegion || null,
  );

  let regionDetail: ReactNode = (
    <div className="LimbsPage__emptyRegion">No linked region is available.</div>
  );
  if (tab === AugmentsTab.Markings && activeBodypart) {
    regionDetail = (
      <Markings
        act={actAndResetPresetWarning}
        body_zone={activeBodypart.body_zone ?? activeBodypart.slot}
        chosen_markings={activeBodypart.chosen_markings}
        marking_choices={activeBodypart.marking_choices}
      />
    );
  } else if (tab === AugmentsTab.BodyParts && activeBodypart) {
    regionDetail = (
      <BodypartAugmentControls
        available={showsInBodyPartsTab(activeBodypart, data.taur_legs)}
        limb={activeBodypart}
      />
    );
  } else if (tab === AugmentsTab.InternalImplants && activeImplant) {
    regionDetail = <InternalImplantControls internal_implant={activeImplant} />;
  }

  const modeLabel =
    tab === AugmentsTab.Markings
      ? 'Markings'
      : tab === AugmentsTab.BodyParts
        ? 'Body parts'
        : 'Internal implants';
  const editorToolbar =
    tab === AugmentsTab.Markings ? (
      <div className="LimbsPage__editorToolbar">
        <span>Marking preset</span>
        <Dropdown
          width="100%"
          options={workbenchData?.filteredMarkingPresets ?? []}
          selected={null}
          placeholder="Apply a preset..."
          maxItems={7}
          searchInput
          styledInput
          onSelected={(value) => {
            if (!hasWarnedRef.current) setPendingPreset(value);
            else act('set_preset', { preset: value });
          }}
        />
      </div>
    ) : (
      <QuirkBalance />
    );

  return (
    <div className="LimbsPage">
      {pendingPreset && (
        <div className="LimbsPage__presetDialog">
          <PresetConfirmPopup
            preset={pendingPreset}
            onConfirm={() => {
              hasWarnedRef.current = true;
              act('set_preset', { preset: pendingPreset });
              setPendingPreset(null);
            }}
            onCancel={() => setPendingPreset(null)}
          />
        </div>
      )}
      <Stack fill vertical>
        <Stack.Item>
          <Stack>
            <Stack.Item grow>
              <Button
                selected={tab === AugmentsTab.Markings}
                onClick={() => handleTab(AugmentsTab.Markings)}
                fluid
                align="center"
                fontSize="14px"
              >
                Markings
              </Button>
            </Stack.Item>
            <Stack.Item grow>
              <Button
                selected={tab === AugmentsTab.BodyParts}
                onClick={() => handleTab(AugmentsTab.BodyParts)}
                fluid
                align="center"
                fontSize="14px"
              >
                Body Parts
              </Button>
            </Stack.Item>
            <Stack.Item grow>
              <Button
                selected={tab === AugmentsTab.InternalImplants}
                onClick={() => handleTab(AugmentsTab.InternalImplants)}
                fluid
                align="center"
                fontSize="14px"
              >
                Internal Implants
              </Button>
            </Stack.Item>
          </Stack>
        </Stack.Item>
        <Stack.Item className="LimbsPage__workspaceHost" grow>
          <AugmentsWorkbench
            decoration={previewDecoration}
            detail={regionDetail}
            detailTitle={activeItem?.label ?? 'Region settings'}
            items={workbenchItems}
            modeLabel={modeLabel}
            onSelect={setSelectedRegion}
            previewId={data.character_preview_view}
            rotationControls={<RotateCharacterButtons />}
            selectedRegion={activeRegion}
            toolbar={editorToolbar}
          />
        </Stack.Item>
      </Stack>
    </div>
  );
};

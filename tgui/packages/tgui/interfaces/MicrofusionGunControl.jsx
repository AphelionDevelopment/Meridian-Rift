// THIS IS A NOVA SECTOR UI FILE
import { useState } from 'react';
import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
} from 'tgui-core/components';
import { toFixed } from 'tgui-core/math';

import { useBackend } from '../backend';
import { Window } from '../layouts';

const MFD = {
  wire: '#2f8f6e',
  glass: 'rgba(0, 22, 16, 0.65)',
  text: '#8ff5cd',
  selected: '#ffd964',
  fault: '#ff5f56',
};

// The gun sheet is 40x32, so the schematic works in icon-pixel space.
const ICON_W = 40;
const ICON_H = 32;

/**
 * Empty bay markers. `x`/`y` is where the ring sits -- kept off the weapon so
 * several empty bays can't stack on top of each other -- and `ax`/`ay` is the
 * spot on the frame it points at, taken from where that bay's overlays actually
 * paint on the 40x32 sheet.
 */
const SLOT_ANCHORS = {
  rail: { x: 17, y: 3, ax: 20, ay: 10, label: 'RAIL' },
  camo: { x: 4, y: 5, ax: 14, ay: 15, label: 'FRAME' },
  unique: { x: 31, y: 3, ax: 19, ay: 15, label: 'UNIQUE' },
  underbarrel: { x: 19, y: 29, ax: 22, ay: 18, label: 'UNDER' },
  barrel: { x: 34, y: 27, ax: 31, ay: 15, label: 'BARREL' },
};

/**
 * Hit-test priority, back to front. Frame reskins cover the whole receiver -- a
 * camo overlay paints nearly as many pixels as the gun itself -- so if they sit
 * on top they swallow every click meant for the parts bolted onto them. Drawing
 * them first puts them at the bottom of both the visual and the hit stack, and
 * a reskinned frame under its fittings is the right way round anyway.
 */
const SLOT_DEPTH = ['camo', 'unique', 'barrel', 'underbarrel', 'rail'];

/** Rebuilds the src DmIcon would have used, so the sprite can live inside an SVG. */
const iconUrl = (icon, iconState) => {
  const ref = globalThis.Byond?.iconRefMap?.[icon];
  if (!ref || !iconState) {
    return null;
  }
  return `${ref}?state=${iconState}&dir=2&movement=false&frame=1`;
};

const heatColor = (percent) => {
  if (percent >= 70) {
    return 'bad';
  }
  if (percent >= 40) {
    return 'average';
  }
  return 'good';
};

/** A single big readout tile in the status strip. */
const Gauge = (props) => {
  const { label, value, sub, onClick, active, color } = props;
  return (
    <Section
      fill
      onClick={onClick}
      style={onClick ? { cursor: 'pointer' } : undefined}
    >
      <Box
        fontFamily="monospace"
        fontSize="0.85rem"
        color={active ? MFD.selected : 'label'}
      >
        {label}
      </Box>
      <Box fontFamily="monospace" fontSize="1.6rem" bold color={color}>
        {value}
      </Box>
      {!!sub && (
        <Box fontFamily="monospace" fontSize="0.8rem" color="label">
          {sub}
        </Box>
      )}
    </Section>
  );
};

/** The always-visible top strip: shots, charge, thermal, integrity. */
const StatusStrip = (props) => {
  const { data, selected, onSelect } = props;
  const {
    has_cell,
    cell_data,
    has_emitter,
    phase_emitter_data,
    gun_heat_dissipation,
  } = data;

  const chargePercent = has_cell
    ? (cell_data.charge / cell_data.max_charge) * 100
    : 0;
  let chargeColor = 'good';
  if (chargePercent <= 25) {
    chargeColor = 'bad';
  } else if (chargePercent <= 50) {
    chargeColor = 'average';
  }
  const heatPercent = has_emitter ? phase_emitter_data.heat_percent : 0;

  return (
    <Stack>
      <Stack.Item grow basis={0}>
        <Gauge
          label="SHOTS"
          value={has_cell ? cell_data.shots_left : '--'}
          sub={has_cell ? `${cell_data.shot_cost} MF each` : 'no cell'}
          color={has_cell ? chargeColor : 'bad'}
          active={selected === 'cell'}
          onClick={() => onSelect('cell')}
        />
      </Stack.Item>
      <Stack.Item grow basis={0}>
        <Gauge
          label="CELL"
          value={`${toFixed(chargePercent, 0)}%`}
          sub={
            has_cell
              ? `${cell_data.charge} / ${cell_data.max_charge} MF`
              : 'no cell seated'
          }
          color={has_cell ? chargeColor : 'bad'}
          active={selected === 'cell'}
          onClick={() => onSelect('cell')}
        />
      </Stack.Item>
      <Stack.Item grow basis={0}>
        <Gauge
          label="THERMAL"
          value={has_emitter ? `${toFixed(heatPercent, 0)}%` : '--'}
          sub={
            has_emitter
              ? `throttle ${phase_emitter_data.throttle_percentage}% | -${phase_emitter_data.heat_dissipation_per_tick}/t`
              : 'no emitter'
          }
          color={has_emitter ? heatColor(heatPercent) : 'bad'}
          active={selected === 'emitter'}
          onClick={() => onSelect('emitter')}
        />
      </Stack.Item>
      <Stack.Item grow basis={0}>
        <Gauge
          label="INTEGRITY"
          value={
            has_emitter ? `${toFixed(phase_emitter_data.integrity, 0)}%` : '--'
          }
          sub={`frame dissipation ${gun_heat_dissipation}`}
          color={
            has_emitter && phase_emitter_data.integrity < 50 ? 'bad' : 'good'
          }
          active={selected === 'emitter'}
          onClick={() => onSelect('emitter')}
        />
      </Stack.Item>
    </Stack>
  );
};

/** The things you want without hunting through the readout for them. */
const QuickActions = (props) => {
  const { act, data } = props;
  const { has_cell, has_emitter, phase_emitter_data } = data;
  return (
    <Section>
      <Button
        icon="snowflake"
        disabled={!has_emitter}
        selected={has_emitter && !!phase_emitter_data.cooling_system}
        tooltip="Toggle the emitter's active cooling system"
        onClick={() => act('toggle_cooling_system')}
      >
        COOLING
      </Button>
      {has_emitter && !!phase_emitter_data.hacked && (
        <Button
          icon="bolt"
          color="bad"
          tooltip="Remove the safety governor on the phase emitter"
          onClick={() => act('overclock_emitter')}
        >
          OVERCLOCK
        </Button>
      )}
      <Button
        icon="eject"
        disabled={!has_cell}
        tooltip="Drop the power cell into your hands"
        onClick={() => act('eject_cell')}
      >
        EJECT CELL
      </Button>
      <Button
        icon="eject"
        disabled={!has_emitter}
        tooltip="Pull the phase emitter out of the frame"
        onClick={() => act('eject_emitter')}
      >
        EJECT EMITTER
      </Button>
    </Section>
  );
};

/**
 * The weapon as it actually looks: base sprite, the frame's own overlays, then
 * one layer per attachment. Attachment layers hit-test on their painted pixels,
 * so clicking the scope picks the scope. Empty bays get a ring instead.
 */
const Schematic = (props) => {
  const { gunIcon, gunIconState, frameOverlays, attachments, emptySlots } =
    props;
  const { selected, hovered, onSelect, onHover } = props;

  const base = iconUrl(gunIcon, gunIconState);
  if (!base) {
    return <NoticeBox>SPRITE FEED UNAVAILABLE</NoticeBox>;
  }

  return (
    <svg
      viewBox={`0 0 ${ICON_W} ${ICON_H}`}
      width="100%"
      style={{ imageRendering: 'pixelated', display: 'block' }}
    >
      <defs>
        <filter
          id="mfd-outline"
          x="-25%"
          y="-25%"
          width="150%"
          height="150%"
          colorInterpolationFilters="sRGB"
        >
          <feMorphology
            in="SourceAlpha"
            operator="dilate"
            radius="1"
            result="fat"
          />
          <feFlood floodColor={MFD.selected} result="tint" />
          <feComposite in="tint" in2="fat" operator="in" result="ring" />
          <feMerge>
            <feMergeNode in="ring" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      <image
        href={base}
        x={0}
        y={0}
        width={ICON_W}
        height={ICON_H}
        style={{ pointerEvents: 'none' }}
      />
      {frameOverlays.map((state) => {
        const url = iconUrl(gunIcon, state);
        return (
          url && (
            <image
              key={state}
              href={url}
              x={0}
              y={0}
              width={ICON_W}
              height={ICON_H}
              style={{ pointerEvents: 'none' }}
            />
          )
        );
      })}

      {[...attachments]
        .sort(
          (a, b) =>
            SLOT_DEPTH.indexOf(a.slot_id) - SLOT_DEPTH.indexOf(b.slot_id),
        )
        .map((attachment) => {
          const url = iconUrl(gunIcon, attachment.overlay_state);
          if (!url) {
            return null;
          }
          const lit =
            selected === attachment.slot_id || hovered === attachment.slot_id;
          return (
            <image
              key={attachment.ref}
              href={url}
              x={0}
              y={0}
              width={ICON_W}
              height={ICON_H}
              pointerEvents="visiblePainted"
              filter={lit ? 'url(#mfd-outline)' : undefined}
              style={{ cursor: 'pointer' }}
              onClick={() => onSelect(attachment.slot_id)}
              onMouseEnter={() => onHover(attachment.slot_id)}
              onMouseLeave={() => onHover(null)}
            />
          );
        })}

      {emptySlots.map((slot) => {
        const anchor = SLOT_ANCHORS[slot];
        if (!anchor) {
          return null;
        }
        const lit = selected === slot || hovered === slot;
        const stroke = lit ? MFD.selected : MFD.wire;
        return (
          <g
            key={slot}
            style={{ cursor: 'pointer' }}
            onClick={() => onSelect(slot)}
            onMouseEnter={() => onHover(slot)}
            onMouseLeave={() => onHover(null)}
          >
            {/* leader from the ring to the part of the frame this bay serves */}
            <line
              x1={anchor.x}
              y1={anchor.y}
              x2={anchor.ax}
              y2={anchor.ay}
              stroke={stroke}
              strokeWidth={0.35}
              opacity={0.75}
            />
            <circle cx={anchor.ax} cy={anchor.ay} r={0.6} fill={stroke} />
            {/* transparent pad so the ring is easy to hit, not just its stroke */}
            <circle cx={anchor.x} cy={anchor.y} r={3.4} fill="transparent" />
            <circle
              cx={anchor.x}
              cy={anchor.y}
              r={2.6}
              fill="transparent"
              stroke={stroke}
              strokeWidth={0.6}
              strokeDasharray="1.4 1"
            />
          </g>
        );
      })}
    </svg>
  );
};

const EmitterPanel = (props) => {
  const { act, emitter, present } = props;
  if (!present) {
    return <NoticeBox danger>NO PHASE EMITTER SEATED</NoticeBox>;
  }
  return (
    <>
      {!!emitter.damaged && <NoticeBox danger>EMITTER DAMAGED</NoticeBox>}
      <LabeledList>
        <LabeledList.Item label="Unit">{emitter.type}</LabeledList.Item>
        <LabeledList.Item label="Integrity">
          <ProgressBar
            value={emitter.integrity}
            minValue={0}
            maxValue={100}
            color={emitter.integrity < 50 ? 'bad' : 'good'}
          >
            {toFixed(emitter.integrity, 1)}%
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Thermal">
          <ProgressBar
            value={emitter.current_heat}
            minValue={0}
            maxValue={emitter.max_heat}
            color={heatColor(emitter.heat_percent)}
          >
            {emitter.current_heat} / {emitter.max_heat}
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Cycle time">
          {emitter.process_time}
        </LabeledList.Item>
        <LabeledList.Item label="Active cooling">
          <Button
            icon="snowflake"
            selected={!!emitter.cooling_system}
            onClick={() => act('toggle_cooling_system')}
          >
            {emitter.cooling_system
              ? `ENGAGED (${emitter.cooling_system_rate}/tick)`
              : 'DISENGAGED'}
          </Button>
        </LabeledList.Item>
      </LabeledList>
      <Box mt={1}>
        {!!emitter.hacked && (
          <Button
            icon="bolt"
            color="bad"
            onClick={() => act('overclock_emitter')}
          >
            OVERCLOCK
          </Button>
        )}
        <Button icon="eject" onClick={() => act('eject_emitter')}>
          EJECT EMITTER
        </Button>
      </Box>
    </>
  );
};

const CellPanel = (props) => {
  const { act, cell, present } = props;
  if (!present) {
    return <NoticeBox danger>NO CELL SEATED</NoticeBox>;
  }
  return (
    <>
      {!!cell.status && <NoticeBox danger>CELL MELTDOWN IMMINENT</NoticeBox>}
      <LabeledList>
        <LabeledList.Item label="Unit">{cell.type}</LabeledList.Item>
        <LabeledList.Item label="Charge">
          {cell.charge} / {cell.max_charge} MF
        </LabeledList.Item>
        <LabeledList.Item label="Remaining">
          {cell.shots_left} shots at {cell.shot_cost} MF
        </LabeledList.Item>
        <LabeledList.Item label="Modules">
          {cell.attachments.length
            ? cell.attachments.join(', ')
            : 'None installed'}
        </LabeledList.Item>
      </LabeledList>
      <Box mt={1}>
        <Button icon="eject" onClick={() => act('eject_cell')}>
          EJECT CELL
        </Button>
      </Box>
    </>
  );
};

const AttachmentPanel = (props) => {
  const { act, attachment, label } = props;
  if (!attachment) {
    return <NoticeBox>{label} BAY EMPTY</NoticeBox>;
  }
  return (
    <>
      <Box color="label" mb={1}>
        {attachment.desc}
      </Box>
      <LabeledList>
        <LabeledList.Item label="Bay">{attachment.slot}</LabeledList.Item>
        {!!attachment.information && (
          <LabeledList.Item label="Readout">
            {attachment.information}
          </LabeledList.Item>
        )}
      </LabeledList>
      <Box mt={1}>
        {!!attachment.has_modifications &&
          attachment.modify.map((option) => (
            <Button
              key={option.reference}
              icon={option.icon}
              color={option.color}
              onClick={() =>
                act('modify_attachment', {
                  attachment_ref: attachment.ref,
                  modify_ref: option.reference,
                })
              }
            >
              {option.title}
            </Button>
          ))}
        <Button
          icon="wrench"
          color="bad"
          onClick={() =>
            act('remove_attachment', { attachment_ref: attachment.ref })
          }
        >
          REMOVE
        </Button>
      </Box>
    </>
  );
};

export const MicrofusionGunControl = (props) => {
  const { act, data } = useBackend();
  const {
    gun_name,
    gun_desc,
    gun_icon,
    gun_icon_state,
    frame_overlays = [],
    has_cell,
    cell_data,
    has_emitter,
    phase_emitter_data,
    attachments = [],
    slots = [],
  } = data;

  const [selected, setSelected] = useState('cell');
  const [hovered, setHovered] = useState(null);

  const bySlot = {};
  for (const attachment of attachments) {
    bySlot[attachment.slot_id] = attachment;
  }
  const emptySlots = slots.filter((slot) => !bySlot[slot]);

  let panelTitle = 'Readout';
  if (selected === 'cell') {
    panelTitle = 'Power Cell';
  } else if (selected === 'emitter') {
    panelTitle = 'Phase Emitter';
  } else if (bySlot[selected]) {
    panelTitle = bySlot[selected].name;
  } else if (SLOT_ANCHORS[selected]) {
    panelTitle = SLOT_ANCHORS[selected].label;
  }

  return (
    <Window
      title={`Micron Control Systems Incorporated: ${gun_name}`}
      width={820}
      height={620}
    >
      <Window.Content scrollable>
        <Stack fill vertical>
          <Stack.Item>
            <StatusStrip
              data={data}
              selected={selected}
              onSelect={setSelected}
            />
          </Stack.Item>
          <Stack.Item>
            <QuickActions act={act} data={data} />
          </Stack.Item>
          <Stack.Item grow>
            <Stack fill>
              <Stack.Item grow={3}>
                <Section fill title={gun_name}>
                  <Box
                    backgroundColor={MFD.glass}
                    style={{ border: `1px solid ${MFD.wire}` }}
                    p={2}
                  >
                    <Schematic
                      gunIcon={gun_icon}
                      gunIconState={gun_icon_state}
                      frameOverlays={frame_overlays}
                      attachments={attachments}
                      emptySlots={emptySlots}
                      selected={selected}
                      hovered={hovered}
                      onSelect={setSelected}
                      onHover={setHovered}
                    />
                  </Box>
                  <Box mt={1} color="label" fontSize="0.9rem">
                    {gun_desc}
                  </Box>
                  <Box mt={1} color="label" fontSize="0.85rem">
                    Click a fitted part to inspect it, or a dashed ring for an
                    empty bay.
                  </Box>
                </Section>
              </Stack.Item>
              <Stack.Item grow={2}>
                <Section fill scrollable title={panelTitle}>
                  {selected === 'emitter' && (
                    <EmitterPanel
                      act={act}
                      emitter={phase_emitter_data}
                      present={has_emitter}
                    />
                  )}
                  {selected === 'cell' && (
                    <CellPanel act={act} cell={cell_data} present={has_cell} />
                  )}
                  {selected !== 'emitter' && selected !== 'cell' && (
                    <AttachmentPanel
                      act={act}
                      attachment={bySlot[selected]}
                      label={SLOT_ANCHORS[selected]?.label || 'THIS'}
                    />
                  )}
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

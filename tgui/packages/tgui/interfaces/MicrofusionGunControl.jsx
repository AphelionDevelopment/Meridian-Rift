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

// Schematic palette. The window is dark, so this is a phosphor-on-glass readout.
const MFD = {
  wire: '#2f8f6e',
  wireBright: '#4fe3ab',
  fill: 'rgba(63, 214, 160, 0.08)',
  empty: '#31514a',
  text: '#8ff5cd',
  selected: '#ffd964',
  fault: '#ff5f56',
};

// Where each bay sits on the schematic below. Keys match the slot ids the gun reports.
const NODES = [
  { id: 'unique', label: 'UNIQUE', x: 52, y: 91 },
  { id: 'camo', label: 'FRAME', x: 110, y: 83 },
  { id: 'rail', label: 'RAIL', x: 175, y: 48 },
  { id: 'cell', label: 'CELL', x: 175, y: 132, fixed: true },
  { id: 'emitter', label: 'EMITTER', x: 240, y: 82, fixed: true },
  { id: 'underbarrel', label: 'UNDER', x: 278, y: 110 },
  { id: 'barrel', label: 'BARREL', x: 348, y: 80 },
];

const heatColor = (percent) => {
  if (percent >= 70) {
    return 'bad';
  }
  if (percent >= 40) {
    return 'average';
  }
  return 'good';
};

/** One selectable bay on the schematic. */
const SchematicNode = (props) => {
  const { node, state, selected, onSelect } = props;
  const isFault = state === 'fault';
  const isFilled = state === 'filled' || isFault;
  let stroke = MFD.empty;
  if (isFault) {
    stroke = MFD.fault;
  } else if (isFilled) {
    stroke = MFD.wireBright;
  }

  return (
    <g onClick={() => onSelect(node.id)} style={{ cursor: 'pointer' }}>
      {selected && (
        <circle
          cx={node.x}
          cy={node.y}
          r={13}
          fill="none"
          stroke={MFD.selected}
          strokeWidth={1.5}
        />
      )}
      <circle
        cx={node.x}
        cy={node.y}
        r={8}
        fill={isFilled ? MFD.fill : 'transparent'}
        stroke={stroke}
        strokeWidth={1.5}
        strokeDasharray={isFilled ? undefined : '3 2'}
      />
      {isFilled && <circle cx={node.x} cy={node.y} r={3} fill={stroke} />}
      <text
        x={node.x}
        y={node.y + 24}
        textAnchor="middle"
        fontSize={9}
        fontFamily="monospace"
        fill={selected ? MFD.selected : MFD.text}
      >
        {node.label}
      </text>
    </g>
  );
};

/** Wireframe side elevation of the weapon with every bay marked. */
const Schematic = (props) => {
  const { stateFor, selected, onSelect } = props;
  const line = {
    fill: 'none',
    stroke: MFD.wire,
    strokeWidth: 1.5,
    strokeLinejoin: 'round',
  };

  return (
    <svg viewBox="0 0 400 175" width="100%" style={{ display: 'block' }}>
      {/* grid backdrop */}
      {[...Array(9).keys()].map((i) => (
        <line
          key={`h${i}`}
          x1={0}
          y1={i * 20}
          x2={400}
          y2={i * 20}
          stroke={MFD.wire}
          strokeWidth={0.3}
          opacity={0.25}
        />
      ))}
      {[...Array(20).keys()].map((i) => (
        <line
          key={`v${i}`}
          x1={i * 20}
          y1={0}
          x2={i * 20}
          y2={175}
          stroke={MFD.wire}
          strokeWidth={0.3}
          opacity={0.25}
        />
      ))}

      {/* stock and receiver */}
      <path d="M22 78 L86 70 L86 104 L22 100 Z" {...line} />
      <path d="M86 62 L250 62 L250 104 L86 104 Z" {...line} />
      {/* top rail */}
      <path d="M120 54 L232 54 L232 62 L120 62 Z" {...line} />
      {/* grip */}
      <path d="M108 104 L136 104 L128 142 L106 142 Z" {...line} />
      {/* cell well */}
      <path d="M152 104 L200 104 L196 146 L156 146 Z" {...line} />
      {/* emitter housing and barrel */}
      <path d="M250 70 L286 70 L286 94 L250 94 Z" {...line} />
      <path d="M286 74 L372 74 L372 88 L286 88 Z" {...line} />
      <path d="M372 70 L384 70 L384 92 L372 92 Z" {...line} />
      {/* underbarrel rail */}
      <path d="M256 94 L304 94 L304 100 L256 100 Z" {...line} />
      {/* bore centreline */}
      <line
        x1={90}
        y1={81}
        x2={384}
        y2={81}
        stroke={MFD.wire}
        strokeWidth={0.6}
        strokeDasharray="6 4"
        opacity={0.7}
      />

      {NODES.map((node) => (
        <SchematicNode
          key={node.id}
          node={node}
          state={stateFor(node)}
          selected={selected === node.id}
          onSelect={onSelect}
        />
      ))}
    </svg>
  );
};

/** Readout for the phase emitter bay. */
const EmitterPanel = (props) => {
  const { act, emitter, present } = props;
  if (!present) {
    return <NoticeBox danger>NO PHASE EMITTER SEATED</NoticeBox>;
  }
  const percent = emitter.heat_percent;
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
            color={heatColor(percent)}
          >
            {emitter.current_heat} / {emitter.max_heat} ({toFixed(percent, 1)}%)
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Throttle at">
          {emitter.throttle_percentage}%
        </LabeledList.Item>
        <LabeledList.Item label="Dissipation">
          {emitter.heat_dissipation_per_tick} / tick
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

/** Readout for the cell bay. */
const CellPanel = (props) => {
  const { act, cell, present } = props;
  if (!present) {
    return <NoticeBox danger>NO CELL SEATED</NoticeBox>;
  }
  const percent = (cell.charge / cell.max_charge) * 100;
  let color = 'good';
  if (percent <= 25) {
    color = 'bad';
  } else if (percent <= 50) {
    color = 'average';
  }
  return (
    <>
      {!!cell.status && <NoticeBox danger>CELL MELTDOWN IMMINENT</NoticeBox>}
      <LabeledList>
        <LabeledList.Item label="Unit">{cell.type}</LabeledList.Item>
        <LabeledList.Item label="Charge">
          <ProgressBar
            value={cell.charge}
            minValue={0}
            maxValue={cell.max_charge}
            color={color}
          >
            {cell.charge} / {cell.max_charge} MF
          </ProgressBar>
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

/** Readout for one attachment bay. */
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
    gun_heat_dissipation,
    has_cell,
    cell_data,
    has_emitter,
    phase_emitter_data,
    attachments = [],
    slots = [],
  } = data;

  const [selected, setSelected] = useState('emitter');

  // Bays this frame actually has, plus the two fixed modules.
  const bySlot = {};
  for (const attachment of attachments) {
    bySlot[attachment.slot_id] = attachment;
  }
  const nodes = NODES.filter(
    (node) => node.fixed || slots.indexOf(node.id) !== -1,
  );

  const stateFor = (node) => {
    if (node.id === 'cell') {
      if (!has_cell) {
        return 'empty';
      }
      return cell_data.status ? 'fault' : 'filled';
    }
    if (node.id === 'emitter') {
      if (!has_emitter) {
        return 'empty';
      }
      return phase_emitter_data.damaged ? 'fault' : 'filled';
    }
    return bySlot[node.id] ? 'filled' : 'empty';
  };

  const activeNode = nodes.find((node) => node.id === selected) || nodes[0];
  const activeId = activeNode?.id;

  let panelTitle = activeNode?.label;
  if (activeId !== 'cell' && activeId !== 'emitter' && bySlot[activeId]) {
    panelTitle = bySlot[activeId].name;
  }

  return (
    <Window
      title={'Micron Control Systems Incorporated: ' + gun_name}
      width={760}
      height={560}
    >
      <Window.Content scrollable>
        <Stack fill vertical>
          <Stack.Item>
            <Section title={gun_name}>
              <Box color="label">{gun_desc}</Box>
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            <Stack fill>
              <Stack.Item grow={3}>
                <Section
                  fill
                  title="Frame Schematic"
                  buttons={
                    <Box color="label" fontFamily="monospace">
                      FRAME DISSIPATION {gun_heat_dissipation}
                    </Box>
                  }
                >
                  <Box
                    backgroundColor="rgba(0, 20, 14, 0.6)"
                    style={{ border: `1px solid ${MFD.wire}` }}
                    p={1}
                  >
                    <Schematic
                      stateFor={stateFor}
                      selected={activeId}
                      onSelect={setSelected}
                    />
                  </Box>
                  <Box mt={1} color="label" fontSize="0.9rem">
                    Select a bay on the schematic to inspect it.
                  </Box>
                </Section>
              </Stack.Item>
              <Stack.Item grow={2}>
                <Section fill scrollable title={panelTitle}>
                  {activeId === 'emitter' && (
                    <EmitterPanel
                      act={act}
                      emitter={phase_emitter_data}
                      present={has_emitter}
                    />
                  )}
                  {activeId === 'cell' && (
                    <CellPanel act={act} cell={cell_data} present={has_cell} />
                  )}
                  {activeId !== 'emitter' && activeId !== 'cell' && (
                    <AttachmentPanel
                      act={act}
                      attachment={bySlot[activeId]}
                      label={activeNode?.label}
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

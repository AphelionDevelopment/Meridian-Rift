// THIS IS A NOVA SECTOR UI FILE
import { useState } from 'react';
import {
  Box,
  Button,
  Icon,
  Input,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Table,
  Tabs,
  Tooltip,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { createSearch } from 'tgui-core/string';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type DogmosCosts = {
  turfs: number;
  groups: number;
  highpressure: number;
  equalize: number;
  superconductivity: number;
  post_process: number;
};

type FireGroupEntry = {
  time: string;
  jump_to: string;
  area: string;
  peak_size: number;
};

type HighCostZoneEntry = {
  time: string;
  jump_to: string;
  area: string;
  reaction: string;
  cost_ms: number;
};

type ExplosionEntry = {
  time: string;
  jump_to: string;
  area: string;
  devastation_range: number;
  heavy_impact_range: number;
  light_impact_range: number;
  cause: string;
  index: number;
};

type ReactionOfInterestEntry = {
  time: string;
  jump_to: string;
  area: string;
  reaction: string;
  amount: number;
};

type BreachEntry = {
  time: string;
  jump_to: string;
  area: string;
  moles_lost: number;
};

type StructureOfInterestEntry = {
  ref: string;
  name: string;
  area: string;
  reason: string;
  pinned_at: string;
  expires: number | null;
};

type MachineBrowseEntry = {
  ref: string;
  name: string;
  area: string;
};

type Data = {
  active_size: number;
  hotspots_size: number;
  conducting_size: number;
  low_pressure_turfs: number;
  high_pressure_turfs: number;
  group_turfs_processed: number;
  equalize_processed: number;
  space_boundary_size: number;
  heat_telemetry: {
    graph_nodes: number;
    edge_attempts: number;
    edges_applied: number;
    lock_contention: number;
    registration_changes: number;
  };
  dogmos_costs: DogmosCosts;
  frozen: BooleanLike;
  show_all: BooleanLike;
  realistic_space_radiation: BooleanLike;
  equalize_enabled: BooleanLike;
  fire_count: number;
  showing_user: BooleanLike;
  kennel_slow_mode: BooleanLike;
  recent_fire_groups: FireGroupEntry[];
  recent_high_cost_zones: HighCostZoneEntry[];
  recent_explosions: ExplosionEntry[];
  recent_reactions_of_interest: ReactionOfInterestEntry[];
  recent_breaches: BreachEntry[];
  structures_of_interest: StructureOfInterestEntry[];
  atmos_machinery_browse?: MachineBrowseEntry[];
  kennel_fire_group_notable_size: number;
  kennel_reaction_magnitude_threshold: number;
  kennel_machine_cost_ms_threshold: number;
  kennel_profile_reactions: BooleanLike;
  kennel_high_cost_ms_threshold: number;
};

enum TABS {
  Overview = 'Overview',
  'Fire Groups' = 'Fire Groups',
  'High-Cost Zones' = 'High-Cost Zones',
  Explosions = 'Explosions',
  'Reactions of Interest' = 'Reactions of Interest',
  'Structures/Machines' = 'Structures/Machines',
  Breaches = 'Breaches',
}

// Same good/average/bad banding tgui-core's own ControllerOverview (the MC panel) uses for subsystem
// cost bars, scaled down to Dogmos' actual per-stage ms range - a full 0.5s-wait cycle rarely spends
// more than a couple of ms in any one stage, so "bad" here means genuinely worth a look, not just busy.
const STAGE_COST_RANGES = {
  good: [0, 4.99],
  average: [5, 9.99],
  bad: [10, Infinity],
} as const;
const STAGE_COST_MAX = 20;

type StageCostRowProps = {
  label: string;
  cost: number;
  active: boolean;
  inactiveTooltip?: string;
};

/// One row per Dogmos fire() stage - mirrors the MC panel's SubsystemRow (status icon + named
/// progress bar), swapping the generic play/pause icon for a paw print colored by the same
/// good/average/bad banding as the bar itself. `active={false}` (a stage gated off, e.g. Equalize
/// while equalize_enabled is off) greys the icon out rather than color-grading a cost that isn't
/// really running.
const StageCostRow = (props: StageCostRowProps) => {
  const { label, cost, active, inactiveTooltip } = props;
  const color = !active ? 'grey' : cost >= 10 ? 'bad' : cost >= 5 ? 'average' : 'good';
  return (
    <Table.Row>
      <Table.Cell collapsing align="center">
        {!active && inactiveTooltip ? (
          <Tooltip content={inactiveTooltip}>
            <Icon name="paw" color={color} />
          </Tooltip>
        ) : (
          <Icon name="paw" color={color} />
        )}
      </Table.Cell>
      <Table.Cell>
        <ProgressBar value={cost} maxValue={STAGE_COST_MAX} ranges={STAGE_COST_RANGES}>
          {label} {cost.toFixed(2)}ms
        </ProgressBar>
      </Table.Cell>
    </Table.Row>
  );
};

const OverviewPanel = (props) => {
  const { act, data } = useBackend<Data>();
  const costs = data.dogmos_costs || ({} as DogmosCosts);
  const equalizeActive = !!data.equalize_enabled;
  return (
    <>
      <Section
        title="Kennel Overview"
        buttons={
          <>
            <Button
              icon={data.frozen ? 'play' : 'pause'}
              color={data.frozen ? 'bad' : 'good'}
              onClick={() => act('toggle-freeze')}
            >
              {data.frozen ? 'Frozen' : 'Running'}
            </Button>
            <Button.Checkbox
              icon="eye"
              checked={data.showing_user}
              onClick={() => act('toggle_user_display')}
              tooltip="Turns on Dogmos' map overlays for you specifically: red breach tiles, orange high-cost zones, purple reactions of interest, cyan leashed structures. This is where overlays/debug visuals turn on."
            >
              Debug Overlays
            </Button.Checkbox>
            <Button.Checkbox
              icon="gauge-high"
              checked={data.kennel_slow_mode}
              onClick={() => act('toggle_kennel_slow_mode')}
              tooltip="ON (default): this panel only pushes cheap Overview data, and only every 4th subsystem cycle - safe for multiple simultaneous viewers. OFF: full live data every cycle, including the event-history tables and overlay candidates."
            >
              Slow Mode
            </Button.Checkbox>
            <Button.Checkbox
              icon="stopwatch"
              checked={data.kennel_profile_reactions}
              onClick={() => act('toggle_kennel_profile_reactions')}
              tooltip="OFF (default): no extra cost. ON: times every single reaction call in Rust and records the slow ones into High-Cost Zones - the one Kennel toggle with real per-reaction overhead."
            >
              Profile Reactions
            </Button.Checkbox>
          </>
        }
      >
        <Stack fill>
          <Stack.Item grow>
            <LabeledList>
              <LabeledList.Item label="Fire Count">
                {data.fire_count}
              </LabeledList.Item>
              <LabeledList.Item label="Active Turfs">
                {data.active_size}
              </LabeledList.Item>
              <LabeledList.Item label="Hotspots">
                {data.hotspots_size}
              </LabeledList.Item>
              <LabeledList.Item label="Superconductors">
                {data.conducting_size}
              </LabeledList.Item>
            </LabeledList>
          </Stack.Item>
          <Stack.Item grow>
            <LabeledList>
              <LabeledList.Item label="Space Boundary Nodes">
                {data.space_boundary_size}
              </LabeledList.Item>
              <LabeledList.Item label="Low / High Pressure Turfs">
                {data.low_pressure_turfs} / {data.high_pressure_turfs}
              </LabeledList.Item>
              <LabeledList.Item label="Group / Equalize Processed">
                {data.group_turfs_processed} / {data.equalize_processed}
              </LabeledList.Item>
              <LabeledList.Item label="Heat Graph Nodes">
                {data.heat_telemetry.graph_nodes}
              </LabeledList.Item>
              <LabeledList.Item label="Heat Edges (attempted / applied)">
                {data.heat_telemetry.edge_attempts} /{' '}
                {data.heat_telemetry.edges_applied}
              </LabeledList.Item>
              <LabeledList.Item label="Heat Lock Contention">
                {data.heat_telemetry.lock_contention}
              </LabeledList.Item>
              <LabeledList.Item label="Heat Registration Changes">
                {data.heat_telemetry.registration_changes}
              </LabeledList.Item>
            </LabeledList>
          </Stack.Item>
        </Stack>
      </Section>
      <Section title="Dogmos Stage Costs (Rust, per cycle)">
        <Table>
          <StageCostRow label="Gas FDM" cost={costs.turfs ?? 0} active />
          <StageCostRow
            label="Excited Groups"
            cost={costs.groups ?? 0}
            active
          />
          <StageCostRow
            label="High Pressure"
            cost={costs.highpressure ?? 0}
            active={equalizeActive}
            inactiveTooltip="Katmos Pressure Equalizer is off (below)"
          />
          <StageCostRow
            label="Equalize"
            cost={costs.equalize ?? 0}
            active={equalizeActive}
            inactiveTooltip="Katmos Pressure Equalizer is off (below)"
          />
          <StageCostRow
            label="Superconductivity"
            cost={costs.superconductivity ?? 0}
            active
          />
          <StageCostRow
            label="Post Process"
            cost={costs.post_process ?? 0}
            active
          />
        </Table>
      </Section>
      {!!data.kennel_slow_mode && (
        <NoticeBox>
          Slow mode is on - the Fire Groups, High-Cost Zones, Explosions,
          Reactions of Interest, Structures/Machines and Breaches tabs may be
          sparse or stale. Disable it above for live data.
        </NoticeBox>
      )}
      <Section title="Configuration">
        <Stack fill wrap>
          <Stack.Item grow basis="45%">
            <LabeledList>
              <LabeledList.Item label="Realistic Space Radiation">
                <Button.Checkbox
                  checked={data.realistic_space_radiation}
                  onClick={() => act('toggle_realistic_space_radiation')}
                  tooltip="ON: real Stefan-Boltzmann blackbody radiation (physically correct, weak near room temperature). OFF: fake vacuum sink (not physical, fast and legible)."
                />
              </LabeledList.Item>
              <LabeledList.Item label="Katmos Pressure Equalizer">
                <Button.Checkbox
                  checked={data.equalize_enabled}
                  onClick={() => act('toggle_equalize_enabled')}
                  tooltip="Whether Dogmos' katmos pressure equalizer (and hull-breach handling) runs as part of the gas FDM pass."
                />
              </LabeledList.Item>
            </LabeledList>
          </Stack.Item>
          <Stack.Item grow basis="45%">
            <LabeledList>
              <LabeledList.Item label="Fire Group Notable Size">
                <Input
                  width="4em"
                  value={`${data.kennel_fire_group_notable_size}`}
                  onChange={(value) =>
                    act('kennel_set_threshold', {
                      threshold: 'fire_group_notable_size',
                      value,
                    })
                  }
                />
              </LabeledList.Item>
              <LabeledList.Item label="Reaction of Interest Threshold">
                <Input
                  width="4em"
                  value={`${data.kennel_reaction_magnitude_threshold}`}
                  onChange={(value) =>
                    act('kennel_set_threshold', {
                      threshold: 'reaction_magnitude_threshold',
                      value,
                    })
                  }
                />
              </LabeledList.Item>
              <LabeledList.Item label="Machine Auto-Pin Threshold (ms)">
                <Input
                  width="4em"
                  value={`${data.kennel_machine_cost_ms_threshold}`}
                  onChange={(value) =>
                    act('kennel_set_threshold', {
                      threshold: 'machine_cost_ms_threshold',
                      value,
                    })
                  }
                />
              </LabeledList.Item>
              <LabeledList.Item label="High-Cost Reaction Threshold (ms)">
                <Input
                  width="4em"
                  value={`${data.kennel_high_cost_ms_threshold}`}
                  onChange={(value) =>
                    act('kennel_set_threshold', {
                      threshold: 'high_cost_ms_threshold',
                      value,
                    })
                  }
                />
              </LabeledList.Item>
            </LabeledList>
          </Stack.Item>
        </Stack>
      </Section>
    </>
  );
};

type Column<T> = {
  label: string;
  render: (entry: T) => React.ReactNode;
  collapsing?: boolean;
};

/**
 * Shared searchable/filterable table for the five recent_* event history tabs - they're all the same
 * shape (newest-first list, a jump_to ref, a handful of display columns), so one generic component
 * covers all of them instead of five near-identical copies.
 */
function EventHistoryTable<T extends { jump_to?: string }>(props: {
  entries: T[];
  columns: Column<T>[];
  searchKeys: (entry: T) => string;
  emptyText: string;
}) {
  const { act } = useBackend<Data>();
  const { entries, columns, searchKeys, emptyText } = props;
  const [searchText, setSearchText] = useState('');
  const filtered = searchText
    ? entries.filter(createSearch(searchText, searchKeys))
    : entries;
  return (
    <>
      <Input
        placeholder="Search..."
        value={searchText}
        onChange={(value) => setSearchText(value)}
        fluid
        mb={1}
      />
      {!filtered.length && <NoticeBox>{emptyText}</NoticeBox>}
      {!!filtered.length && (
        <Table>
          <Table.Row header>
            {columns.map((col) => (
              <Table.Cell key={col.label} collapsing={col.collapsing}>
                {col.label}
              </Table.Cell>
            ))}
            {!!entries[0]?.jump_to && <Table.Cell collapsing>Jump</Table.Cell>}
          </Table.Row>
          {filtered.map((entry, i) => (
            <tr key={i}>
              {columns.map((col) => (
                <td key={col.label}>{col.render(entry)}</td>
              ))}
              {!!entry.jump_to && (
                <td>
                  <Button
                    icon="crosshairs"
                    onClick={() =>
                      act('move-to-target', { spot: entry.jump_to })
                    }
                  />
                </td>
              )}
            </tr>
          ))}
        </Table>
      )}
    </>
  );
}

const FireGroupsPanel = (props) => {
  const { data } = useBackend<Data>();
  return (
    <Section
      title={`Recent Fire Groups (peak size >= ${data.kennel_fire_group_notable_size})`}
    >
      <EventHistoryTable
        entries={data.recent_fire_groups}
        searchKeys={(entry) => entry.area}
        emptyText="No notable fire groups recorded yet."
        columns={[
          { label: 'Time', render: (e) => e.time, collapsing: true },
          { label: 'Area', render: (e) => e.area },
          { label: 'Peak Size', render: (e) => e.peak_size, collapsing: true },
        ]}
      />
    </Section>
  );
};

const HighCostZonesPanel = (props) => {
  const { data } = useBackend<Data>();
  return (
    <Section
      title={`Recent High-Cost Reactions (single call >= ${data.kennel_high_cost_ms_threshold}ms)`}
    >
      {!data.kennel_profile_reactions && (
        <NoticeBox>
          Reaction profiling is off (Overview tab) - this list stays empty
          until it's enabled. It has a real, opt-in Rust-side cost per
          reaction call, so it defaults off.
        </NoticeBox>
      )}
      {!!data.kennel_profile_reactions && !data.recent_high_cost_zones.length && (
        <NoticeBox>
          Profiling is on - no reactions have crossed the threshold yet.
        </NoticeBox>
      )}
      <EventHistoryTable
        entries={data.recent_high_cost_zones}
        searchKeys={(entry) => `${entry.area} ${entry.reaction}`}
        emptyText=""
        columns={[
          { label: 'Time', render: (e) => e.time, collapsing: true },
          { label: 'Area', render: (e) => e.area },
          { label: 'Reaction', render: (e) => e.reaction },
          { label: 'Cost', render: (e) => `${e.cost_ms}ms`, collapsing: true },
        ]}
      />
    </Section>
  );
};

const ExplosionsPanel = (props) => {
  const { data } = useBackend<Data>();
  return (
    <Section title="Recent Explosions">
      <EventHistoryTable
        entries={data.recent_explosions}
        searchKeys={(entry) => `${entry.area} ${entry.cause}`}
        emptyText="No explosions recorded yet."
        columns={[
          { label: 'Time', render: (e) => e.time, collapsing: true },
          { label: 'Area', render: (e) => e.area },
          { label: 'Cause', render: (e) => e.cause },
          {
            label: 'Range (D/H/L)',
            render: (e) =>
              `${e.devastation_range}/${e.heavy_impact_range}/${e.light_impact_range}`,
            collapsing: true,
          },
        ]}
      />
    </Section>
  );
};

const ReactionsOfInterestPanel = (props) => {
  const { data } = useBackend<Data>();
  return (
    <Section
      title={`Recent Reactions of Interest (amount >= ${data.kennel_reaction_magnitude_threshold})`}
    >
      <EventHistoryTable
        entries={data.recent_reactions_of_interest}
        searchKeys={(entry) => `${entry.area} ${entry.reaction}`}
        emptyText="No notable reactions recorded yet."
        columns={[
          { label: 'Time', render: (e) => e.time, collapsing: true },
          { label: 'Area', render: (e) => e.area },
          { label: 'Reaction', render: (e) => e.reaction },
          { label: 'Amount', render: (e) => e.amount, collapsing: true },
        ]}
      />
    </Section>
  );
};

const BreachesPanel = (props) => {
  const { data } = useBackend<Data>();
  return (
    <Section title="Recent Breaches">
      <EventHistoryTable
        entries={data.recent_breaches}
        searchKeys={(entry) => entry.area}
        emptyText="No breaches recorded yet."
        columns={[
          { label: 'Time', render: (e) => e.time, collapsing: true },
          { label: 'Area', render: (e) => e.area },
          {
            label: 'Moles Lost',
            render: (e) => e.moles_lost,
            collapsing: true,
          },
        ]}
      />
    </Section>
  );
};

const StructuresPanel = (props) => {
  const { act, data } = useBackend<Data>();
  const [pinnedSearch, setPinnedSearch] = useState('');
  const [browseSearch, setBrowseSearch] = useState('');
  const pinned = pinnedSearch
    ? data.structures_of_interest.filter(
        createSearch(pinnedSearch, (e) => `${e.name} ${e.area} ${e.reason}`),
      )
    : data.structures_of_interest;
  const browse = data.atmos_machinery_browse || [];
  const browseFiltered = browseSearch
    ? browse.filter(createSearch(browseSearch, (e) => `${e.name} ${e.area}`))
    : browse;
  return (
    <>
      <Section title="Leashed / Flagged Structures &amp; Machines">
        <Input
          placeholder="Search leashed..."
          value={pinnedSearch}
          onChange={(value) => setPinnedSearch(value)}
          fluid
          mb={1}
        />
        {!pinned.length && (
          <NoticeBox>
            The kennel's empty - explosion causes, breach-adjacent machinery,
            and high per-cycle-cost machines auto-leash here, or leash one
            manually below.
          </NoticeBox>
        )}
        {!!pinned.length && (
          <Table>
            <Table.Row header>
              <Table.Cell>Name</Table.Cell>
              <Table.Cell>Area</Table.Cell>
              <Table.Cell>Reason</Table.Cell>
              <Table.Cell collapsing>Pinned At</Table.Cell>
              <Table.Cell collapsing />
            </Table.Row>
            {pinned.map((entry) => (
              <tr key={entry.ref}>
                <td>{entry.name}</td>
                <td>{entry.area}</td>
                <td>{entry.reason}</td>
                <td>{entry.pinned_at}</td>
                <td>
                  <Button
                    icon="crosshairs"
                    onClick={() =>
                      act('move-to-target', { spot: entry.ref })
                    }
                  />
                  <Button
                    icon="times"
                    color="bad"
                    tooltip="Unleash"
                    onClick={() =>
                      act('kennel_unpin', { ref: entry.ref })
                    }
                  />
                </td>
              </tr>
            ))}
          </Table>
        )}
      </Section>
      <Section title="Leash a Machine">
        {!data.atmos_machinery_browse && (
          <NoticeBox>
            Turn off Kennel Slow Mode (Overview tab) to browse and manually
            leash any registered atmos machine/canister - this list can be
            large, so it's not sent while slow mode is on.
          </NoticeBox>
        )}
        {!!data.atmos_machinery_browse && (
          <>
            <Input
              placeholder="Search machinery..."
              value={browseSearch}
              onChange={(value) => setBrowseSearch(value)}
              fluid
              mb={1}
            />
            <Table>
              {browseFiltered.slice(0, 100).map((entry) => (
                <tr key={entry.ref}>
                  <td>{entry.name}</td>
                  <td>{entry.area}</td>
                  <td>
                    <Button
                      icon="paw"
                      content="Leash"
                      onClick={() => act('kennel_pin', { ref: entry.ref })}
                    />
                  </td>
                </tr>
              ))}
            </Table>
            {browseFiltered.length > 100 && (
              <Box color="label">
                {browseFiltered.length - 100} more not shown - narrow your
                search.
              </Box>
            )}
          </>
        )}
      </Section>
    </>
  );
};

export const DogmosKennel = (props) => {
  const tabs = Object.keys(TABS);
  const [currentTab, setCurrentTab] = useState(tabs[0]);

  let componentShown;
  switch (currentTab) {
    case TABS['Fire Groups']:
      componentShown = <FireGroupsPanel />;
      break;
    case TABS['High-Cost Zones']:
      componentShown = <HighCostZonesPanel />;
      break;
    case TABS.Explosions:
      componentShown = <ExplosionsPanel />;
      break;
    case TABS['Reactions of Interest']:
      componentShown = <ReactionsOfInterestPanel />;
      break;
    case TABS['Structures/Machines']:
      componentShown = <StructuresPanel />;
      break;
    case TABS.Breaches:
      componentShown = <BreachesPanel />;
      break;
    case TABS.Overview:
    default:
      componentShown = <OverviewPanel />;
  }

  return (
    <Window title="🐾 Dogmos Kennel" width={900} height={680}>
      <Window.Content scrollable>
        <Tabs>
          {tabs.map((tab) => (
            <Tabs.Tab
              key={tab}
              selected={currentTab === tab}
              onClick={() => setCurrentTab(tab)}
            >
              {tab}
            </Tabs.Tab>
          ))}
        </Tabs>
        {componentShown}
      </Window.Content>
    </Window>
  );
};

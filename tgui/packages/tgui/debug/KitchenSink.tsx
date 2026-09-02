/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */
import { useAtom } from 'jotai';
import { useState } from 'react';
import { JSONTree } from 'react-json-tree';
import {
  Button,
  Divider,
  Dropdown,
  Input,
  LabeledList,
  Modal,
  NoticeBox,
  NumberInput,
  ProgressBar,
  Section,
  Slider,
  Stack,
  Table,
  Tabs,
  TextArea,
  Tooltip,
} from 'tgui-core/components';
import { useBackend } from '../backend';
import {
  MERIDIAN_BASE_THEME_IDS,
  MERIDIAN_BASE_THEME_OPTIONS,
  type MeridianBaseThemeId,
  tgui16,
} from '../constants/theme';
import { debugThemeAtom } from '../events/store';
import { Pane, Window } from '../layouts';
import { DiagnosticLoaderComparison } from './DiagnosticLoaderComparison';

type Props = {
  panel?: boolean;
};

enum Tab {
  Config = 'config',
  Data = 'data',
  Shared = 'shared',
  Chunks = 'outgoingPayloadQueues',
  Components = 'components',
  LoaderStudy = 'loader-study',
}

const tabs = [
  { name: 'Config', value: Tab.Config },
  { name: 'Data', value: Tab.Data },
  { name: 'Shared', value: Tab.Shared },
  { name: 'Chunks', value: Tab.Chunks },
] as const;

export function KitchenSink(props: Props) {
  const { panel } = props;

  const [activeTab, setActiveTab] = useState(Tab.Config);
  const [showModal, setShowModal] = useState(false);
  const [debugTheme, setDebugTheme] = useAtom(debugThemeAtom);

  const Layout = panel ? Pane : Window;

  const changeTheme = (direction: -1 | 1) => {
    const currentIndex = debugTheme
      ? MERIDIAN_BASE_THEME_IDS.indexOf(debugTheme)
      : direction > 0
        ? -1
        : 0;
    const nextIndex =
      (currentIndex + direction + MERIDIAN_BASE_THEME_IDS.length) %
      MERIDIAN_BASE_THEME_IDS.length;
    setDebugTheme(MERIDIAN_BASE_THEME_IDS[nextIndex]);
  };

  return (
    <Layout title="MeridianOS Development Showcase" width={800} height={720}>
      <Layout.Content>
        <Stack className="MeridianShowcase" vertical fill>
          <Stack.Item>
            <div
              className="MeridianShowcase__switcher"
              data-meridian-theme-switcher
            >
              <div>
                <strong>Development skin</strong>
                <span className="MeridianShowcase__themeDetail">
                  {debugTheme
                    ? MERIDIAN_BASE_THEME_OPTIONS.find(
                        ({ id }) => id === debugTheme,
                      )?.construction
                    : 'Inherit the interface or device theme'}
                </span>
              </div>
              <div className="MeridianShowcase__switcherControls">
                <Button
                  icon="undo"
                  selected={!debugTheme}
                  onClick={() => setDebugTheme(null)}
                >
                  Inherit
                </Button>
                <Button
                  aria-label="Previous MeridianOS skin"
                  icon="chevron-left"
                  onClick={() => changeTheme(-1)}
                />
                <Button
                  aria-label="Next MeridianOS skin"
                  icon="chevron-right"
                  onClick={() => changeTheme(1)}
                />
                <Dropdown
                  width="180px"
                  options={MERIDIAN_BASE_THEME_OPTIONS.map(({ id, name }) => ({
                    displayText: name,
                    value: id,
                  }))}
                  selected={debugTheme}
                  displayText={
                    debugTheme
                      ? MERIDIAN_BASE_THEME_OPTIONS.find(
                          ({ id }) => id === debugTheme,
                        )?.name
                      : 'Inherited'
                  }
                  onSelected={(value) =>
                    setDebugTheme(value as MeridianBaseThemeId)
                  }
                />
              </div>
            </div>
          </Stack.Item>
          <Stack.Item grow>
            <Stack fill>
              <Stack.Item grow>
                <Tabs vertical>
                  {tabs.map((tab) => (
                    <Tabs.Tab
                      key={tab.name}
                      className="candystripe"
                      selected={activeTab === tab.value}
                      onClick={() => setActiveTab(tab.value)}
                    >
                      {tab.name}
                    </Tabs.Tab>
                  ))}
                  <Divider />
                  <Tabs.Tab
                    selected={activeTab === Tab.Components}
                    onClick={() => setActiveTab(Tab.Components)}
                  >
                    Components
                  </Tabs.Tab>
                  <Tabs.Tab
                    selected={activeTab === Tab.LoaderStudy}
                    onClick={() => setActiveTab(Tab.LoaderStudy)}
                  >
                    Loader study
                  </Tabs.Tab>
                </Tabs>
              </Stack.Item>
              <Stack.Item grow={4}>
                {activeTab === Tab.Components ? (
                  <ComponentsPage onShowModal={() => setShowModal(true)} />
                ) : activeTab === Tab.LoaderStudy ? (
                  <DiagnosticLoaderComparison />
                ) : (
                  <TreePage tab={activeTab} />
                )}
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Layout.Content>
      {showModal && (
        <Modal onEscape={() => setShowModal(false)}>
          <h2>Bounded diagnostic modal</h2>
          <p>Opaque surface, strong boundary, retained Escape behavior.</p>
          <Button icon="check" onClick={() => setShowModal(false)}>
            Acknowledge
          </Button>
        </Modal>
      )}
    </Layout>
  );
}

function ComponentsPage(props: { onShowModal: () => void }) {
  const { onShowModal } = props;
  const [inputValue, setInputValue] = useState('Meridian relay 04');
  const [textValue, setTextValue] = useState(
    'Task-oriented notes remain readable at narrow widths.',
  );
  const [dropdownValue, setDropdownValue] = useState('Nominal');
  const [numberValue, setNumberValue] = useState(42);
  const [sliderValue, setSliderValue] = useState(64);
  const [checked, setChecked] = useState(true);
  const [radioValue, setRadioValue] = useState('primary');

  return (
    <Section fill scrollable title="MeridianOS component board">
      <div className="MeridianShowcase__board" data-meridian-component-board>
        <Section title="Control states">
          <div className="MeridianShowcase__controlRow">
            <Button>Rest</Button>
            <Button className="MeridianShowcase__forceHover">Hover</Button>
            <Button className="MeridianShowcase__forcePressed">Pressed</Button>
            <Button selected>Selected</Button>
            <Button disabled>Disabled</Button>
            <Button color="danger" icon="triangle-exclamation">
              Destructive
            </Button>
            <Button className="MeridianShowcase__forceFocus">Focus</Button>
          </div>
          <Tabs>
            <Tabs.Tab selected>Overview</Tabs.Tab>
            <Tabs.Tab>Telemetry</Tabs.Tab>
            <Tabs.Tab>Maintenance</Tabs.Tab>
          </Tabs>
        </Section>

        <Section title="Inputs and selection">
          <LabeledList>
            <LabeledList.Item label="Identifier">
              <Input
                fluid
                monospace
                value={inputValue}
                onChange={setInputValue}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Mode">
              <Dropdown
                fluid
                options={['Nominal', 'Standby', 'Isolated']}
                selected={dropdownValue}
                onSelected={setDropdownValue}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Threshold">
              <NumberInput
                value={numberValue}
                minValue={0}
                maxValue={100}
                unit="%"
                onChange={setNumberValue}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Gain">
              <Slider
                value={sliderValue}
                minValue={0}
                maxValue={100}
                onChange={(_, value) => setSliderValue(value)}
              />
            </LabeledList.Item>
          </LabeledList>
          <TextArea
            fluid
            height="72px"
            value={textValue}
            onChange={setTextValue}
          />
          <div className="MeridianShowcase__controlRow">
            <Button.Checkbox
              checked={checked}
              onClick={() => setChecked(!checked)}
            >
              Confirmed
            </Button.Checkbox>
            {['primary', 'backup'].map((value) => (
              <label className="MeridianShowcase__radio" key={value}>
                <input
                  type="radio"
                  name="showcase-channel"
                  value={value}
                  checked={radioValue === value}
                  onChange={() => setRadioValue(value)}
                />
                {value === 'primary' ? 'Primary channel' : 'Backup channel'}
              </label>
            ))}
          </div>
        </Section>

        <Section title="Progress and status">
          <ProgressBar value={0.64}>64% nominal</ProgressBar>
          <ProgressBar className="ProgressBar--segmented" value={0.37}>
            37% segmented opt-in
          </ProgressBar>
          <NoticeBox info>
            Information has a fixed blue rail and marker.
          </NoticeBox>
          <NoticeBox success>Nominal state has a fixed green rail.</NoticeBox>
          <NoticeBox>Warning state has a fixed amber rail.</NoticeBox>
          <NoticeBox danger>Danger state has a fixed red rail.</NoticeBox>
        </Section>

        <Section title="Data plane">
          <Table>
            <Table.Row header>
              <Table.Cell>Channel</Table.Cell>
              <Table.Cell>Status</Table.Cell>
              <Table.Cell collapsing>Reading</Table.Cell>
            </Table.Row>
            <Table.Row>
              <Table.Cell>Coolant loop</Table.Cell>
              <Table.Cell>Nominal</Table.Cell>
              <Table.Cell className="ConsoleReading" collapsing>
                018.4 K
              </Table.Cell>
            </Table.Row>
            <Table.Row>
              <Table.Cell>Relay bank</Table.Cell>
              <Table.Cell>
                <Button compact>Inspect</Button>
              </Table.Cell>
              <Table.Cell className="ConsoleReading" collapsing>
                12 / 12
              </Table.Cell>
            </Table.Row>
          </Table>
        </Section>

        <Section title="Hierarchy, overlay, and narrow layout">
          <h2 className="ConsoleDisplay">SYSTEM INSTRUMENTS</h2>
          <p>
            Body copy keeps the system sans stack.{' '}
            <span className="ConsoleReading">ID MR-042 / 13:37</span>
          </p>
          <Section title="Quiet nested section">
            Nested panels use a recessed plane and divider instead of another
            decorative frame.
          </Section>
          <Section
            className="MeridianShowcase__scrollSection"
            scrollable
            title="Scrollable section"
          >
            {Array.from({ length: 8 }, (_, index) => (
              <p key={index}>
                Telemetry record {String(index + 1).padStart(2, '0')}
              </p>
            ))}
          </Section>
          <div className="MeridianShowcase__controlRow">
            <Tooltip content="Opaque bounded tooltip with retained semantics">
              <Button icon="circle-info">Tooltip</Button>
            </Tooltip>
            <Button icon="window-maximize" onClick={onShowModal}>
              Modal
            </Button>
          </div>
        </Section>
      </div>
    </Section>
  );
}

type TreeProps = {
  tab: Tab;
};

function TreePage(props: TreeProps) {
  const { tab } = props;

  const backend = useBackend();
  const inView = backend[tab];

  return (
    <Section
      fill
      scrollable
      title={`${backend.config.interface.name ?? 'TGUI'} data`}
    >
      <div style={{ border: 'thin solid var(--color-base)' }}>
        <JSONTree data={inView} theme={tgui16} />
      </div>
    </Section>
  );
}

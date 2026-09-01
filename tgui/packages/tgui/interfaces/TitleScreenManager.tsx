// THIS IS AN APHELION UI FILE
import {
  Button,
  Divider,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { loadedMappings } from '../assets';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import {
  type LobbyTitleArtVariant,
  type LobbyTitleTexture,
  type LobbyTitleTreatment,
  resolveLobbyScreenPresentation,
  TitleArtwork,
} from './common/TitleArtwork';

type ScreenOption = {
  /** Config file name, or null for the neutral Meridian Rift master. */
  name: string | null;
  isDefault: BooleanLike;
  isAlt: BooleanLike;
  url: string | null;
  variant: LobbyTitleArtVariant;
  bezel: BooleanLike;
  texture: LobbyTitleTexture;
  wordmark: BooleanLike;
};

type Choice = { id: string; name: string; desc: string };

type Data = {
  screens: ScreenOption[];
  markUrl: string | null;
  variants: Choice[];
  textures: Choice[];
  liveScreen: string | null;
  liveScreenManaged: BooleanLike;
  rotateTitleScreens: BooleanLike;
  draftScreen: string | null;
  draftScreenChosen: BooleanLike;
  draftVariant: LobbyTitleArtVariant;
  draftBezel: BooleanLike;
  draftTexture: LobbyTitleTexture;
  draftWordmark: BooleanLike;
  pending: BooleanLike;
};

const DEFAULT_SCREEN_LABEL = 'Meridian Rift (default)';
const ALT_SCREEN_LABEL = 'Meridian Rift (default, alt)';
const DEFAULT_SCREEN_KEY = '__default__';
const SCANLINE_ASSET = 'meridian_rift_scanlines_navarobl.png';

/** Strips the extension so a long file name still fits the row. */
function screenLabel(screen: ScreenOption): string {
  if (screen.isAlt) {
    return ALT_SCREEN_LABEL;
  }
  if (screen.isDefault || screen.name === null) {
    return DEFAULT_SCREEN_LABEL;
  }
  return screen.name.replace(/\.[a-z0-9]+$/i, '');
}

/**
 * The neutral master is tinted directly. Configured screens always use the
 * selected screen treatment, with the Meridian Rift mark as an optional
 * overlay.
 */
function draftTreatment(data: Data): LobbyTitleTreatment {
  const selected = data.screens.find(
    (screen) => screen.name === data.draftScreen,
  );
  if (selected?.isDefault || selected?.name === null) {
    return 'mask';
  }
  return data.draftWordmark ? 'overlay' : 'screen';
}

export function TitleScreenManager() {
  const { act, data } = useBackend<Data>();
  const {
    screens = [],
    variants = [],
    textures = [],
    markUrl,
    draftScreen,
    liveScreen,
  } = data;

  const selected = data.draftScreenChosen
    ? screens.find((screen) => screen.name === draftScreen)
    : undefined;
  const isDefaultScreen = !!(selected?.isDefault || selected?.name === null);
  const treatment = draftTreatment(data);

  return (
    <Window title="Lobby Title Screen" width={880} height={640}>
      <Window.Content>
        <Stack fill>
          <Stack.Item basis="19rem">
            <Section fill scrollable title="Title Screens">
              <Tabs vertical>
                {screens.map((screen) => (
                  <Tabs.Tab
                    key={screen.name ?? DEFAULT_SCREEN_KEY}
                    icon={
                      data.liveScreenManaged && screen.name === liveScreen
                        ? 'circle-check'
                        : undefined
                    }
                    selected={
                      !!data.draftScreenChosen && screen.name === draftScreen
                    }
                    onClick={() => act('select', { screen: screen.name ?? '' })}
                  >
                    {screenLabel(screen)}
                  </Tabs.Tab>
                ))}
              </Tabs>
            </Section>
          </Stack.Item>

          <Stack.Item grow>
            <Stack fill vertical>
              <Stack.Item grow>
                <Section fill title="Preview">
                  {!data.draftScreenChosen ? (
                    <NoticeBox info>
                      No editable title screen is selected. Choose a configured
                      title screen to preview or edit it.
                    </NoticeBox>
                  ) : selected?.url ? (
                    <div className="TitleScreenManager__preview">
                      <TitleArtwork
                        bezel={!!data.draftBezel}
                        markSrc={markUrl ?? undefined}
                        presentation={resolveLobbyScreenPresentation(
                          treatment,
                          !!selected.isAlt,
                        )}
                        src={selected.url}
                        texture={data.draftTexture}
                        textureSrc={loadedMappings[SCANLINE_ASSET]}
                        treatment={treatment}
                        variant={data.draftVariant}
                      />
                    </div>
                  ) : (
                    <NoticeBox>
                      This screen is no longer in the config directory.
                    </NoticeBox>
                  )}
                </Section>
              </Stack.Item>

              <Stack.Item>
                <Section title="Appearance">
                  {!data.draftScreenChosen ? (
                    <NoticeBox info>
                      Choose a configured title screen to edit its appearance.
                    </NoticeBox>
                  ) : (
                    <>
                      <LabeledList>
                        <LabeledList.Item label="Screen">
                          {variants.map((choice) => (
                            <Button
                              key={choice.id}
                              selected={data.draftVariant === choice.id}
                              tooltip={choice.desc}
                              onClick={() => act('set', { variant: choice.id })}
                            >
                              {choice.name}
                            </Button>
                          ))}
                        </LabeledList.Item>

                        <LabeledList.Item label="Scanlines">
                          {textures.map((choice) => (
                            <Button
                              key={choice.id}
                              selected={data.draftTexture === choice.id}
                              tooltip={choice.desc}
                              onClick={() => act('set', { texture: choice.id })}
                            >
                              {choice.name}
                            </Button>
                          ))}
                        </LabeledList.Item>

                        <LabeledList.Item label="Bezel">
                          <Button.Checkbox
                            checked={!!data.draftBezel}
                            tooltip="The monitor rim, independent of the screen effect"
                            onClick={() =>
                              act('set', { bezel: !data.draftBezel })
                            }
                          >
                            Show the monitor rim
                          </Button.Checkbox>
                        </LabeledList.Item>
                      </LabeledList>
                      {!isDefaultScreen && (
                        <Button.Checkbox
                          checked={!!data.draftWordmark}
                          mt={0.5}
                          onClick={() =>
                            act('set', { wordmark: !data.draftWordmark })
                          }
                        >
                          Display MERIDIAN RIFT
                        </Button.Checkbox>
                      )}
                    </>
                  )}

                  <Divider />

                  <Stack align="center">
                    <Stack.Item grow>
                      <Button.Checkbox
                        checked={!!data.rotateTitleScreens}
                        tooltip="Saves immediately without changing the current screen draft"
                        onClick={() =>
                          act('set_rotation', {
                            rotate: !data.rotateTitleScreens,
                          })
                        }
                      >
                        Rotate title screens each round
                      </Button.Checkbox>
                    </Stack.Item>
                    <Stack.Item>
                      <Button
                        disabled={!data.pending}
                        icon="rotate-left"
                        tooltip="Discard the draft and re-read what is live"
                        onClick={() => act('revert')}
                      >
                        Revert
                      </Button>
                    </Stack.Item>
                    <Stack.Item>
                      <Button
                        color="good"
                        disabled={!data.pending}
                        icon="check"
                        tooltip="Applies to everyone and persists across rounds"
                        onClick={() => act('apply')}
                      >
                        Apply for everyone
                      </Button>
                    </Stack.Item>
                  </Stack>
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
}

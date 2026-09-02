/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import type { ComponentProps } from 'react'; // APHELION EDIT ADDITION
import { Box, Button } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { resolveAsset } from '../assets';
import { useBackend } from '../backend';
import { Window } from './Window';

export type MeridianOSData = { // APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: export type NTOSData = {
  comp_light_color: string;
  has_light: BooleanLike;
  id_name: string;
  light_on: BooleanLike;
  login: Login;
  pai: string | null;
  alert_style: number;
  alert_color: string;
  alert_name: string;
  PC_batteryicon: string | null;
  PC_batterypercent: string | null;
  PC_device_theme: string;
  PC_lowpower_mode: BooleanLike;
  PC_ntneticon: string;
  PC_programheaders: Program[];
  PC_showexitprogram: BooleanLike;
  PC_stationdate: string;
  PC_stationtime: string;
  programs: Program[];
  proposed_login: Login;
  removable_media: string[];
  show_imprint: BooleanLike;
};

// APHELION EDIT ADDITION START - MERIDIAN_UI
// APHELION EDIT ADDITION START - MERIDIAN_UI
/** @deprecated Use `MeridianOSData`. */
export type NTOSData = MeridianOSData;
// APHELION EDIT ADDITION END

// APHELION EDIT ADDITION END
type Program = {
  alert: BooleanLike;
  desc: string;
  header_program: BooleanLike;
  icon: string;
  name: string;
  running: BooleanLike;
};

type Login = {
  IDInserted?: BooleanLike;
  IDJob: string | null;
  IDName: string | null;
};

export const MeridianWindow = (props: ComponentProps<typeof Window>) => { // APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: export const NtosWindow = (props) => {
  const { title, width = 575, height = 700, children } = props;
  const { act, data } = useBackend<MeridianOSData>(); // APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: useBackend<NTOSData>();
  const {
    PC_device_theme,
    PC_batteryicon,
    PC_batterypercent,
    PC_ntneticon,
    PC_stationdate,
    PC_stationtime,
    PC_programheaders = [],
    PC_showexitprogram,
    PC_lowpower_mode,
  } = data;

  return (
    <Window title={title} width={width} height={height} theme={PC_device_theme}>
      {/* // APHELION EDIT REMOVAL START - MERIDIAN_UI
      <div className="NtosWindow">
        <div className="NtosWindow__header NtosHeader">
          <div className="NtosHeader__left">
      // APHELION EDIT REMOVAL END */}
      {/* APHELION EDIT ADDITION START - MERIDIAN_UI */}
      <div className="MeridianWindow NtosWindow">
        <div className="MeridianWindow__header NtosWindow__header MeridianHeader NtosHeader">
          <div className="MeridianHeader__left NtosHeader__left">
          {/* APHELION EDIT ADDITION END */}
            <Box inline bold mr={2}>
              <Button
                width="26px"
                lineHeight="22px"
                textAlign="left"
                tooltip={PC_stationdate}
                color="transparent"
                icon="calendar"
                tooltipPosition="bottom"
              />
              {PC_stationtime}
            </Box>
            <Box inline italic mr={2} opacity={0.33}>
              {(PC_device_theme === 'syndicate' && 'Syndix') || 'MeridianOS'} {/* APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: || 'NtOS' */}
              {!!PC_lowpower_mode && ' - RUNNING ON LOW POWER MODE'}
            </Box>
          </div>
          <div className="MeridianHeader__right NtosHeader__right"> {/* APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: className="NtosHeader__right" */}
            {PC_programheaders.map((header) => (
              <Box key={header.icon} inline mr={1}>
                <img
                  className="MeridianHeader__icon NtosHeader__icon" // APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: className="NtosHeader__icon"
                  src={resolveAsset(header.icon)}
                />
              </Box>
            ))}
            <Box inline>
              {PC_ntneticon && (
                <img
                  className="MeridianHeader__icon NtosHeader__icon" // APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: className="NtosHeader__icon"
                  src={resolveAsset(PC_ntneticon)}
                />
              )}
            </Box>
            {!!PC_batteryicon && (
              <Box inline mr={1}>
                <img
                  className="MeridianHeader__icon NtosHeader__icon" // APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: className="NtosHeader__icon"
                  src={resolveAsset(PC_batteryicon)}
                />
                {PC_batterypercent}
              </Box>
            )}
            {!!PC_showexitprogram && (
              <Button
                color="transparent"
                icon="window-minimize-o"
                tooltip="Minimize"
                tooltipPosition="bottom"
                onClick={() => act('PC_minimize')}
              />
            )}
            {!!PC_showexitprogram && (
              <Button
                color="transparent"
                icon="window-close-o"
                tooltip="Close"
                tooltipPosition="bottom-start"
                onClick={() => act('PC_exit')}
              />
            )}
            {!PC_showexitprogram && (
              <Button
                textAlign="center"
                color="transparent"
                icon="power-off"
                tooltip="Power off"
                tooltipPosition="bottom-start"
                onClick={() => act('PC_shutdown')}
              />
            )}
          </div>
        </div>
        {children}
      </div>
    </Window>
  );
};

/* // APHELION EDIT REMOVAL START - MERIDIAN_UI
const NtosWindowContent = (props) => {
*/ // APHELION EDIT REMOVAL END
// APHELION EDIT ADDITION START - MERIDIAN_UI
const MeridianWindowContent = (
  props: ComponentProps<typeof Window.Content>,
) => {
// APHELION EDIT ADDITION END
  return (
    <div className="MeridianWindow__content NtosWindow__content"> {/* APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: className="NtosWindow__content" */}
      <Window.Content {...props} />
    </div>
  );
};

MeridianWindow.Content = MeridianWindowContent; // APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: NtosWindow.Content = NtosWindowContent;

// APHELION EDIT ADDITION START - MERIDIAN_UI
/** @deprecated Use `MeridianWindow`. */
export const NtosWindow = MeridianWindow;
// APHELION EDIT ADDITION END

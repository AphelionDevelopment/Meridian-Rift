import { ByondUi } from 'tgui-core/components';
// APHELION EDIT ADDITION START - MERIDIAN_UI
import {
  PreferencesCharacterPreviewFrame,
  type PreferencesCharacterPreviewDecorationMode,
} from './PreferencesCharacterPreviewFrame';
// APHELION EDIT ADDITION END

export const CharacterPreview = (props: {
  decoration?: PreferencesCharacterPreviewDecorationMode; // APHELION EDIT ADDITION
  width?: string; // NOVA EDIT
  height: string;
  id: string;
}) => {
  // NOVA EDIT
  const { decoration = 'none', width = '272px' } = props; // APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: const { width = '272px' } = props;
  // NOVA EDIT END
  const preview = ( // APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: return (
    <ByondUi
      width={width} // NOVA EDIT
      height={props.height}
      params={{
        id: props.id,
        type: 'map',
      }}
    />
  );
// APHELION EDIT ADDITION START - MERIDIAN_UI

  if (decoration === 'none') {
    return preview;
  }

  return (
    <PreferencesCharacterPreviewFrame
      decoration={decoration}
      height={props.height}
      width={width}
    >
      {preview}
    </PreferencesCharacterPreviewFrame>
  );
// APHELION EDIT ADDITION END
};

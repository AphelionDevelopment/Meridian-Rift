import { ByondUi } from 'tgui-core/components';
import {
  PreferencesCharacterPreviewFrame,
  type PreferencesCharacterPreviewDecorationMode,
} from './PreferencesCharacterPreviewFrame';

export const CharacterPreview = (props: {
  decoration?: PreferencesCharacterPreviewDecorationMode;
  width?: string; // NOVA EDIT
  height: string;
  id: string;
}) => {
  // NOVA EDIT
  const { decoration = 'none', width = '272px' } = props;
  // NOVA EDIT END
  const preview = (
    <ByondUi
      width={width} // NOVA EDIT
      height={props.height}
      params={{
        id: props.id,
        type: 'map',
      }}
    />
  );

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
};

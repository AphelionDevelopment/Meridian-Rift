// THIS IS A NOVA SECTOR UI FILE
import type { FeatureChoiced } from '../../base';
import { FeatureDropdownWithPreviewButton } from './dropdown_with_preview_button';

export const character_scream: FeatureChoiced = {
  name: 'Character Scream',
  component: FeatureDropdownWithPreviewButton('play_scream_preview'),
};

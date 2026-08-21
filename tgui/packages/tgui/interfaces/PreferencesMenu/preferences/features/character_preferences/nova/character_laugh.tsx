// THIS IS A NOVA SECTOR UI FILE
import type { FeatureChoiced } from '../../base';
import { FeatureDropdownWithPreviewButton } from './dropdown_with_preview_button';

export const character_laugh: FeatureChoiced = {
  name: 'Character Laugh',
  component: FeatureDropdownWithPreviewButton('play_laugh_preview'),
};

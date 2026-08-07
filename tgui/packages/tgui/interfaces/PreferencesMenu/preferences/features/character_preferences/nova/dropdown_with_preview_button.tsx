// THIS IS A NOVA SECTOR UI FILE
import { useBackend } from 'tgui/backend';
import { Button, Stack } from 'tgui-core/components';

import type { FeatureChoicedServerData, FeatureValueProps } from '../../base';
import { FeatureDropdownInput } from '../../dropdowns';

export function FeatureDropdownWithPreviewButton(previewAction: string) {
  return (
    props: FeatureValueProps<string, string, FeatureChoicedServerData>,
  ) => {
    const { act } = useBackend();

    return (
      <Stack g={0.5}>
        <Stack.Item grow>
          <FeatureDropdownInput {...props} />
        </Stack.Item>
        <Stack.Item>
          <Button
            onClick={() => {
              act(previewAction);
            }}
            icon="play"
            width="100%"
            height="100%"
          />
        </Stack.Item>
      </Stack>
    );
  };
}

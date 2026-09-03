// THIS IS AN APHELION UI FILE
import type { CSSProperties, ReactNode } from 'react';
import { Section } from 'tgui-core/components';

import { CharacterPreview } from '../../common/CharacterPreview';
import type { PreferencesCharacterPreviewDecorationMode } from '../../common/PreferencesCharacterPreviewFrame';
import previewCalloutSchema from './augmentation-preview-callouts.json';

type AugmentationDecorationMode = Exclude<
  PreferencesCharacterPreviewDecorationMode,
  'none'
>;

export type AugmentsPreviewCalloutSide = 'bottom' | 'left' | 'right' | 'top';

export type AugmentsPreviewCallout = {
  edge: number;
  region: string;
  side: AugmentsPreviewCalloutSide;
  target: {
    x: number;
    y: number;
  };
};

export type AugmentsWorkbenchItem = {
  available?: boolean;
  label: string;
  region: string;
  summary: ReactNode;
};

const calloutSchema = previewCalloutSchema as {
  modes: Record<AugmentationDecorationMode, string>;
  profiles: Record<string, AugmentsPreviewCallout[]>;
};

export const getAugmentsPreviewCallouts = (
  decoration: AugmentationDecorationMode,
) => calloutSchema.profiles[calloutSchema.modes[decoration]] ?? [];

export const AugmentsRegionSelector = (props: {
  callout: AugmentsPreviewCallout;
  item: AugmentsWorkbenchItem;
  onSelect: (region: string) => void;
  selected: boolean;
}) => {
  const { callout, item, onSelect, selected } = props;
  const style = {
    '--augments-callout-edge': `${callout.edge}%`,
  } as CSSProperties;

  return (
    <button
      aria-controls="augments-region-editor"
      aria-pressed={selected}
      className={`LimbsPage__regionSelector LimbsPage__regionSelector--${callout.side}`}
      data-available={item.available === false ? 'false' : 'true'}
      onClick={() => onSelect(item.region)}
      style={style}
      type="button"
    >
      <span className="LimbsPage__regionLabel">{item.label}</span>
      <span className="LimbsPage__regionSummary">{item.summary}</span>
    </button>
  );
};

export const AugmentsWorkbench = (props: {
  decoration: AugmentationDecorationMode;
  detail: ReactNode;
  detailTitle: ReactNode;
  items: AugmentsWorkbenchItem[];
  modeLabel: string;
  onSelect: (region: string) => void;
  previewId: string;
  rotationControls: ReactNode;
  selectedRegion: string;
  toolbar?: ReactNode;
}) => {
  const {
    decoration,
    detail,
    detailTitle,
    items,
    modeLabel,
    onSelect,
    previewId,
    rotationControls,
    selectedRegion,
    toolbar,
  } = props;
  const itemsByRegion = new Map(items.map((item) => [item.region, item]));
  const callouts = getAugmentsPreviewCallouts(decoration).filter((callout) =>
    itemsByRegion.has(callout.region),
  );
  const calloutsBySide = (side: AugmentsPreviewCalloutSide) =>
    callouts.filter((callout) => callout.side === side);

  const renderRail = (side: AugmentsPreviewCalloutSide) => (
    <div
      aria-label={`${side} body-region selectors`}
      className={`LimbsPage__calloutRail LimbsPage__calloutRail--${side}`}
      role="group"
    >
      {calloutsBySide(side).map((callout) => {
        const item = itemsByRegion.get(callout.region)!;
        return (
          <AugmentsRegionSelector
            callout={callout}
            item={item}
            key={callout.region}
            onSelect={onSelect}
            selected={selectedRegion === callout.region}
          />
        );
      })}
    </div>
  );

  return (
    <div className="LimbsPage__workspace">
      <Section
        className="LimbsPage__schematicSection"
        fill
        title="Anatomical link"
      >
        <div className="LimbsPage__schematic">
          <div className="LimbsPage__schematicStatus">
            <span>Map mode</span>
            <strong>{modeLabel}</strong>
            <span className="LimbsPage__schematicStatusState">
              Live preview
            </span>
          </div>
          <div className="LimbsPage__bodyMap">
            {renderRail('top')}
            {renderRail('left')}
            <div className="LimbsPage__previewViewport">
              <CharacterPreview
                decoration={decoration}
                height="100%"
                id={previewId}
                width="100%"
              />
            </div>
            {renderRail('right')}
            {renderRail('bottom')}
          </div>
          <div className="LimbsPage__schematicFooter">
            <span className="LimbsPage__schematicHint">
              <span aria-hidden="true" className="LimbsPage__socketKey" />
              Select a region to edit its linked settings
            </span>
            {rotationControls}
          </div>
        </div>
      </Section>

      <Section
        className="LimbsPage__editorSection"
        fill
        scrollable
        title={detailTitle}
      >
        <div id="augments-region-editor">
          {toolbar}
          {detail}
        </div>
      </Section>
    </div>
  );
};

// THIS IS AN APHELION UI FILE
import { type CSSProperties, useState } from 'react';
import {
  Button,
  Dropdown,
  LabeledList,
  NoticeBox,
  Section,
  Table,
} from 'tgui-core/components';
import { DiagnosticLoader } from '../interfaces/common/DiagnosticLoader';

const STUDY_SIZES = [48, 64, 96, 144] as const;

const CHECKPOINTS = [
  { label: 'Indeterminate', value: 'indeterminate' },
  { label: '0%', value: '0' },
  { label: '1%', value: '1' },
  { label: '50%', value: '50' },
  { label: '99%', value: '99' },
  { label: '100%', value: '100' },
] as const;

type StudySampleStyle = CSSProperties & {
  '--loader-study-scale': number;
  '--loader-study-size': string;
};

export function DiagnosticLoaderComparison() {
  const [scale, setScale] = useState(1);
  const [checkpoint, setCheckpoint] = useState('indeterminate');
  const [reducedMotion, setReducedMotion] = useState(false);
  const value = checkpoint === 'indeterminate' ? undefined : Number(checkpoint);

  return (
    <Section fill scrollable title="Diagnostic loader A/B study">
      <NoticeBox>
        Source A is intentionally unavailable: the licensed #21604950 archive
        was not supplied, and a public preview is not an exact or auditable
        vector source. It fails the provenance hard gate and is not traced.
      </NoticeBox>

      <div className="MeridianLoaderStudy__controls">
        <LabeledList>
          <LabeledList.Item label="Preview scale">
            <Dropdown
              options={[
                { displayText: '100%', value: '1' },
                { displayText: '125%', value: '1.25' },
                { displayText: '150%', value: '1.5' },
              ]}
              selected={String(scale)}
              onSelected={(nextScale) => setScale(Number(nextScale))}
            />
          </LabeledList.Item>
          <LabeledList.Item label="State">
            <Dropdown
              options={CHECKPOINTS.map(({ label, value }) => ({
                displayText: label,
                value,
              }))}
              selected={checkpoint}
              onSelected={setCheckpoint}
            />
          </LabeledList.Item>
        </LabeledList>
        <Button.Checkbox
          checked={reducedMotion}
          onClick={() => setReducedMotion(!reducedMotion)}
        >
          Static reduced-motion study
        </Button.Checkbox>
      </div>

      <div className="MeridianLoaderStudy__matrix">
        <Section title="A — exact #21604950 source-derived">
          <div className="MeridianLoaderStudy__samples">
            {STUDY_SIZES.map((size) => (
              <div className="MeridianLoaderStudy__sample" key={size}>
                <div className="MeridianLoaderStudy__sourceGate">
                  <strong>{size}px study gated</strong>
                  <span>Exact path topology unavailable</span>
                </div>
                <span className="MeridianLoaderStudy__sampleLabel">
                  {size}px · {Math.round(scale * 100)}%
                </span>
              </div>
            ))}
          </div>
        </Section>

        <Section title="B — Meridian-authored instrument">
          <div className="MeridianLoaderStudy__samples">
            {STUDY_SIZES.map((size) => {
              const style: StudySampleStyle = {
                '--loader-study-scale': scale,
                '--loader-study-size': `${size}px`,
              };
              return (
                <div
                  className="MeridianLoaderStudy__sample"
                  key={size}
                  style={style}
                >
                  <DiagnosticLoader
                    ariaLabel={`Meridian loader ${size}px study`}
                    className={
                      reducedMotion
                        ? 'DiagnosticLoader--motion-reduced'
                        : undefined
                    }
                    label={null}
                    maxValue={100}
                    value={value}
                  />
                  <span className="MeridianLoaderStudy__sampleLabel">
                    {size}px · {Math.round(scale * 100)}%
                  </span>
                </div>
              );
            })}
          </div>
        </Section>
      </div>

      <Section title="Selection score">
        <Table>
          <Table.Row header>
            <Table.Cell>Candidate</Table.Cell>
            <Table.Cell>Cohesion</Table.Cell>
            <Table.Cell>48px</Table.Cell>
            <Table.Cell>Integration</Table.Cell>
            <Table.Cell>Cost</Table.Cell>
            <Table.Cell>Access</Table.Cell>
            <Table.Cell>Maintenance</Table.Cell>
            <Table.Cell>Provenance</Table.Cell>
            <Table.Cell>Total</Table.Cell>
          </Table.Row>
          <Table.Row>
            <Table.Cell>A — source-derived</Table.Cell>
            <Table.Cell colSpan={7}>Disqualified: source hard gate</Table.Cell>
            <Table.Cell>0 / 100</Table.Cell>
          </Table.Row>
          <Table.Row>
            <Table.Cell>B — Meridian</Table.Cell>
            <Table.Cell>24 / 25</Table.Cell>
            <Table.Cell>19 / 20</Table.Cell>
            <Table.Cell>15 / 15</Table.Cell>
            <Table.Cell>14 / 15</Table.Cell>
            <Table.Cell>10 / 10</Table.Cell>
            <Table.Cell>8 / 10</Table.Cell>
            <Table.Cell>5 / 5</Table.Cell>
            <Table.Cell>95 / 100 provisional</Table.Cell>
          </Table.Row>
        </Table>
      </Section>
    </Section>
  );
}

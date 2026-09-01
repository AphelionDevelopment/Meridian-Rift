import { afterEach, describe, expect, it, mock } from 'bun:test';
import { cleanup, fireEvent, render } from '@testing-library/react';

import { PriorityButton } from './JobsPage';
import { LoadoutActionButton } from './loadout';
import { SpeciesPerk } from './SpeciesPage';

afterEach(cleanup);

describe('Preferences visual controls', () => {
  it('gives the selected job priority a check and non-color state', () => {
    const onClick = mock(() => undefined);
    const view = render(
      <PriorityButton
        color="green"
        enabled
        name="High"
        onClick={onClick}
      />,
    );
    const button = view.getByRole('button', { name: 'High' });

    expect(button.getAttribute('aria-pressed')).toBe('true');
    expect(button.classList).toContain(
      'PreferencesMenu__Jobs__departments__priority--enabled',
    );
    expect(
      button.querySelector(
        '.PreferencesMenu__Jobs__departments__priorityMark',
      ),
    ).not.toBeNull();

    fireEvent.click(button);
    expect(onClick).toHaveBeenCalledTimes(1);
  });

  it('keeps an unselected job priority visually empty and unpressed', () => {
    const view = render(
      <PriorityButton
        color="yellow"
        enabled={false}
        name="Medium"
        onClick={() => undefined}
      />,
    );
    const button = view.getByRole('button', { name: 'Medium' });

    expect(button.getAttribute('aria-pressed')).toBe('false');
    expect(
      button.querySelector(
        '.PreferencesMenu__Jobs__departments__priorityMark',
      ),
    ).toBeNull();
  });

  it('centers a species perk in a bounded icon cell', () => {
    const view = render(
      <SpeciesPerk
        className="color-bg-green"
        perk={{
          description: 'Test description',
          name: 'Test perk',
          ui_icon: 'robot',
        }}
      />,
    );
    const cell = view.container.querySelector(
      '.PreferencesMenu__SpeciesPerk',
    );

    expect(cell).not.toBeNull();
    expect(cell?.querySelector('.Icon')).not.toBeNull();
  });

  it('routes Loadout icon actions through the shared centered-button contract', () => {
    const configure = mock(() => undefined);
    const remove = mock(() => undefined);
    const view = render(
      <>
        <LoadoutActionButton
          icon="cogs"
          iconColor="grey"
          iconSize={1.8}
          label="Configure test item"
          onClick={configure}
        />
        <LoadoutActionButton
          icon="times"
          iconColor="red"
          iconSize={2}
          label="Remove test item"
          onClick={remove}
        />
      </>,
    );

    for (const label of ['Configure test item', 'Remove test item']) {
      const button = view.getByRole('button', { name: label });
      const content = button.querySelector('.Button__content');
      const icon = content?.firstElementChild;

      expect(button.classList).toContain('Button--empty');
      expect(button.classList).toContain('Button--flex');
      expect(button.classList).toContain('Button--hasIcon');
      expect(button.style.height).not.toBe('');
      expect(button.style.height).toBe(button.style.width);
      expect(content?.childElementCount).toBe(1);
      expect(icon?.classList).toContain('Button--icon');
    }

    fireEvent.click(view.getByRole('button', { name: 'Configure test item' }));
    fireEvent.click(view.getByRole('button', { name: 'Remove test item' }));
    expect(configure).toHaveBeenCalledTimes(1);
    expect(remove).toHaveBeenCalledTimes(1);
  });
});

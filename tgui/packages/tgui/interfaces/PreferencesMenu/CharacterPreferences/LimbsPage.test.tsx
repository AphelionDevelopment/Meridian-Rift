import { afterEach, describe, expect, it } from 'bun:test';
import { cleanup, fireEvent, render } from '@testing-library/react';
import { Dropdown } from 'tgui-core/components';
import { HoverText } from './LimbsPage';

afterEach(cleanup);

describe('Augments descriptive tooltip', () => {
  it('associates the real focusable control and dismisses with Escape', () => {
    const view = render(
      <HoverText text="Calibrated limb response profile">
        <Dropdown
          options={['Nominal']}
          selected="Nominal"
          onSelected={() => {}}
          searchInput
          styledInput
        />
      </HoverText>,
    );

    const control = view.getByRole('textbox');
    const descriptionId = control.getAttribute('aria-describedby');
    expect(descriptionId).toBeTruthy();
    expect(document.getElementById(descriptionId!)?.textContent).toBe(
      'Calibrated limb response profile',
    );

    fireEvent.focus(control);
    const wrapper = document.getElementById(descriptionId!)!.parentElement!;
    expect(wrapper.classList.contains('visible')).toBe(true);

    fireEvent.keyDown(control, { key: 'Escape' });
    expect(wrapper.classList.contains('visible')).toBe(false);
  });
});

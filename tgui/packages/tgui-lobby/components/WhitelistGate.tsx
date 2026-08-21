// THIS IS AN APHELION UI FILE
import { sendAction } from '../actions';

/** Replaces the nav menu when the Discord whitelist gate blocks this player from playing. */
export function WhitelistGate() {
  return (
    <div className="container_nav container_nav--centered">
      <p className="menu_notice menu_notice--centered">
        You must be whitelisted to play.
        <br />
        Link your Discord to continue.
      </p>
      <div
        className="menu_button menu_button--centered"
        onClick={() => sendAction('get_whitelisted')}
      >
        GET WHITELISTED
      </div>
    </div>
  );
}

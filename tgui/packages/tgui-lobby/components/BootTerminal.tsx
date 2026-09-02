// THIS IS AN APHELION UI FILE
import { type CSSProperties, useEffect, useRef, useState } from 'react';
import { DiagnosticLoader } from 'tgui/interfaces/common/DiagnosticLoader';

export type StartupMessage = {
  text: string;
  warning: boolean;
};

type ProgressState = {
  previousTick: number;
  lastVisualWrite: number;
  currentTime: number;
  completionTime: number;
  currentPosition: number;
  renderedPosition: number;
};

type ProgressRailStyle = CSSProperties & {
  '--boot-progress': number;
};

export const BOOT_PROGRESS_WRITE_INTERVAL_MS = 100;
const PROGRESS_TICKS_PER_MILLISECOND = 1 / 100;

const clamp = (value: number, minimum: number, maximum: number) =>
  Math.min(Math.max(value, minimum), maximum);

const finiteOr = (value: number, fallback: number) =>
  Number.isFinite(value) ? value : fallback;

export function isBootProgressWriteDue(tick: number, lastVisualWrite: number) {
  return (
    Number.isFinite(tick) &&
    Number.isFinite(lastVisualWrite) &&
    tick - lastVisualWrite >= BOOT_PROGRESS_WRITE_INTERVAL_MS
  );
}

/**
 * Convert Dream Maker's decisecond startup timing into a monotonic percentage.
 * Keeping this pure makes the extrapolation and malformed-data behavior
 * independently testable without adding another animation loop.
 */
export function getStartupProgressPercent(
  currentTime: number,
  completionTime: number,
  previousPercent = 0,
) {
  const safePrevious = clamp(finiteOr(previousPercent, 0), 0, 100);
  if (
    !Number.isFinite(currentTime) ||
    !Number.isFinite(completionTime) ||
    completionTime <= 0
  ) {
    return safePrevious;
  }

  return clamp(
    Math.max(safePrevious, (currentTime / completionTime) * 100),
    0,
    100,
  );
}

export function extrapolateStartupTime(
  currentTime: number,
  completionTime: number,
  elapsedMilliseconds: number,
) {
  const safeCompletion = Math.max(finiteOr(completionTime, 1), 1);
  const safeCurrent = clamp(finiteOr(currentTime, 0), 0, safeCompletion);
  const elapsed = Math.max(finiteOr(elapsedMilliseconds, 0), 0);

  return Math.min(
    safeCurrent + elapsed * PROGRESS_TICKS_PER_MILLISECOND,
    safeCompletion,
  );
}

/**
 * Startup terminal + progress instrument shown while the map is still loading
 * (SSticker.current_state == GAME_STATE_STARTUP).
 */
export function BootTerminal({
  messages,
  progressCurrent,
  progressTotal,
}: {
  messages: StartupMessage[];
  progressCurrent: number;
  progressTotal: number;
}) {
  const initialPosition = getStartupProgressPercent(
    progressCurrent,
    progressTotal,
  );
  const [visualPercent, setVisualPercent] = useState(initialPosition);
  const terminalRef = useRef<HTMLDivElement>(null);
  const rootRef = useRef<HTMLDivElement>(null);
  const initialTick = performance.now();

  const state = useRef<ProgressState>({
    previousTick: initialTick,
    lastVisualWrite: initialTick,
    currentTime: finiteOr(progressCurrent, 0),
    completionTime: Math.max(finiteOr(progressTotal, 1), 1),
    currentPosition: initialPosition,
    renderedPosition: initialPosition,
  });

  useEffect(() => {
    state.current.currentTime = finiteOr(progressCurrent, 0);
    state.current.completionTime = Math.max(finiteOr(progressTotal, 1), 1);
  }, [progressCurrent, progressTotal]);

  useEffect(() => {
    let frameId: number;

    const resetVisibilityClock = () => {
      state.current.previousTick = performance.now();
      rootRef.current?.toggleAttribute('data-document-hidden', document.hidden);
    };

    const renderFrame = (tick: number) => {
      const progress = state.current;
      const elapsedMs = Math.max(tick - progress.previousTick, 0);
      progress.previousTick = tick;

      if (!document.hidden) {
        progress.currentTime = extrapolateStartupTime(
          progress.currentTime,
          progress.completionTime,
          elapsedMs,
        );
        progress.currentPosition = getStartupProgressPercent(
          progress.currentTime,
          progress.completionTime,
          progress.currentPosition,
        );

        const writeIsDue = isBootProgressWriteDue(
          tick,
          progress.lastVisualWrite,
        );
        const completionNeedsWrite =
          progress.currentPosition === 100 && progress.renderedPosition !== 100;

        if (
          (writeIsDue || completionNeedsWrite) &&
          progress.currentPosition !== progress.renderedPosition
        ) {
          progress.lastVisualWrite = tick;
          progress.renderedPosition = progress.currentPosition;
          setVisualPercent(progress.currentPosition);
        }
      }

      frameId = requestAnimationFrame(renderFrame);
    };

    document.addEventListener('visibilitychange', resetVisibilityClock);
    resetVisibilityClock();
    frameId = requestAnimationFrame(renderFrame);

    return () => {
      cancelAnimationFrame(frameId);
      document.removeEventListener('visibilitychange', resetVisibilityClock);
    };
  }, []);

  // Keep the transcript scrolled to the newest startup line.
  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight;
    }
  }, [messages]);

  const latestMessage = messages.at(-1)?.text || 'Awaiting startup telemetry';
  const terminalMessages = messages.length
    ? messages
    : [{ text: latestMessage, warning: false }];
  const recordCount = String(messages.length).padStart(2, '0');
  const displayPercent = Math.floor(visualPercent);
  const progressRailStyle: ProgressRailStyle = {
    '--boot-progress': visualPercent / 100,
  };

  return (
    <div className="boot_terminal" ref={rootRef}>
      <div className="container_terminal">
        <div aria-hidden="true" className="container_terminal__header">
          <span>MeridianOS // BOOT TRANSCRIPT</span>
          <span className="container_terminal__channel">
            <span className="container_terminal__lamp" />
            {recordCount} REC / LIVE
          </span>
        </div>

        <div
          aria-label="System startup log"
          aria-live="polite"
          aria-relevant="additions"
          className="container_terminal__log"
          ref={terminalRef}
          role="log"
        >
          {terminalMessages.map((message, index) => (
            <p
              key={`${index}-${message.text}`}
              className={`terminal_text ${
                message.warning ? 'terminal_text--warning' : ''
              }`}
            >
              <span aria-hidden="true" className="terminal_text__channel">
                {message.warning ? 'WRN!' : 'SYS>'}
              </span>
              <span className="terminal_text__message">
                {message.warning ? 'CAUTION / ' : ''}
                {message.text}
              </span>
            </p>
          ))}
        </div>

        <div aria-hidden="true" className="terminal_prompt">
          <span className="terminal_prompt__label">
            MeridianOS/BOOT:STREAM&gt;
          </span>
          <span className="boot_terminal__cursor" />
        </div>
      </div>

      <div className="boot_terminal__instrument">
        <DiagnosticLoader
          ariaLabel="System startup progress"
          detail={
            <span className="boot_terminal__status">
              <span aria-hidden="true" className="boot_terminal__statusChannel">
                PROC/BOOT
              </span>
              <span className="boot_terminal__statusValue">
                {displayPercent}% <span aria-hidden>·</span> {latestMessage}
              </span>
            </span>
          }
          label="SYSTEM STARTUP"
          maxValue={100}
          minValue={0}
          size="large"
          value={visualPercent}
        />
      </div>

      <div aria-hidden className="container_progress">
        <div className="progress_bar" style={progressRailStyle} />
      </div>
    </div>
  );
}

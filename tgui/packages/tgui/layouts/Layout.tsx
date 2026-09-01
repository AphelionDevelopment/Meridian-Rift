/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { useAtomValue } from 'jotai';
import { useEffect, useRef } from 'react';
import type { Box } from 'tgui-core/components';
import { addScrollableNode, removeScrollableNode } from 'tgui-core/events';
import { classes } from 'tgui-core/react';
import { computeBoxClassName, computeBoxProps } from 'tgui-core/ui';
import { resolveMeridianTheme } from '../constants/theme';
import { debugThemeAtom } from '../events/store';

type BoxProps = React.ComponentProps<typeof Box>;

type Props = Partial<{
  theme: string;
}> &
  BoxProps;

export function Layout(props: Props) {
  const { className, theme = 'nanotrasen', children, ...rest } = props;
  const debugTheme = useAtomValue(debugThemeAtom);
  const resolvedTheme = resolveMeridianTheme(
    theme,
    process.env.NODE_ENV !== 'production' ? debugTheme : null,
  );
  const managedClasses = resolvedTheme.classes;
  const managedClassKey = managedClasses.join(' ');
  const previousManagedClasses = useRef<string[]>([]);

  useEffect(() => {
    const root = document.documentElement;
    const nextManagedClasses = managedClassKey.split(' ');
    root.classList.remove(...previousManagedClasses.current);
    root.classList.add(...nextManagedClasses);
    previousManagedClasses.current = nextManagedClasses;

    return () => {
      root.classList.remove(...nextManagedClasses);
      previousManagedClasses.current = [];
    };
  }, [managedClassKey]);

  return (
    <div className={managedClassKey} data-theme={resolvedTheme.base}>
      <div
        className={classes(['Layout', className, computeBoxClassName(rest)])}
        {...computeBoxProps(rest)}
      >
        {children}
      </div>
    </div>
  );
}

type ContentProps = Partial<{
  scrollable: boolean;
}> &
  BoxProps;

function LayoutContent(props: ContentProps) {
  const { className, scrollable, children, ...rest } = props;
  const node = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const self = node.current;

    if (self && scrollable) {
      addScrollableNode(self);
    }
    return () => {
      if (self && scrollable) {
        removeScrollableNode(self);
      }
    };
  }, []);

  return (
    <div
      className={classes([
        'Layout__content',
        scrollable && 'Layout__content--scrollable',
        className,
        computeBoxClassName(rest),
      ])}
      ref={node}
      {...computeBoxProps(rest)}
    >
      {children}
    </div>
  );
}

Layout.Content = LayoutContent;

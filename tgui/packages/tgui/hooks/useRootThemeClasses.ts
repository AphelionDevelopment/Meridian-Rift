// THIS IS AN APHELION UI FILE
import { useEffect, useRef } from 'react';

/**
 * Reconcile only the theme classes owned by the active renderer.
 *
 * Runtime classes added by BYOND, accessibility tooling, or another surface
 * remain untouched. Keeping the previous owned set also makes rapid theme
 * changes deterministic without assigning to `documentElement.className`.
 */
export function useRootThemeClasses(managedClasses: readonly string[]) {
  const managedClassKey = managedClasses.join(' ');
  const previousManagedClasses = useRef<string[]>([]);

  useEffect(() => {
    const root = document.documentElement;
    const nextManagedClasses = managedClassKey.split(' ').filter(Boolean);
    root.classList.remove(...previousManagedClasses.current);
    root.classList.add(...nextManagedClasses);
    previousManagedClasses.current = nextManagedClasses;

    return () => {
      root.classList.remove(...nextManagedClasses);
      previousManagedClasses.current = [];
    };
  }, [managedClassKey]);
}

// THIS IS AN APHELION UI FILE
import { useEffect } from 'react';

/**
 * Reconcile only the theme classes owned by the active renderer.
 *
 * Runtime classes added by BYOND, accessibility tooling, or another surface
 * remain untouched. Effect cleanup removes the previous owned set before the
 * next theme is applied, without assigning to `documentElement.className`.
 */
export function useRootThemeClasses(managedClasses: readonly string[]) {
  const managedClassKey = managedClasses.join(' ');

  useEffect(() => {
    const root = document.documentElement;
    const nextManagedClasses = managedClassKey.split(' ').filter(Boolean);
    root.classList.add(...nextManagedClasses);

    return () => {
      root.classList.remove(...nextManagedClasses);
    };
  }, [managedClassKey]);
}

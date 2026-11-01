import type { GlobOptions } from 'glob-modern';
import { glob as modernGlob } from 'glob-modern';

export * from 'glob-modern';

type LegacyOptions = Omit<GlobOptions, 'withFileTypes'> & {
  withFileTypes?: false;
  nonull?: boolean;
  nosort?: boolean;
  nounique?: boolean;
  sync?: boolean;
};
type Callback = (error: Error | null, matches?: string[]) => void;
declare const legacyGlob: Pick<typeof modernGlob, Exclude<keyof typeof modernGlob, 'sync'>> & {
  (pattern: string | string[], callback: Callback): undefined;
  (pattern: string | string[], options: LegacyOptions, callback: Callback): undefined;
  (pattern: string | string[], options: LegacyOptions & {sync: true}): string[];
  (pattern: string | string[], options?: LegacyOptions): Promise<string[]>;
  sync(pattern: string | string[], options?: LegacyOptions): string[];
};
export default legacyGlob;

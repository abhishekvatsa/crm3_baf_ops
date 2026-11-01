export * from 'minimatch-modern';
import { minimatch } from 'minimatch-modern';
declare const legacyMatch: typeof minimatch;
export default legacyMatch;

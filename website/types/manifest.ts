export interface Part {
  id: string;
  name: string;
  file: string;
  /** Display label for an alternative variant of this part (e.g., "WiFi Antennas"). */
  variant?: string;
  /** When true, the part is shown in the gallery but skipped by the bulk zip downloads. */
  excludeFromDownloadAll?: boolean;
}

export interface PartGroup {
  id: string;
  name: string;
  description: string;
  parts: Part[];
}

export interface Assemblies {
  body: string;
}

export interface Manifest {
  generated: string;
  commit: string;
  assemblies?: Assemblies;
  groups: PartGroup[];
}

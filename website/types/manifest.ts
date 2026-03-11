export interface Part {
  id: string;
  name: string;
  file: string;
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

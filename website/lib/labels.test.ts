import { describe, expect, it } from 'vitest';
import {
  LABEL_MAX_CHARS,
  LABEL_WIDTH_MARGIN_MM,
  engravedLabel,
  isBlank,
  labelIsTooWide,
  sanitiseLabel,
} from './labels';

// The measurement half needs a canvas and a loaded font, so it is exercised in the browser
// rather than here. What is testable in node is the part that carries the security and
// identity weight: what a label may contain, and what counts as no label at all.

describe('what the input accepts', () => {
  it('keeps the characters a rack label is actually made of', () => {
    expect(sanitiseLabel('NODE-01 rack_A.2 (#3)+')).toBe('NODE-01 rack_A.2 (#3)+');
  });

  it('drops the two characters that would break out of the -D argument', () => {
    // Verified against real OpenSCAD: a quote closes the string and the rest executes;
    // a trailing backslash raises "Unterminated string".
    expect(sanitiseLabel('AB"CD')).toBe('ABCD');
    expect(sanitiseLabel('AB\\CD')).toBe('ABCD');
  });

  it('drops anything the shared link could not encode', () => {
    // encodeState runs the result through btoa, which throws outside Latin1.
    expect(sanitiseLabel('ラック')).toBe('');
    expect(() => btoa(sanitiseLabel('café ☕'))).not.toThrow();
  });

  it('drops characters that would make the file name ambiguous', () => {
    expect(sanitiseLabel('a/b')).toBe('ab');
    expect(sanitiseLabel('50%')).toBe('50');
  });

  it('caps the length', () => {
    expect(sanitiseLabel('X'.repeat(100))).toHaveLength(LABEL_MAX_CHARS);
  });

  it('keeps a trailing space, so a name can still be typed one word at a time', () => {
    expect(sanitiseLabel('NODE ')).toBe('NODE ');
  });
});

describe('what actually gets engraved', () => {
  it('trims, because OpenSCAD does not treat spaces as nothing', () => {
    // An untrimmed "   " engraves three spaces: a mesh that differs from the blank filter
    // while looking identical to it.
    expect(engravedLabel('   ')).toBe('');
    expect(engravedLabel('  NODE 01  ')).toBe('NODE 01');
    expect(isBlank('   ', '\t')).toBe(true);
    expect(isBlank('', 'A')).toBe(false);
  });

  it('is idempotent, so re-sanitising at the worker cannot change the part identity', () => {
    for (const raw of ['NODE 01', ' X ', 'A"B', 'ラック', 'Z'.repeat(40)]) {
      expect(engravedLabel(engravedLabel(raw))).toBe(engravedLabel(raw));
    }
  });
});

describe('the width gate', () => {
  const LIMIT = 61.1745; // what cad/sections/body/dust.scad derives at the shipped config

  it('rejects a label past the limit, with margin to spare', () => {
    expect(labelIsTooWide(70.8, LIMIT)).toBe(true);
    expect(labelIsTooWide(LIMIT, LIMIT)).toBe(true);
    // Inside the CAD's bound but inside the margin too: rejected here, because the margin
    // is what absorbs the difference between this browser's metrics and OpenSCAD's.
    expect(labelIsTooWide(LIMIT - LABEL_WIDTH_MARGIN_MM + 0.01, LIMIT)).toBe(true);
  });

  it('accepts a label comfortably inside it', () => {
    expect(labelIsTooWide(30, LIMIT)).toBe(false);
    expect(labelIsTooWide(LIMIT - LABEL_WIDTH_MARGIN_MM - 0.01, LIMIT)).toBe(false);
  });

  it('claims nothing when the width could not be measured', () => {
    // A font that has not loaded must not produce a confident verdict. The CAD assert is
    // the authority and still fires in the worker.
    expect(labelIsTooWide(null, LIMIT)).toBe(false);
  });
});

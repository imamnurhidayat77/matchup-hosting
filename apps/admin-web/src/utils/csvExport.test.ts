import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { downloadCsv } from './csvExport';

describe('downloadCsv', () => {
  const originalCreateElement = document.createElement.bind(document);
  let clickSpy: ReturnType<typeof vi.fn>;
  let createObjectURLSpy: ReturnType<typeof vi.fn>;
  let revokeObjectURLSpy: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    clickSpy = vi.fn();
    createObjectURLSpy = vi.fn(() => 'blob:mock-url');
    revokeObjectURLSpy = vi.fn();
    URL.createObjectURL = createObjectURLSpy;
    URL.revokeObjectURL = revokeObjectURLSpy;

    document.createElement = ((tag: string) => {
      const el = originalCreateElement(tag);
      if (tag === 'a') el.click = clickSpy;
      return el;
    }) as typeof document.createElement;
  });

  afterEach(() => {
    document.createElement = originalCreateElement;
  });

  it('does nothing when given an empty row list', () => {
    downloadCsv([], 'empty.csv');
    expect(createObjectURLSpy).not.toHaveBeenCalled();
    expect(clickSpy).not.toHaveBeenCalled();
  });

  it('builds a CSV blob from row objects and triggers a download', () => {
    downloadCsv([{ name: 'Alice', age: 30 }], 'people.csv');
    expect(createObjectURLSpy).toHaveBeenCalledTimes(1);
    const blob = createObjectURLSpy.mock.calls[0][0] as Blob;
    expect(blob.type).toBe('text/csv;charset=utf-8;');
    expect(clickSpy).toHaveBeenCalledTimes(1);
    expect(revokeObjectURLSpy).toHaveBeenCalledWith('blob:mock-url');
  });

  it('escapes values containing commas, quotes, or newlines', async () => {
    let capturedBlob: Blob | undefined;
    createObjectURLSpy.mockImplementation((blob: Blob) => {
      capturedBlob = blob;
      return 'blob:mock-url';
    });

    downloadCsv([{ note: 'has, comma', quote: 'she said "hi"', multi: 'line1\nline2' }], 'x.csv');

    const text = await capturedBlob?.text();
    expect(text).toContain('"has, comma"');
    expect(text).toContain('"she said ""hi"""');
    expect(text).toContain('"line1\nline2"');
  });

  it('renders null/undefined cell values as empty strings', async () => {
    let capturedBlob: Blob | undefined;
    createObjectURLSpy.mockImplementation((blob: Blob) => {
      capturedBlob = blob;
      return 'blob:mock-url';
    });

    downloadCsv([{ a: null, b: undefined, c: 'ok' }], 'x.csv');

    const text = await capturedBlob?.text();
    expect(text).toBe('a,b,c\n,,ok');
  });
});

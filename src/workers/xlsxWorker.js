import * as XLSX from "xlsx";

const SAFE_READ_DEFAULTS = {
  type: "array",
  cellDates: false,
  cellNF: false,
  cellStyles: false,
  cellFormula: false,
  WTF: false,
};

self.onmessage = (ev) => {
  const msg = ev.data || {};
  const id = msg.id;
  try {
    const buffer = msg.buffer;
    if (!buffer) throw new Error("Missing XLSX buffer.");

    const wb = XLSX.read(buffer, { ...SAFE_READ_DEFAULTS, ...(msg.readOptions || {}) });
    const names = wb.SheetNames || [];
    const name = msg.sheetName || names[msg.sheetIndex ?? 0] || names[0];
    if (!name) throw new Error("No sheets found in workbook.");
    const ws = wb.Sheets[name];
    if (!ws) throw new Error(`Worksheet not found: ${name}`);

    let rows = XLSX.utils.sheet_to_json(ws, msg.sheetToJsonOptions || {});
    if (msg.maxRows && rows.length > msg.maxRows) rows = rows.slice(0, msg.maxRows);

    self.postMessage({ id, result: { sheetName: name, rows } });
  } catch (e) {
    self.postMessage({ id, error: e?.message || String(e) });
  }
};

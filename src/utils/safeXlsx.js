const DEFAULT_MAX_BYTES = 50 * 1024 * 1024; // 50MB
const DEFAULT_TIMEOUT_MS = 15000;
const XLSX_DISABLED = String(import.meta?.env?.VITE_DISABLE_XLSX || "").toLowerCase() === "true";

function isArrayBufferLike(v) {
  return v && (v instanceof ArrayBuffer || v?.buffer instanceof ArrayBuffer);
}

/**
 * @param {File|ArrayBuffer|Uint8Array} input
 * @param {{
 *   maxBytes?: number;
 * }} opts
 * @returns {Promise<ArrayBuffer>}
 */
async function getArrayBuffer(input, opts = {}) {
  const maxBytes = opts.maxBytes ?? DEFAULT_MAX_BYTES;

  if (typeof File !== "undefined" && input instanceof File) {
    if (input.size > maxBytes) {
      throw new Error(`File too large: ${input.size} bytes (max ${maxBytes} bytes).`);
    }
    return await input.arrayBuffer();
  }

  if (isArrayBufferLike(input)) {
    const buf = input instanceof ArrayBuffer ? input : input.buffer;
    if (buf.byteLength > maxBytes) {
      throw new Error(`Buffer too large: ${buf.byteLength} bytes (max ${maxBytes} bytes).`);
    }
    return buf;
  }

  throw new Error("Unsupported XLSX input. Expected File or ArrayBuffer.");
}

/**
 * Safely parse XLSX in a Web Worker to mitigate ReDoS (limits + timeout).
 * @param {File|ArrayBuffer|Uint8Array} input
 * @param {{
 *   readOptions?: Record<string, any>;
 *   sheetToJsonOptions?: Record<string, any>;
 *   sheetIndex?: number;
 *   sheetName?: string;
 *   maxRows?: number;
 *   maxBytes?: number;
 *   timeoutMs?: number;
 * }} opts
 * @returns {Promise<{ sheetName: string; rows: any[] }>}
 */
export async function readXlsxSheetToJson(input, opts = {}) {
  if (XLSX_DISABLED) {
    throw new Error("Excel uploads (.xlsx/.xls) are disabled. Use CSV instead.");
  }
  const buffer = await getArrayBuffer(input, opts);
  const timeoutMs = opts.timeoutMs ?? DEFAULT_TIMEOUT_MS;

  if (typeof Worker === "undefined") {
    // Fallback: parse on main thread if Workers are unavailable.
    const XLSX = await import("xlsx");
    const wb = XLSX.read(buffer, { type: "array", ...(opts.readOptions || {}) });
    const names = wb.SheetNames || [];
    const name = opts.sheetName || names[opts.sheetIndex ?? 0] || names[0];
    if (!name) throw new Error("No sheets found in workbook.");
    const ws = wb.Sheets[name];
    if (!ws) throw new Error(`Worksheet not found: ${name}`);
    let rows = XLSX.utils.sheet_to_json(ws, opts.sheetToJsonOptions || {});
    if (opts.maxRows && rows.length > opts.maxRows) rows = rows.slice(0, opts.maxRows);
    return { sheetName: name, rows };
  }

  const worker = new Worker(new URL("../workers/xlsxWorker.js", import.meta.url), { type: "module" });

  return await new Promise((resolve, reject) => {
    const id = Math.random().toString(36).slice(2);
    const timer = setTimeout(() => {
      worker.terminate();
      reject(new Error(`XLSX parse timeout after ${timeoutMs}ms.`));
    }, timeoutMs);

    worker.onmessage = (ev) => {
      const msg = ev.data || {};
      if (msg.id !== id) return;
      clearTimeout(timer);
      worker.terminate();
      if (msg.error) {
        reject(new Error(msg.error));
      } else {
        resolve(msg.result);
      }
    };

    worker.onerror = (err) => {
      clearTimeout(timer);
      worker.terminate();
      reject(err);
    };

    worker.postMessage(
      {
        id,
        buffer,
        readOptions: opts.readOptions || {},
        sheetToJsonOptions: opts.sheetToJsonOptions || {},
        sheetIndex: opts.sheetIndex ?? 0,
        sheetName: opts.sheetName || "",
        maxRows: opts.maxRows || 0,
      },
      [buffer]
    );
  });
}

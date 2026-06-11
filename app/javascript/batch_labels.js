import qrcode from "qrcode-generator";

// Use UTF-8 byte conversion when available (CJS build exposes it; ESM build does not,
// but our URLs are ASCII-only so the default encoding is fine either way).
if (qrcode.stringToBytesFuncs) {
  qrcode.stringToBytes = qrcode.stringToBytesFuncs["UTF-8"];
}

/**
 * Draw a QR code for `url` onto `canvas`.
 * Quiet zone is 4 modules on every side.
 */
function drawQR(url, canvas) {
  const qr = qrcode(0, "M"); // type 0 = auto, M = ~15% error correction
  qr.addData(url);
  qr.make();

  const moduleCount = qr.getModuleCount();
  const margin      = 4;   // quiet-zone modules
  const cellSize    = 6;   // px per module
  const totalPx     = (moduleCount + margin * 2) * cellSize;

  canvas.width  = totalPx;
  canvas.height = totalPx;

  const ctx = canvas.getContext("2d");
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, totalPx, totalPx);
  ctx.fillStyle = "#000000";

  for (let r = 0; r < moduleCount; r++) {
    for (let c = 0; c < moduleCount; c++) {
      if (qr.isDark(r, c)) {
        ctx.fillRect(
          (c + margin) * cellSize,
          (r + margin) * cellSize,
          cellSize,
          cellSize
        );
      }
    }
  }
}

function escAttr(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/</g, "&lt;");
}

document.addEventListener("DOMContentLoaded", function () {
  const addBtn       = document.getElementById("add-entry");
  const entriesList  = document.getElementById("entries-list");
  const generateBtn  = document.getElementById("generate-btn");
  const sheet        = document.getElementById("qr-sheet");
  const captionCheck = document.getElementById("show-captions");
  const printBtn     = document.getElementById("print-btn");

  // Only the generator page has these elements
  if (!addBtn) return;

  function addEntry(batch, date) {
    const today = new Date().toISOString().slice(0, 10);
    const row = document.createElement("div");
    row.className = "d-flex gap-2 align-items-center mb-2 entry-row";
    row.innerHTML =
      `<input type="text"  class="form-control entry-batch" placeholder="Batch #" value="${escAttr(batch || "")}" required>` +
      `<input type="date"  class="form-control entry-date"  value="${escAttr(date  || today)}">` +
      `<button type="button" class="btn btn-outline-danger btn-sm remove-entry" aria-label="Remove">&times;</button>`;
    row.querySelector(".remove-entry").addEventListener("click", () => row.remove());
    entriesList.appendChild(row);
    row.querySelector(".entry-batch").focus();
  }

  // Start with one blank row
  addEntry();

  addBtn.addEventListener("click", () => addEntry());

  generateBtn.addEventListener("click", async function () {
    const rows  = entriesList.querySelectorAll(".entry-row");
    const items = [];
    rows.forEach(function (row) {
      const batch = row.querySelector(".entry-batch").value.trim();
      const date  = row.querySelector(".entry-date").value.trim();
      if (batch) items.push({ batch, date });
    });

    if (!items.length) {
      alert("Add at least one batch entry.");
      return;
    }

    generateBtn.disabled = true;
    generateBtn.textContent = "Generating…";

    const csrfMeta = document.querySelector('meta[name="csrf-token"]');
    let data;
    try {
      const resp = await fetch("/labels/encode", {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfMeta ? csrfMeta.content : "",
        },
        body: JSON.stringify({ items }),
      });
      if (!resp.ok) throw new Error("Server error " + resp.status);
      data = await resp.json();
    } catch (err) {
      alert("Failed to generate codes: " + err.message);
      return;
    } finally {
      generateBtn.disabled = false;
      generateBtn.textContent = "Generate codes";
    }

    const showCaptions = captionCheck && captionCheck.checked;

    sheet.innerHTML = "";
    data.labels.forEach(function (label, i) {
      const item    = items[i] || {};
      const wrapper = document.createElement("div");
      wrapper.className = "qr-label";

      const canvas = document.createElement("canvas");
      drawQR(label.url, canvas);
      wrapper.appendChild(canvas);

      // Always create caption; visibility toggled by checkbox
      const cap = document.createElement("div");
      cap.className    = "qr-caption";
      cap.textContent  = [item.batch, item.date].filter(Boolean).join(" — ");
      cap.style.display = showCaptions ? "" : "none";
      wrapper.appendChild(cap);

      sheet.appendChild(wrapper);
    });

    sheet.style.display = "";
    if (printBtn) printBtn.style.display = "";
  });

  // Toggle captions on already-rendered sheet
  if (captionCheck) {
    captionCheck.addEventListener("change", function () {
      sheet.querySelectorAll(".qr-caption").forEach(function (el) {
        el.style.display = captionCheck.checked ? "" : "none";
      });
    });
  }

  if (printBtn) {
    printBtn.addEventListener("click", () => window.print());
  }
});

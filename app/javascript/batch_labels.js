import qrcode from "qrcode-generator";

// Use UTF-8 byte conversion when available (CJS build exposes it; ESM build does not,
// but our URLs are ASCII-only so the default encoding is fine either way).
if (qrcode.stringToBytesFuncs) {
  qrcode.stringToBytes = qrcode.stringToBytesFuncs["UTF-8"];
}

/**
 * Draw a QR code for `url` onto `canvas`.
 * Renders at ~560px so it prints sharply at 1.75in / 300 DPI.
 * Quiet zone is 4 modules on every side.
 */
function drawQR(url, canvas) {
  const qr = qrcode(0, "M");
  qr.addData(url);
  qr.make();

  const moduleCount  = qr.getModuleCount();
  const margin       = 4;
  const totalModules = moduleCount + margin * 2;

  // Target ~560px so 1.75in CSS = ~320 DPI on a 300 DPI printer
  const cellSize = Math.max(4, Math.floor(560 / totalModules));
  const totalPx  = totalModules * cellSize;

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

  if (!addBtn) return;

  function addEntry(batch, date, product, notes) {
    const today = new Date().toISOString().slice(0, 10);
    const row = document.createElement("div");
    row.className = "entry-row card mb-2";
    row.innerHTML =
      `<div class="card-body p-2">` +
        `<div class="row g-2 align-items-center">` +
          `<div class="col-6 col-md-2">` +
            `<input type="text" class="form-control form-control-sm entry-batch" placeholder="Batch #" value="${escAttr(batch || "")}" required>` +
          `</div>` +
          `<div class="col-6 col-md-2">` +
            `<input type="date" class="form-control form-control-sm entry-date" value="${escAttr(date || today)}">` +
          `</div>` +
          `<div class="col-12 col-md-4">` +
            `<input type="text" class="form-control form-control-sm entry-product" placeholder="Product name">` +
          `</div>` +
          `<div class="col-10 col-md">` +
            `<input type="text" class="form-control form-control-sm entry-notes" placeholder="Notes (optional)">` +
          `</div>` +
          `<div class="col-2 col-md-auto">` +
            `<button type="button" class="btn btn-outline-danger btn-sm remove-entry w-100" aria-label="Remove">&times;</button>` +
          `</div>` +
        `</div>` +
      `</div>`;

    if (product) row.querySelector(".entry-product").value = product;
    if (notes)   row.querySelector(".entry-notes").value   = notes;

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
      const batch   = row.querySelector(".entry-batch").value.trim();
      const date    = row.querySelector(".entry-date").value.trim();
      const product = row.querySelector(".entry-product").value.trim();
      const notes   = row.querySelector(".entry-notes").value.trim();
      if (batch) items.push({ batch, date, product, notes });
    });

    if (!items.length) {
      alert("Add at least one batch entry.");
      return;
    }

    generateBtn.disabled    = true;
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
      generateBtn.disabled    = false;
      generateBtn.textContent = "Generate codes";
    }

    const showCaptions = captionCheck && captionCheck.checked;

    sheet.innerHTML = "";

    // Group labels into sheets of 4 (matches one 4×6 label)
    for (let i = 0; i < data.labels.length; i += 4) {
      const sheetEl = document.createElement("div");
      sheetEl.className = "label-sheet";

      for (let j = i; j < Math.min(i + 4, data.labels.length); j++) {
        const label  = data.labels[j];
        const item   = items[j] || {};

        const wrapper = document.createElement("div");
        wrapper.className = "qr-label";

        const canvas = document.createElement("canvas");
        drawQR(label.url, canvas);
        wrapper.appendChild(canvas);

        // Caption: product · batch · date  (always created, toggled by checkbox)
        const cap = document.createElement("div");
        cap.className    = "qr-caption";
        cap.textContent  = [item.product, item.batch, item.date].filter(Boolean).join(" · ");
        cap.style.display = showCaptions ? "" : "none";
        wrapper.appendChild(cap);

        sheetEl.appendChild(wrapper);
      }

      sheet.appendChild(sheetEl);
    }

    sheet.style.display = "";
    if (printBtn) printBtn.style.display = "";
  });

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

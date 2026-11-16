import qrcode from "qrcode-generator";

// Draws a crisp, scalable SVG QR code into every element with data-qr="<url>".
// Used by printed labels (PO pallet labels); size the element with CSS.
function drawAll() {
  document.querySelectorAll("[data-qr]").forEach((el) => {
    if (el.dataset.qrDrawn) return;
    const qr = qrcode(0, "M");
    qr.addData(el.dataset.qr);
    qr.make();
    el.innerHTML = qr.createSvgTag({ cellSize: 4, margin: 2, scalable: true });
    el.dataset.qrDrawn = "1";
  });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", drawAll);
} else {
  drawAll();
}

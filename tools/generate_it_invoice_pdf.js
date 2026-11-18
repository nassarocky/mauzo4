#!/usr/bin/env node
/**
 * Generate IT / CCTV invoice PDF (TZS).
 * Usage: node tools/generate_it_invoice_pdf.js [outputPath]
 */
const fs = require("fs");
const path = require("path");
const PDFDocument = require("pdfkit");

const OUT =
  process.argv[2] ||
  path.join(__dirname, "..", "dist", "IT_Invoice_CCTV_2026-11-04.pdf");

const lines = [
  {
    description: "8-Channel DVR",
    qty: 1,
    unit: "150,000",
    unitNum: 150000,
    details: "",
  },
  {
    description: "Analog HIK Camera 2MP",
    qty: 8,
    unit: "38,000",
    unitNum: 38000,
    details: "",
  },
  {
    description: "CAT6 Cable",
    qty: 65,
    unit: "2,000",
    unitNum: 2000,
    details: "per metre",
  },
  {
    description: "Power Supply with Fuse",
    qty: 1,
    unit: "90,000",
    unitNum: 90000,
    details: "",
  },
  {
    description: "Power Pins + BNC Connectors",
    qty: 36,
    unit: "1,000",
    unitNum: 1000,
    details: "pieces",
  },
  {
    description: "Power Cable",
    qty: 1,
    unit: "2,500",
    unitNum: 2500,
    details: "",
  },
  {
    description: "Hard Disk (HDD) 2TB",
    qty: 1,
    unit: "200,000",
    unitNum: 200000,
    details: "",
  },
  {
    description: "RJ45 Connectors",
    qty: 1,
    unit: "15,000",
    unitNum: 15000,
    details: "1 lot",
  },
  {
    description: "Installation + Transportation",
    qty: 1,
    unit: "300,000",
    unitNum: 300000,
    details: "Labour and transport",
  },
];

function fmt(n) {
  return n.toLocaleString("en-US");
}

const subtotal = lines.reduce((s, row) => s + row.qty * row.unitNum, 0);

fs.mkdirSync(path.dirname(OUT), { recursive: true });

const doc = new PDFDocument({ size: "A4", margin: 50 });
const stream = fs.createWriteStream(OUT);
doc.pipe(stream);

const primary = "#1a5276";
const muted = "#555555";

doc.fillColor(primary).fontSize(22).font("Helvetica-Bold").text("INVOICE", { align: "right" });
doc.moveDown(0.3);
doc.fillColor(muted).fontSize(10).font("Helvetica").text("IT / CCTV Supply & Installation", { align: "right" });

doc.moveDown(1.2);
doc.fillColor("#000").font("Helvetica-Bold").fontSize(11).text("From:");
doc.font("Helvetica").fontSize(10).text("Light Network", { continued: false });
doc.text("Email: lightnetwork2023@gmail.com");
doc.text("Phone: 0758422100");

doc.moveDown(0.8);
doc.font("Helvetica-Bold").fontSize(11).text("Bill To:");
doc.font("Helvetica").fontSize(10).text("Shamba la Kuku");

doc.moveDown(0.8);
const invNo = "INV-IT-2026-1104";
const invDate = "4 November 2026";
doc.font("Helvetica").fontSize(10);
doc.text(`Invoice No: ${invNo}`, { continued: true });
doc.text(`    Date: ${invDate}`, { align: "right" });
doc.text("Currency: Tanzanian Shillings (TSh)");

doc.moveDown(1);

const tableTop = doc.y;
const col = { desc: 50, qty: 320, unit: 380, amount: 480 };
const rowH = 22;

doc.rect(50, tableTop, 495, 20).fill(primary);
doc.fillColor("#fff").font("Helvetica-Bold").fontSize(9);
doc.text("Description", col.desc + 4, tableTop + 6, { width: 250 });
doc.text("Qty", col.qty, tableTop + 6, { width: 50, align: "right" });
doc.text("Unit (TSh)", col.unit, tableTop + 6, { width: 90, align: "right" });
doc.text("Amount (TSh)", col.amount, tableTop + 6, { width: 90, align: "right" });

let y = tableTop + 20;
doc.fillColor("#000").font("Helvetica").fontSize(9);

lines.forEach((row, i) => {
  if (i % 2 === 0) {
    doc.rect(50, y, 495, rowH).fill("#f4f6f7");
    doc.fillColor("#000");
  }
  const detail = row.details ? ` (${row.details})` : "";
  const amount = row.qty * row.unitNum;
  doc.text(row.description + detail, col.desc + 4, y + 6, { width: 255 });
  doc.text(String(row.qty), col.qty, y + 6, { width: 50, align: "right" });
  doc.text(row.unit, col.unit, y + 6, { width: 90, align: "right" });
  doc.font("Helvetica-Bold").text(fmt(amount), col.amount, y + 6, { width: 90, align: "right" });
  doc.font("Helvetica");
  y += rowH;
});

doc.rect(50, y, 495, 1).fill("#ccc");
y += 12;

doc.font("Helvetica-Bold").fontSize(11);
doc.text("GRAND TOTAL (TSh)", col.unit - 40, y, { width: 120, align: "right" });
doc.fillColor(primary).fontSize(12).text(fmt(subtotal), col.amount, y, { width: 90, align: "right" });
doc.fillColor("#000");

y += 36;
doc.font("Helvetica").fontSize(9).fillColor(muted);
doc.text(
  "Amounts verified: line totals = quantity × unit price. " +
    "Sum of all lines = TSh " +
    fmt(subtotal) +
    ".",
  50,
  y,
  { width: 495 }
);

doc.moveDown(2);
doc.fillColor("#000").font("Helvetica-Bold").fontSize(10).text("Payment terms");
doc.font("Helvetica").fontSize(9).text("Payment due within 14 days of invoice date unless agreed otherwise.");

doc.moveDown(1.5);
doc.fontSize(8).fillColor(muted).text("Thank you for your business.", { align: "center" });

doc.end();

stream.on("finish", () => {
  console.log("Wrote:", OUT);
  console.log("Grand total (TSh):", fmt(subtotal));
});

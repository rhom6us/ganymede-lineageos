module.exports = {
  pdf_options: {
    width: "5.5in",
    height: "8.5in",
    margin: {
      top: "0.5in",
      right: "0.5in",
      bottom: "0.5in",
      left: "0.5in"
    },
    displayHeaderFooter: true,
    headerTemplate: "<span></span>",
    footerTemplate:
      '<div style="width:100%;font-size:8pt;color:#666;text-align:center;font-family:sans-serif;">' +
      '<span class="pageNumber"></span> / <span class="totalPages"></span></div>',
    printBackground: true
  },
  css: `
    body { font-family: -apple-system, "Segoe UI", system-ui, sans-serif; font-size: 10.5pt; line-height: 1.45; color: #111; }
    h1 { font-size: 16pt; margin-top: 0.6em; border-bottom: 1pt solid #ccc; padding-bottom: 0.2em; }
    h2 { font-size: 13pt; margin-top: 1em; }
    h3 { font-size: 11.5pt; margin-top: 0.8em; }
    p, li { margin: 0.3em 0; }
    code { font-family: "Cascadia Mono", Consolas, "Courier New", monospace; font-size: 9.5pt; background: #f4f4f4; padding: 1px 3px; border-radius: 2px; }
    pre { background: #f4f4f4; padding: 8pt; border-radius: 3pt; overflow-x: auto; font-size: 9pt; line-height: 1.35; }
    pre code { background: none; padding: 0; }
    table { border-collapse: collapse; width: 100%; font-size: 9.5pt; margin: 0.5em 0; }
    th, td { border: 1pt solid #ccc; padding: 3pt 5pt; text-align: left; vertical-align: top; }
    th { background: #f0f0f0; }
    hr { border: none; border-top: 1pt solid #ccc; margin: 1em 0; }
    a { color: #0366d6; word-break: break-all; }
    blockquote { border-left: 3pt solid #ccc; padding-left: 8pt; color: #555; margin: 0.5em 0; }
    strong { color: #000; }
  `
};

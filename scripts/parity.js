#!/usr/bin/env node

/**
 * Headless Node runner for Elm ParityWorker.
 *
 * Usage:
 *   node scripts/parity.js <minOverlap> <fragment1> <fragment2> ...
 */

const path = require("path");
const fs = require("fs");

const workerPath = path.join(__dirname, "../elm-stuff/parity-worker.js");
if (!fs.existsSync(workerPath)) {
  console.error("Compiled parity worker not found at " + workerPath);
  process.exit(1);
}

// Suppress console info if needed
const { Elm } = require(workerPath);

const minOverlap = parseInt(process.argv[2] || "2", 10);
const fragments = process.argv.slice(3);

if (fragments.length === 0) {
  // Read from stdin if no fragments supplied in arguments
  let input = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => {
    input += chunk;
  });
  process.stdin.on("end", () => {
    const lines = input
      .split(/\r?\n/)
      .map((l) => l.trim())
      .filter((l) => l.length > 0);
    runWorker(minOverlap, lines);
  });
} else {
  runWorker(minOverlap, fragments);
}

function runWorker(overlap, frags) {
  const app = Elm.ParityWorker.init({
    flags: {
      minOverlap: overlap,
      fragments: frags,
    },
  });

  app.ports.outputResult.subscribe((contigs) => {
    contigs.forEach((c) => console.log(c));
    process.exit(0);
  });
}

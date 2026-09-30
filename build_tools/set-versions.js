#!/usr/bin/env node
// set-versions.js — write the release version into Chart.yaml.
//
// Run from .releaserc.json's prepare step:  node build_tools/set-versions.js <version>
//
// Helm chart versions are SemVer 2, so the semantic-release version is taken
// verbatim, pre-release suffix included (1.2.0-pre.4 is a valid chart version).
// Only the top-level "version:" line is rewritten. appVersion tracks the
// upstream web UI image and is left alone.

const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const CHART = "Chart.yaml";

const SEMVER = /^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$/;

// Rewrite the top-level version line in place, so the rest of the file
// (comments, key order, quoting) is untouched and the diff stays one line.
function setChartVersion(file, version) {
  const target = path.join(ROOT, file);
  const raw = fs.readFileSync(target, "utf8");
  const line = /^version:[ \t]*\S+[ \t]*$/m;

  if (!line.test(raw)) {
    throw new Error(`${file} has no top-level 'version:' line`);
  }
  fs.writeFileSync(target, raw.replace(line, `version: ${version}`));
  console.log(`${file}: version -> ${version}`);
}

const semver = process.argv[2];
if (!semver) {
  console.error("usage: set-versions.js <version>");
  process.exit(1);
}

try {
  if (!SEMVER.test(semver)) {
    throw new Error(`'${semver}' is not a SemVer 2 version`);
  }
  setChartVersion(CHART, semver);
} catch (err) {
  console.error(`set-versions: ${err.message}`);
  process.exit(1);
}

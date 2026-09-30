#!/usr/bin/env node
// set-versions.js — write the release version into package.json and manifest.json.
//
// Run from .releaserc.json's prepare step:  node build_tools/set-versions.js <version>
//
// package.json takes the semantic-release version verbatim (npm speaks semver).
//
// manifest.json cannot: a WebExtension "version" only accepts 1-4 dot-separated
// integers (0-65535), so the pre-release form X.Y.Z-pre.N has its trailing
// counter folded into a fourth component instead.
//
//   1.2.0          ->  1.2.0
//   1.2.0-pre.4    ->  1.2.0.4
//   1.2.0-pre.4+ci ->  1.2.0.4   (build metadata dropped)
//
// Note that 1.2.0.4 sorts *after* 1.2.0 for the browser, whereas semver puts
// the pre-release first. That is unavoidable within the manifest format and
// harmless here: alpha builds are self-distributed, never upgraded in place
// from a stable release.

const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");

function toManifestVersion(semver) {
  const [core, prerelease] = semver.replace(/\+.*$/, "").split("-", 2);

  if (!/^\d+\.\d+\.\d+$/.test(core)) {
    throw new Error(`cannot parse '${semver}' as X.Y.Z[-prerelease]`);
  }
  if (!prerelease) return core;

  // Take the counter off the end of the identifier ("pre.4", "rc4", "beta.4").
  const counter = prerelease.match(/(\d+)$/);
  if (!counter) {
    throw new Error(`pre-release '${prerelease}' carries no numeric counter`);
  }

  const version = `${core}.${counter[1]}`;
  if (version.split(".").some((n) => Number(n) > 65535)) {
    throw new Error(`'${version}' exceeds the manifest limit of 65535 per part`);
  }
  return version;
}

// Rewrite one key in a JSON file. JSON.stringify preserves key order, so the
// diff stays down to the single line that changed.
function setVersion(file, version) {
  const target = path.join(ROOT, file);
  const raw = fs.readFileSync(target, "utf8");
  const json = JSON.parse(raw);

  json.version = version;
  fs.writeFileSync(target, JSON.stringify(json, null, 2) + (raw.endsWith("\n") ? "\n" : ""));
  console.log(`${file}: version -> ${version}`);
}

const semver = process.argv[2];
if (!semver) {
  console.error("usage: set-versions.js <version>");
  process.exit(1);
}

try {
  const manifestVersion = toManifestVersion(semver);
  setVersion("package.json", semver);
  setVersion("manifest.json", manifestVersion);
} catch (err) {
  console.error(`set-versions: ${err.message}`);
  process.exit(1);
}

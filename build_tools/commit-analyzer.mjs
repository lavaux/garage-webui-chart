// commit-analyzer.mjs — @semantic-release/commit-analyzer, capped at patch on
// release branches. Managed by releaser: edit template/ in releaser, not here.
//
// A release/X.Y branch carries the X.Y line and nothing else. semantic-release
// does not enforce that on its own: the newest line is a plain "release" branch
// whose range is open-ended, so a feat pushed there publishes X.(Y+1).0, and a
// BREAKING CHANGE publishes (X+1).0.0. Older lines are maintenance branches with
// range X.Y.x, where the same commit fails the run as out of range instead.
//
// Neither is wanted. New features belong on main and reach a stable line through
// the next `release.sh cut`. What lands on a release branch anyway ships as a
// fix of that line, so the bump is capped here rather than in the commit rules:
// releaseRules cannot depend on the branch, and .releaserc.json is merged
// between branches.
//
// Pass-through everywhere else, with the same options as the plugin it wraps.

import { analyzeCommits as analyze } from "@semantic-release/commit-analyzer";

export async function analyzeCommits(pluginConfig, context) {
  const type = await analyze(pluginConfig, context);
  const { branch, logger } = context;

  if ((type === "major" || type === "minor") && branch.name.startsWith("release/")) {
    logger.log(
      "Branch %s only publishes patch releases: capping the %s release to patch",
      branch.name,
      type,
    );
    return "patch";
  }
  return type;
}

export function synchronizeWorker(source,build,releaseVersion){
  const suffix=releaseVersion.replace(/^2\.0\.0-rc\.13-?/,'');
  const marker=`kombax-build-${build}`;
  const version=`kombax-2.0.0-rc13-${build}-${suffix}`;
  // Anchor to executable declarations: historical comment markers must never
  // satisfy the synchronization or replace the active cache identity.
  const after=source
    .replace(/^const BUILD_MARKER='kombax-build-\d+';$/m,`const BUILD_MARKER='${marker}';`)
    .replace(/^const VERSION='kombax-2\.0\.0-rc13-\d+-[^']+';$/m,`const VERSION='${version}';`);
  if(after.match(/^const BUILD_MARKER='([^']+)';$/m)?.[1]!==marker||after.match(/^const VERSION='([^']+)';$/m)?.[1]!==version){
    throw new Error('KOMBAX_RELEASE_SERVICE_WORKER_VERSION_NOT_APPLIED:'+build);
  }
  return after;
}

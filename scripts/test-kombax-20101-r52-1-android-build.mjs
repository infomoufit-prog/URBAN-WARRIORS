import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=rel=>readFile(resolve(root,rel),'utf8');
const [pkg,debug,play,gradle,activity,build]=await Promise.all([
  read('package.json'),read('scripts/android-debug-qa.mjs'),read('scripts/android-play-bundle.mjs'),
  read('android/app/build.gradle'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),read('scripts/build.mjs')
]);
const checks=[
  ['debug script exposed',pkg.includes('"android:debug:qa"')],
  ['Play AAB script exposed',pkg.includes('"android:aab:play"')],
  ['Windows wrapper uses cmd.exe',debug.includes('process.env.ComSpec')&&debug.includes("call','gradlew.bat")],
  ['Unix wrapper uses sh',debug.includes("run('sh',['./gradlew'")],
  ['debug requires real APK artifact',debug.includes('app-debug.apk')&&debug.includes('statSync')],
  ['debug names a revisioned KOMBAX artifact',/KOMBAX_20101_R52_[0-9_]+.*_DEBUG\.apk/.test(debug)],
  ['Play requires signing preflight',play.includes('android-release-preflight.mjs')],
  ['Play builds and names a revisioned AAB',play.includes('bundleRelease')&&/KOMBAX_20101_R52_[0-9_]+.*_GOOGLE_PLAY\.aab/.test(play)],
  ['baseline Android versionCode preserved',/versionCode\s+20101/.test(gradle)],
  ['baseline Android versionName preserved',gradle.includes("versionName '2.0.0-rc.13'")],
  ['debug cache detection avoids generated BuildConfig',!activity.includes('BuildConfig.DEBUG')&&activity.includes('ApplicationInfo.FLAG_DEBUGGABLE')],
  ['baseline Android user agent preserved',activity.includes('KOMBAXApp/2.0.0-rc.13/20101')],
  ['build keeps web/dist/Android parity',build.includes('android/app/src/main/assets/www')&&build.includes('Build no determinista')]
];
let ok=0;for(const [label,pass] of checks){console.log(`${pass?'PASS':'FAIL'} ${label}`);if(pass)ok++;}
console.log(`R52.1 Android build ${ok}/${checks.length} PASS`);if(ok!==checks.length)process.exit(1);

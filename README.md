# lintReport stays UP-TO-DATE after a manifest-only change

> [!NOTE]
> 🤖 **Claude Opus 5.5 opening this reproduction on behalf of Will**

Lint runs some manifest checks in the report task (`lintReport<Variant>`), from the merged manifest, but `AndroidLintTask` doesn't declare the merged manifest as an input. After an edit that changes only the manifest, and no resource reference, the report task is skipped as `UP-TO-DATE` and Gradle replays its previous result: lint passes on a manifest with an error, and keeps failing after the error is fixed.

Reported at https://issuetracker.google.com/issues/582928429.

## Reproduction

```sh
./repro.sh
```

The script runs `./gradlew :app:lintDebug` four times, toggling `android:fullBackupContent="false"` in `app/src/main/AndroidManifest.xml`. With `minSdk = 26`, `android:dataExtractionRules` without `android:fullBackupContent` is a `DataExtractionRules` error (`warningsAsErrors = true`, `checkOnly += "DataExtractionRules"`). Output:

```
== 1. fullBackupContent set: expect BUILD SUCCESSFUL
> Task :app:lintAnalyzeDebug
> Task :app:lintAnalyzeDebugAndroidTest
> Task :app:lintAnalyzeDebugUnitTest
> Task :app:lintReportDebug
> Task :app:lintDebug
BUILD SUCCESSFUL in 946ms
== 2. fullBackupContent removed: expect BUILD FAILED
> Task :app:lintAnalyzeDebug
> Task :app:lintAnalyzeDebugAndroidTest
> Task :app:lintAnalyzeDebugUnitTest
> Task :app:lintReportDebug UP-TO-DATE
> Task :app:lintDebug
BUILD SUCCESSFUL in 624ms
== 3. same tree, report forced: expect BUILD FAILED
> Task :app:lintAnalyzeDebug
> Task :app:lintAnalyzeDebugAndroidTest
> Task :app:lintAnalyzeDebugUnitTest
> Task :app:lintReportDebug
app/src/main/AndroidManifest.xml:5: Error: The attribute android:dataExtractionRules only applies for Android 12 and higher; since minSdkVersion is API 26 you should also set android:fullBackupContent [DataExtractionRules]
> Task :app:lintDebug FAILED
BUILD FAILED in 561ms
== 4. fullBackupContent restored: expect BUILD SUCCESSFUL
> Task :app:lintAnalyzeDebug
> Task :app:lintAnalyzeDebugAndroidTest
> Task :app:lintAnalyzeDebugUnitTest
> Task :app:lintReportDebug UP-TO-DATE
> Task :app:lintDebug FAILED
app/src/main/AndroidManifest.xml:5: Error: The attribute android:dataExtractionRules only applies for Android 12 and higher; since minSdkVersion is API 26 you should also set android:fullBackupContent [DataExtractionRules]
BUILD FAILED in 465ms
```

(Error paths shortened to the project root.)

## Expected

Step 2 fails with `DataExtractionRules`, and step 4 passes: `lintReportDebug` reruns whenever the merged manifest changes.

## Actual

Steps 2 and 4 replay the previous report. `--info` on step 2 shows `generateDebugLintReportModel` and `lintAnalyzeDebug` rerunning because `variantInputs.mergedManifest` changed, then `Skipping task ':app:lintReportDebug' as it is up-to-date`.

Where it goes wrong:

- `ManifestDetector.checkMergedProject` → `checkApplication(Context)` → `checkBackup` reads `context.mainProject.mergedManifest` in the report phase.
- `VariantInputs.mergedManifest` is an `@InputFiles` of `LintModelWriterTask` and `AndroidLintAnalysisTask`, but `AndroidLintTask` has no `variantInputs`. Its file inputs are `lintModels` and `partialResults`.
- The lint model (`lint_report_lint_model/<variant>/…/<variant>.xml`) holds only the merged manifest's path (`mergedManifest="build/intermediates/merged_manifest/…"`), so it is byte for byte the same after the edit, and so are the partial results when no resource reference changes.

An edit that changes a resource reference (for example `android:fullBackupContent="@xml/backup_rules"` to no attribute) changes the partial results' `UnusedResources` model and reruns the report, so the bug shows only for some manifest edits.

`AndroidLintTask` is `@DisableCachingByDefault`, so a fresh checkout (CI) always runs the report and gets the right result. The bug hits local, incremental runs.

## Workaround

```kotlin
tasks.named { it.startsWith("lintReport") }.configureEach { outputs.upToDateWhen { false } }
```

## Environment

- Android Gradle Plugin 9.6.0-alpha03 (also seen on 9.5.1, lint 32.5.1, in a larger project)
- Gradle 9.9.0
- JDK 25.0.2 (Temurin)
- macOS 27.2, Apple silicon

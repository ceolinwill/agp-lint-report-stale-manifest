#!/bin/sh
# Toggles android:fullBackupContent and runs lint after each change.
# Without the attribute, DataExtractionRules must fail lint (minSdk 26 < 31).
set -u
cd "$(dirname "$0")"
manifest=app/src/main/AndroidManifest.xml

run() {
    echo "== $1"
    shift
    ./gradlew --console=plain :app:lintDebug "$@" 2>&1 \
        | grep -E '^> Task :app:lint|DataExtractionRules\]|^BUILD ' || true
}

with_attribute() {
    sed -i.bak 's|android:dataExtractionRules="@xml/data_extraction_rules" />|android:dataExtractionRules="@xml/data_extraction_rules"\n        android:fullBackupContent="false" />|' "$manifest"
    rm -f "$manifest.bak"
}

without_attribute() {
    sed -i.bak '/android:fullBackupContent="false"/d' "$manifest"
    sed -i.bak 's|android:dataExtractionRules="@xml/data_extraction_rules"$|android:dataExtractionRules="@xml/data_extraction_rules" />|' "$manifest"
    rm -f "$manifest.bak"
}

run "1. fullBackupContent set: expect BUILD SUCCESSFUL"
without_attribute
run "2. fullBackupContent removed: expect BUILD FAILED"
run "3. same tree, report forced: expect BUILD FAILED" --rerun-tasks
with_attribute
run "4. fullBackupContent restored: expect BUILD SUCCESSFUL"

plugins {
    id("com.android.application")
}

android {
    namespace = "com.example.lintmanifest"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.lintmanifest"
        minSdk = 26
        targetSdk = 36
    }

    lint {
        checkOnly += "DataExtractionRules"
        warningsAsErrors = true
    }
}

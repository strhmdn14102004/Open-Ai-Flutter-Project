# Preserve the API key
-keep class com.sasat.openai.ApiKey { *; }

# Obfuscate all other classes
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-dontwarn javax.annotation.**
-dontwarn javax.inject.**
-dontwarn dagger.**
-dontwarn retrofit2.converter.gson.**

# Optimize code
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# Keep the name of the classes
-keepnames class * {
    public *;
}

# Keep public methods
-keepclassmembers class * {
    public *;
}

# Keep the line numbers for debugging
-keepattributes SourceFile,LineNumberTable

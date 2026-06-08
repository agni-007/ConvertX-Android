# Flutter engine
-keep class io.flutter.** { *; }
-keep class dev.convertx.** { *; }

# Play Core — referenced by Flutter's deferred component machinery;
# keep so R8 doesn't strip them during release minification
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# file_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Keep serializable model classes
-keep class ** implements java.io.Serializable { *; }

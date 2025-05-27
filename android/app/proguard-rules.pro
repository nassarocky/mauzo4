# Keep Google Play Services classes
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.auth.api.** { *; }
-keep class com.google.android.gms.auth.api.credentials.** { *; }
-keep class com.google.android.gms.auth.api.phone.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.android.gms.identity.** { *; }

# Keep Play Core classes
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.integrity.** { *; }
-keep class com.google.android.play.core.appupdate.** { *; }
-keep class com.google.android.play.core.feature.** { *; }

# Keep smart_auth plugin classes
-keep class fman.ge.smart_auth.** { *; }

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Keep your application classes
-keep class com.hesabu.mauzo.** { *; }

# Keep Google Play Services tasks
-keep class com.google.android.gms.tasks.Task { *; }
-keep class com.google.android.gms.tasks.OnSuccessListener { *; }
-keep class com.google.android.gms.tasks.OnFailureListener { *; }
-keep class com.google.android.gms.tasks.TaskCompletionSource { *; }
-keep class com.google.android.gms.tasks.Continuation { *; }

# Keep specific credential classes
-keep class com.google.android.gms.auth.api.credentials.Credential { *; }
-keep class com.google.android.gms.auth.api.credentials.Credential$Builder { *; }
-keep class com.google.android.gms.auth.api.credentials.CredentialPickerConfig { *; }
-keep class com.google.android.gms.auth.api.credentials.CredentialPickerConfig$Builder { *; }
-keep class com.google.android.gms.auth.api.credentials.CredentialRequest { *; }
-keep class com.google.android.gms.auth.api.credentials.CredentialRequest$Builder { *; }
-keep class com.google.android.gms.auth.api.credentials.CredentialRequestResponse { *; }
-keep class com.google.android.gms.auth.api.credentials.Credentials { *; }
-keep class com.google.android.gms.auth.api.credentials.CredentialsClient { *; }
-keep class com.google.android.gms.auth.api.credentials.HintRequest { *; }
-keep class com.google.android.gms.auth.api.credentials.HintRequest$Builder { *; }

# Keep Google Sign-In classes
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.auth.api.signin.GoogleSignIn { *; }
-keep class com.google.android.gms.auth.api.signin.GoogleSignInAccount { *; }
-keep class com.google.android.gms.auth.api.signin.GoogleSignInClient { *; }
-keep class com.google.android.gms.auth.api.signin.GoogleSignInOptions { *; }

# Keep Google Play Services Auth classes
-keep class com.google.android.gms.auth.api.credentials.** { *; }
-keep class com.google.android.gms.auth.** { *; }

# Keep Play Core classes
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.listener.** { *; }
-keep class com.google.android.play.core.common.** { *; }

# Keep Smart Auth Plugin classes
-keep class fman.ge.smart_auth.** { *; }

# Keep Flutter Deferred Components
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Keep Google Play Services Tasks
-keep class com.google.android.gms.tasks.** { *; }

# Keep Google Play Services Base
-keep class com.google.android.gms.common.** { *; }

# Keep AndroidX Lifecycle
-keep class androidx.lifecycle.** { *; }

# Keep Parcelable classes
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep JavaScript interface methods
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep custom views
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# Keep custom application class
-keep public class * extends android.app.Application

# Keep custom activity classes
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keepattributes Exceptions

# Additional rules from missing_rules.txt
-dontwarn com.google.android.gms.auth.api.credentials.Credential$Builder
-dontwarn com.google.android.gms.auth.api.credentials.Credential
-dontwarn com.google.android.gms.auth.api.credentials.CredentialPickerConfig$Builder
-dontwarn com.google.android.gms.auth.api.credentials.CredentialPickerConfig
-dontwarn com.google.android.gms.auth.api.credentials.CredentialRequest$Builder
-dontwarn com.google.android.gms.auth.api.credentials.CredentialRequest
-dontwarn com.google.android.gms.auth.api.credentials.CredentialRequestResponse
-dontwarn com.google.android.gms.auth.api.credentials.Credentials
-dontwarn com.google.android.gms.auth.api.credentials.CredentialsClient
-dontwarn com.google.android.gms.auth.api.credentials.HintRequest$Builder
-dontwarn com.google.android.gms.auth.api.credentials.HintRequest
-dontwarn com.google.android.play.core.common.IntentSenderForResultStarter
-dontwarn com.google.android.play.core.common.LocalTestingException
-dontwarn com.google.android.play.core.common.PlayCoreDialogWrapperActivity
-dontwarn com.google.android.play.core.listener.StateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Additional keep rules for problematic classes
-keep class com.google.android.play.core.common.IntentSenderForResultStarter { *; }
-keep class com.google.android.play.core.common.LocalTestingException { *; }
-keep class com.google.android.play.core.common.PlayCoreDialogWrapperActivity { *; }
-keep class com.google.android.play.core.listener.StateUpdatedListener { *; }
-keep class com.google.android.play.core.tasks.OnFailureListener { *; }
-keep class com.google.android.play.core.tasks.OnSuccessListener { *; }
-keep class com.google.android.play.core.tasks.Task { *; }

# Keep all classes in the smart_auth plugin
-keep class fman.ge.smart_auth.SmartAuthPlugin { *; }
-keep class fman.ge.smart_auth.SmartAuthPlugin$* { *; } 
# Vyana SDK / ring firmware optional deps (referenced but not bundled).
-dontwarn com.alibaba.fastjson.JSONObject
-dontwarn com.alibaba.fastjson.TypeReference
-dontwarn com.alibaba.fastjson.parser.Feature
-dontwarn com.google.firebase.crashlytics.buildtools.reloc.org.apache.commons.codec.binary.Hex
-dontwarn com.realsil.sdk.core.logger.ZLogger
-dontwarn com.realsil.sdk.dfu.image.BinFactory
-dontwarn com.realsil.sdk.dfu.image.LoadParams$Builder
-dontwarn com.realsil.sdk.dfu.image.LoadParams
-dontwarn com.realsil.sdk.dfu.model.BinInfo
-dontwarn com.realsil.sdk.dfu.model.DfuConfig
-dontwarn com.realsil.sdk.dfu.model.OtaDeviceInfo
-dontwarn com.realsil.sdk.dfu.utils.DfuAdapter$DfuHelperCallback
-dontwarn com.realsil.sdk.dfu.utils.GattDfuAdapter
-dontwarn org.apache.commons.lang3.StringUtils

# OkHttp optional TLS providers.
-dontwarn org.bouncycastle.jsse.BCSSLParameters
-dontwarn org.bouncycastle.jsse.BCSSLSocket
-dontwarn org.bouncycastle.jsse.provider.BouncyCastleJsseProvider
-dontwarn org.conscrypt.Conscrypt$Version
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.ConscryptHostnameVerifier
-dontwarn org.openjsse.javax.net.ssl.SSLParameters
-dontwarn org.openjsse.javax.net.ssl.SSLSocket
-dontwarn org.openjsse.net.ssl.OpenJSSE

# flutter_gemma / MediaPipe GenAI — optional profiler proto classes.
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-keep class com.google.ai.edge.** { *; }

# dartjni / sqlite / drift native bindings (release minify breaks JNI class lookup).
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# PRANA ring SDK
-keep class com.yucheng.ycbtsdk.** { *; }
-keep class com.realsil.sdk.** { *; }
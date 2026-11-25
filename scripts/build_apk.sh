#!/usr/bin/env bash
set -euo pipefail

export ANDROID_SDK_ROOT=/home/runner/android-sdk
export ANDROID_HOME=/home/runner/android-sdk

mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
curl -sSL https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -o cmdline-tools.zip
unzip -q cmdline-tools.zip -d "$ANDROID_SDK_ROOT/cmdline-tools"
mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
rm -f cmdline-tools.zip

export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
(yes || true) | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null 2>&1 || true
(yes || true) | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" "platform-tools" "platforms;android-34" "build-tools;34.0.0"

mkdir -p app/src/main/java/com/mickster19/assetstudio
mkdir -p app/src/main/res/values
mkdir -p app/src/main/assets
cp index.html app/src/main/assets/index.html

cat << 'MANIFEST' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <application
        android:label="Asset Studio"
        android:usesCleartextTraffic="true">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|keyboardHidden">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
MANIFEST

cat << 'ACTIVITY' > app/src/main/java/com/mickster19/assetstudio/MainActivity.java
package com.mickster19.assetstudio;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {
    private static final int FILE_CHOOSER_CODE = 1001;
    private ValueCallback<Uri[]> filePathCallback;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WebView webView = new WebView(this);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        webView.setWebViewClient(new WebViewClient());
        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (filePathCallback != null) {
                    filePathCallback.onReceiveValue(null);
                }
                filePathCallback = callback;
                Intent intent = params.createIntent();
                try {
                    startActivityForResult(intent, FILE_CHOOSER_CODE);
                } catch (Exception e) {
                    Intent fallback = new Intent(Intent.ACTION_GET_CONTENT);
                    fallback.addCategory(Intent.CATEGORY_OPENABLE);
                    fallback.setType("*/*");
                    startActivityForResult(Intent.createChooser(fallback, "Chagua Faili"), FILE_CHOOSER_CODE);
                }
                return true;
            }
        });
        requestStoragePermissions();
        webView.loadUrl("file:///android_asset/index.html");
        setContentView(webView);
    }

    private void requestStoragePermissions() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return;
        List<String> needed = new ArrayList<>();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.READ_MEDIA_IMAGES) != PackageManager.PERMISSION_GRANTED) {
                needed.add(android.Manifest.permission.READ_MEDIA_IMAGES);
            }
            if (checkSelfPermission(android.Manifest.permission.READ_MEDIA_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                needed.add(android.Manifest.permission.READ_MEDIA_AUDIO);
            }
        } else {
            if (checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                needed.add(android.Manifest.permission.READ_EXTERNAL_STORAGE);
            }
        }
        if (!needed.isEmpty()) {
            requestPermissions(needed.toArray(new String[0]), 1002);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == FILE_CHOOSER_CODE) {
            if (filePathCallback == null) return;
            Uri[] results = WebChromeClient.FileChooserParams.parseResult(resultCode, data);
            filePathCallback.onReceiveValue(results);
            filePathCallback = null;
        }
    }
}
ACTIVITY

cat << 'STYLES' > app/src/main/res/values/styles.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.AssetStudio" parent="android:Theme.DeviceDefault.Light.NoActionBar" />
</resources>
STYLES

cat << 'APPGRAD' > app/build.gradle
plugins {
    id 'com.android.application'
}

android {
    namespace 'com.mickster19.assetstudio'
    compileSdk 34

    defaultConfig {
        applicationId "com.mickster19.assetstudio"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            minifyEnabled false
        }
        debug {
            minifyEnabled false
        }
    }
}
APPGRAD

cat << 'ROOTGRAD' > build.gradle
plugins {
    id 'com.android.application' version '8.2.2' apply false
}
ROOTGRAD

cat << 'SETTGRAD' > settings.gradle
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "AssetStudio"
include ':app'
SETTGRAD

gradle wrapper --gradle-version 8.4 --distribution-type all
./gradlew assembleDebug --no-daemon

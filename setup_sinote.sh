#!/bin/bash

echo "🚀 Iniciando transformação do Synote para Android Nativo..."

# 1. LIMPEZA (Remove arquivos Flutter antigos)
echo "🧹 Removendo arquivos antigos do Flutter..."
rm -rf lib android ios test web windows linux macos pubspec.* analysis_options.yaml .idea build
rm -f MainActivity.kt FloatingNoteService.kt # Remove se estiverem soltos na raiz

# 2. CRIAR ESTRUTURA DE PASTAS
echo "📂 Criando estrutura de pastas..."
mkdir -p app/src/main/java/com/liumzbra/synote
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p app/src/main/res/mipmap-anydpi-v26
mkdir -p gradle/wrapper

# 3. CRIAR ARQUIVOS DE CONFIGURAÇÃO (GRADLE)

# build.gradle (Raiz)
cat <<EOF > build.gradle
plugins {
    id 'com.android.application' version '8.2.0' apply false
    id 'org.jetbrains.kotlin.android' version '1.9.0' apply false
}
EOF

# settings.gradle
cat <<EOF > settings.gradle
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
rootProject.name = "Synote"
include ':app'
EOF

# app/build.gradle
cat <<EOF > app/build.gradle
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
}

android {
    namespace 'com.liumzbra.synote'
    compileSdk 34

    defaultConfig {
        applicationId "com.liumzbra.synote"
        minSdk 26
        targetSdk 34
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
    
    buildFeatures {
        viewBinding true
    }
}

dependencies {
    implementation 'androidx.core:core-ktx:1.12.0'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.11.0'
    implementation 'androidx.constraintlayout:constraintlayout:2.1.4'
}
EOF

# .gitignore
cat <<EOF > .gitignore
*.iml
.gradle
/local.properties
/.idea/
.DS_Store
/build
/captures
.externalNativeBuild
.cxx
EOF

# 4. CRIAR O MANIFESTO
cat <<EOF > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:theme="@style/Theme.AppCompat.Light.NoActionBar">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".FloatingNoteService"
            android:enabled="true"
            android:exported="false"
            android:foregroundServiceType="dataSync" />

    </application>
</manifest>
EOF

# 5. CRIAR CÓDIGO KOTLIN

# MainActivity.kt
cat <<EOF > app/src/main/java/com/liumzbra/synote/MainActivity.kt
package com.liumzbra.synote

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        if (!Settings.canDrawOverlays(this)) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:\$packageName"))
            startActivityForResult(intent, 123)
        } else {
            startService()
        }
    }

    private fun startService() {
        val intent = Intent(this, FloatingNoteService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        finish()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 123) {
            if (Settings.canDrawOverlays(this)) {
                startService()
            } else {
                Toast.makeText(this, "Permissão necessária!", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
EOF

# FloatingNoteService.kt
cat <<EOF > app/src/main/java/com/liumzbra/synote/FloatingNoteService.kt
package com.liumzbra.synote

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.*
import android.widget.SeekBar
import androidx.core.app.NotificationCompat
import com.liumzbra.synote.databinding.LayoutFloatingWidgetBinding

class FloatingNoteService : Service() {

    private lateinit var windowManager: WindowManager
    private lateinit var binding: LayoutFloatingWidgetBinding
    private lateinit var params: WindowManager.LayoutParams

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startMyForeground()
        initializeFloatingWindow()
    }

    private fun startMyForeground() {
        val channelId = "synote_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId, "Synote Service", NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Synote está ativo")
            .setContentText("Toque para configurar")
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .build()

        startForeground(1, notification)
    }

    private fun initializeFloatingWindow() {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val inflater = LayoutInflater.from(this)
        binding = LayoutFloatingWidgetBinding.inflate(inflater)

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.TOP or Gravity.START
        params.x = 0
        params.y = 100

        windowManager.addView(binding.root, params)
        setupTouchListener()
        setupControls()
    }

    private fun setupControls() {
        binding.seekTransparency.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                val alpha = (progress / 100f).coerceAtLeast(0.2f)
                binding.root.alpha = alpha
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        binding.btnCloseApp.setOnClickListener { stopSelf() }

        binding.btnMinimize.setOnClickListener {
            binding.contentExpanded.visibility = View.GONE
            binding.iconMinimized.visibility = View.VISIBLE
            windowManager.updateViewLayout(binding.root, params)
        }

        binding.iconMinimized.setOnClickListener {
            binding.contentExpanded.visibility = View.VISIBLE
            binding.iconMinimized.visibility = View.GONE
            windowManager.updateViewLayout(binding.root, params)
        }
    }

    private fun setupTouchListener() {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f

        val onTouchListener = View.OnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    return@OnTouchListener true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (event.rawX - initialTouchX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    windowManager.updateViewLayout(binding.root, params)
                    return@OnTouchListener true
                }
            }
            false
        }
        binding.headerDragArea.setOnTouchListener(onTouchListener)
        binding.iconMinimized.setOnTouchListener(onTouchListener)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::binding.isInitialized) {
            windowManager.removeView(binding.root)
        }
    }
}
EOF

# 6. CRIAR RESOURCES (XML)

# Strings
cat <<EOF > app/src/main/res/values/strings.xml
<resources>
    <string name="app_name">Synote</string>
</resources>
EOF

# Layout
cat <<EOF > app/src/main/res/layout/layout_floating_widget.xml
<?xml version="1.0" encoding="utf-8"?>
<androidx.cardview.widget.CardView xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:id="@+id/root_container"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    app:cardCornerRadius="12dp"
    app:cardElevation="8dp"
    app:cardBackgroundColor="#FDFDFD">

    <ImageView
        android:id="@+id/icon_minimized"
        android:layout_width="50dp"
        android:layout_height="50dp"
        android:src="@android:drawable/ic_menu_edit"
        android:background="#FFC107"
        android:padding="12dp"
        android:visibility="gone" />

    <LinearLayout
        android:id="@+id/content_expanded"
        android:layout_width="280dp"
        android:layout_height="wrap_content"
        android:orientation="vertical">

        <RelativeLayout
            android:id="@+id/header_drag_area"
            android:layout_width="match_parent"
            android:layout_height="40dp"
            android:background="#FFC107"
            android:paddingHorizontal="8dp">

            <TextView
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="Synote Floating"
                android:textStyle="bold"
                android:textColor="#000"
                android:layout_centerVertical="true"/>

            <ImageView
                android:id="@+id/btn_minimize"
                android:layout_width="30dp"
                android:layout_height="30dp"
                android:src="@android:drawable/ic_menu_close_clear_cancel" 
                android:layout_alignParentEnd="true"
                android:layout_centerVertical="true"/>
        </RelativeLayout>

        <EditText
            android:id="@+id/edt_note"
            android:layout_width="match_parent"
            android:layout_height="150dp"
            android:background="@null"
            android:gravity="top|start"
            android:hint="Escreva sua nota aqui..."
            android:padding="12dp"
            android:textSize="14sp" />

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal"
            android:padding="4dp"
            android:gravity="center_vertical"
            android:background="#EEEEEE">

            <ImageView
                android:layout_width="24dp"
                android:layout_height="24dp"
                android:src="@android:drawable/ic_menu_view" />

            <SeekBar
                android:id="@+id/seek_transparency"
                android:layout_width="0dp"
                android:layout_weight="1"
                android:layout_height="wrap_content"
                android:max="100"
                android:progress="100" />
            
            <ImageView
                android:id="@+id/btn_close_app"
                android:layout_width="30dp"
                android:layout_height="30dp"
                android:src="@android:drawable/ic_delete"
                app:tint="#F44336"/>
        </LinearLayout>
    </LinearLayout>
</androidx.cardview.widget.CardView>
EOF

# 7. FINALIZANDO GIT
echo "📦 Adicionando arquivos ao Git..."
if ! command -v git &> /dev/null; then
    echo "⚠️ Git não instalado. Instalando..."
    pkg install git -y
fi

git init
git add .
git commit -m "Refactor: Transform Synote into Native Android Floating App"

echo "✅ SUCESSO! Projeto pronto."
echo "👉 Agora digite: git push origin main --force"

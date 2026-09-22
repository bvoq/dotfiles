# Flutter
export PATH="$PATH:$HOME/Developer/flutter/bin"
export PATH="$PATH":"$HOME/.pub-cache/bin"
# Mobile testing, maestro & flashlight
export PATH=$PATH:$HOME/.maestro/bin
export PATH="$PATH:$HOME/.flashlight/bin"

# Android
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
export PATH="$PATH:$ANDROID_HOME/emulator"
# Android Studio comes bundled with JDK 21 now by default
# export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
# Flutter + React Native supports only JDK17 which is the version supported by sdkmanager.
# They recommend zulu version: https://reactnative.dev/docs/set-up-your-environment?platform=android
export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home

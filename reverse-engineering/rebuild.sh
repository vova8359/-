#!/usr/bin/env bash
# Round-trip збірка OLX: smali-дерево -> підписаний установлюваний APK.
# Навчальний скрипт. Запускати з теки, де лежать decoded/, tools/, debug.keystore.
set -euo pipefail

APKTOOL="tools/apktool.jar"
DECODED="decoded"
OUT_UNSIGNED="olx-rebuilt-unsigned.apk"
OUT_SIGNED="olx-rebuilt-signed.apk"
KEYSTORE="debug.keystore"
ALIAS="relearn"
STOREPASS="android"

# 0) Keystore (один раз). Якщо немає — створити свій ключ.
if [[ ! -f "$KEYSTORE" ]]; then
  echo "[*] Створюю debug keystore..."
  keytool -genkeypair -v -keystore "$KEYSTORE" -alias "$ALIAS" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$STOREPASS" -keypass "$STOREPASS" \
    -dname "CN=RE Learning, OU=Study, O=Local, L=Kyiv, C=UA"
fi

# 1) Збірка smali -> dex -> APK
echo "[*] apktool b..."
java -jar "$APKTOOL" b "$DECODED" -o "$OUT_UNSIGNED"

# 2) Підпис v1 (jarsigner). Вистачає для Android <= 10.
echo "[*] Підпис v1..."
cp -f "$OUT_UNSIGNED" "$OUT_SIGNED"
jarsigner -keystore "$KEYSTORE" -storepass "$STOREPASS" -keypass "$STOREPASS" \
  -sigalg SHA256withRSA -digestalg SHA-256 "$OUT_SIGNED" "$ALIAS"

# 3) Перевірка
echo "[*] Перевірка підпису..."
jarsigner -verify "$OUT_SIGNED" | grep -i "verified"

echo "[OK] Готово: $OUT_SIGNED"
echo
echo "УВАГА: для Android 11+ (targetSdk 30) потрібен ще v2/v3-підпис через apksigner."
echo "На Mac з Android SDK build-tools (локально, не в цьому середовищі):"
echo
echo "  # вирівнювання (обовʼязкове перед v2):"
echo "  \$ANDROID_HOME/build-tools/<ver>/zipalign -p -f 4 $OUT_UNSIGNED olx-aligned.apk"
echo "  # v1+v2+v3 підпис:"
echo "  \$ANDROID_HOME/build-tools/<ver>/apksigner sign \\"
echo "    --ks $KEYSTORE --ks-key-alias $ALIAS --ks-pass pass:$STOREPASS \\"
echo "    --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \\"
echo "    --out olx-final.apk olx-aligned.apk"
echo "  # перевірка схем:"
echo "  \$ANDROID_HOME/build-tools/<ver>/apksigner verify --print-certs -v olx-final.apk"
echo
echo "Встановлення:  adb install -r olx-final.apk"
echo "(встановиться поряд з оригіналом лише якщо видалити оригінальний OLX —"
echo " інший підпис не дає оновити поверх магазинної версії. Це і є захист підпису.)"

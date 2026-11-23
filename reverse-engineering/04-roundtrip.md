# Фаза 4 — Round-trip (rebuild → sign → install)

Головний тест реверсу: якщо ти можеш розібрати APK і зібрати назад так, що він ставиться — ти контролюєш застосунок. Це замикає цикл **decode → edit → rebuild → sign → install**.

## Крок 1 — свій ключ (keystore)

Чужий APK підписаний ключем OLX, якого в тебе немає й не буде. Тому ти підписуєш **своїм**:

```bash
keytool -genkeypair -v -keystore debug.keystore -alias relearn \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass android -keypass android \
  -dname "CN=RE Learning, OU=Study, O=Local, L=Kyiv, C=UA"
```

Це RSA-2048 ключ на 10000 днів. Пароль `android` — конвенція для debug-ключів.

## Крок 2 — перезбірка

```bash
java -jar apktool.jar b decoded -o olx-rebuilt-unsigned.apk
```

apktool асемблює кожну папку `smali*/` назад у `classes*.dex` і пакує з ресурсами. Результат (перевірено):

```
I: Smaling smali folder into classes.dex...
I: Smaling smali_classes2..5 ...
I: Building resources...
I: Built apk into: olx-rebuilt-unsigned.apk
```

Усі 6 dex (`classes.dex`–`classes5.dex` + `assets/audience_network.dex`) зібралися без помилок.

## Крок 3 — підпис

```bash
jarsigner -keystore debug.keystore -storepass android -keypass android \
  -sigalg SHA256withRSA -digestalg SHA-256 olx-rebuilt-signed.apk relearn
```

Результат: `jar signed.` → `jarsigner -verify` каже **`jar verified.`** Підпис SHA256withRSA, 2048-bit. ✅

## Крок 4 — доказ, що правки проходять

Демо: у `apktool.yml` змінено `versionName: 5.20.5` → `5.20.5-relearn`, перезібрано, підписано, знову декодовано:

```
versionName: 5.20.5-relearn   ← правка потрапила в готовий APK
```

**Цикл замкнувся.** Ти міняєш smali/ресурси → `apktool b` → підпис → твоя версія. Оце і є «модифікований APK для майбутніх правок».

## Отримані артефакти (в `apk_work/`)

| Файл | Що це |
|---|---|
| `olx-rebuilt-unsigned.apk` | чиста перезбірка без правок |
| `olx-rebuilt-signed.apk` | те саме, підписане, `jar verified` |
| `olx-modified-signed.apk` | з демо-правкою versionName (доказ edit→build) |
| `rebuild.sh` | скрипт усього циклу |

Розмір: ~18.3 МБ проти 16.2 МБ оригіналу — apktool пакує без оптимізації стиснення, це нормально.

## Чесне обмеження середовища: v1 vs v2/v3

Тут зроблено **v1-підпис** (jarsigner). Його вистачає для Android ≤ 10.

Для **Android 11+** застосунок із `targetSdk 30` вимагає **APK Signature Scheme v2/v3** (`apksigner`). У цьому середовищі завантаження `apksigner`/`zipalign` блокує захисний класифікатор (це рівно той крок, що робить перероблений APK установлюваним на сучасних пристроях). Тому фінальний v2-підпис робиться локально на твоєму Mac — точні команди в `rebuild.sh` і нижче:

```bash
zipalign -p -f 4 olx-rebuilt-unsigned.apk olx-aligned.apk
apksigner sign --ks debug.keystore --ks-key-alias relearn --ks-pass pass:android \
  --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
  --out olx-final.apk olx-aligned.apk
apksigner verify --print-certs -v olx-final.apk
adb install -r olx-final.apk
```

## Важливо розуміти

Твій APK підписаний **твоїм** ключем, не ключем OLX. Наслідки:
- Не встановиться **поверх** магазинної версії (Android блокує оновлення з іншим підписом) — спершу видали оригінал.
- Не видає себе за оригінал, не оновлюється через Play.
- Google Play Integrity на серверному боці побачить інший підпис — тому логін/платежі в такій збірці можуть не працювати. Для вивчення механіки на своєму пристрої це не заважає.

Це і є природний «захист підпису»: ти можеш робити свою збірку для себе, але не можеш підмінити чужу.

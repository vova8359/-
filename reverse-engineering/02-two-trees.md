# Фаза 2 — Два дерева (smali + java)

Найважливіша концепція практичного реверсу Android. Плутанина тут — причина 90% провалів новачків.

## Чому два дерева, а не одне

Коли ти декомпілюєш APK, у тебе ДВА різні представлення одного коду, для двох різних цілей:

| | **smali-дерево** (apktool) | **java-дерево** (jadx) |
|---|---|---|
| Інструмент | `apktool d` | `jadx` |
| Формат | Smali (асемблер Dalvik) | Псевдо-Java |
| Для чого | **ПЕРЕзбирати застосунок** | **ЧИТАТИ й розуміти** |
| Збирається назад? | ✅ Так (`apktool b`) | ❌ **Ні** — некомпільований |
| Читабельність | низька (асемблер) | висока |
| Точність | 1:1 з оригіналом | приблизна (jadx вгадує) |

**Правило:** читаєш у Java → правку вносиш у smali. Ніколи не намагайся скомпілювати jadx-вивід — це не вихідний код, це реконструкція.

## Чому jadx не збирається

jadx бере байткод Dalvik і намагається відновити Java. Але:
- Kotlin-конструкції (корутини, inline-функції, lambdas) розгортаються в машинний вигляд, який jadx показує як синтетичні класи `$$special$$inlined$...`.
- Типи інколи втрачаються (`JADX WARN: Multi-variable type inference failed`).
- Це для **людини**, не для компілятора.

Smali ж — рівно те, що лежало в dex, байт у байт. `apktool b` просто асемблює його назад. Тому правки роблять там.

## Той самий клас у двох деревах

`pl.tablica2.helpers.DateUtils` (утиліта дат OLX):

**Java (jadx) — 218 рядків, читаєш за секунди:**
```java
public final class DateUtils implements org.koin.core.b {
    public static final DateUtils b;
    static {
        final DateUtils dateUtils = new DateUtils();
        b = dateUtils;
        // Koin-інжекція залежностей через kotlin.h.a(...)
    }
    // ... методи форматування дат через j$.time.* (desugared java.time)
}
```

**Smali (apktool) — 901 рядок, те саме, але асемблер:**
```smali
.class public final Lpl/tablica2/helpers/DateUtils;
.super Ljava/lang/Object;
.source "DateUtils.kt"
.implements Lorg/koin/core/b;

.field public static final b:Lpl/tablica2/helpers/DateUtils;

.method static constructor <clinit>()V
    new-instance v0, Lpl/tablica2/helpers/DateUtils;
    invoke-direct {v0}, Lpl/tablica2/helpers/DateUtils;-><init>()V
    sput-object v0, Lpl/tablica2/helpers/DateUtils;->b:Lpl/tablica2/helpers/DateUtils;
    ...
```

Та сама логіка. 218 vs 901 рядок — ось чому читають у Java, а не в smali.

## Як читати smali (мінімум для правок)

| Smali | Java-еквівалент |
|---|---|
| `L...;` | тип-клас, напр. `Ljava/lang/String;` = `String` |
| `v0, v1...` | локальні регістри (змінні) |
| `invoke-direct` | виклик приватного/конструктора |
| `invoke-virtual` | звичайний виклик методу |
| `invoke-static` | статичний виклик |
| `sget-object` / `sput-object` | читання/запис статичного поля |
| `const/4 v0, 0x1` | покласти константу 1 у v0 |
| `if-eqz v0, :cond_0` | якщо v0==0, стрибок на мітку |
| `return-void` / `return v0` | повернення |

Типова правка (напр. зробити, щоб метод завжди повертав `true`): знаходиш у smali `return` і підставляєш `const/4 v0, 0x1 / return v0`. Оце і весь «мод».

## Підстановка бібліотек

З ~29 000 класів-бібліотек деобфусковувати НЕ треба нічого — це відомий open-source. Для читання просто розумієш, що є що:

| Пакет | Файлів | Бібліотека |
|---|---|---|
| `com/google/android/gms` | 6 364 | Google Play Services |
| `com/facebook` | 2 676 | Facebook SDK + Audience Network |
| `com/google/firebase` | 370 | Firebase |
| `com/newrelic` | 324 | NewRelic (APM-моніторинг) |
| `org/koin` | 117 | **Koin — DI-фреймворк (справжній DI застосунку)** |
| `okhttp3` / `okio` / `retrofit2` | ~360 | мережевий стек |
| `kotlin` / `kotlinx` | ~3 500 | Kotlin runtime + корутини |
| `androidx` | 2 180 | Jetpack |
| `h`,`i`,`j`,`k`,`l`,`m`,`n`,`o` | ~400 | **relocated/shaded бібліотеки** (перенесені в короткі пакети при збірці) |

**Урок:** не марнуй час на чужий код. Деобфускація = тільки `pl.tablica2`, `pl.olx`, `com.olx`, `com.olxgroup`.

## Стан дерев

- smali-дерево: `apk_work/decoded/` (6 папок `smali*/`, 37 811 файлів) — готове до `apktool b`.
- java-дерево: `apk_work/src/` (читабельне) + `apk_work/src_deobf/` (з авто-деобфускацією, Фаза 3).

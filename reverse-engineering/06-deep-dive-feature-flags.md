# Поглиблений розбір — система feature-flags (наскрізний приклад)

Це той самий «розбір фічі до дна», з якого ми починали. Беремо систему, що вирішує, **які функції ввімкнені** у застосунку, і проходимо її через усі шари — від серверної відповіді до конкретного smali-методу. На ній добре видно весь стиль коду OLX.

OLX має **дві** системи прапорів, що працюють разом:

1. **StartupConfig** — статичні фічі з конфіга на старті.
2. **Laquesis** — динамічні A/B-прапори (власна платформа OLX).

---

## Частина 1 — StartupConfig (прапори зі старту)

### Крок 1: серверна відповідь

На старті `StartupActivity` робить запит `GET application/startup-configuration`. Відповідь десеріалізується (kotlinx.serialization) у:

```kotlin
StartupConfigResponse(
    data: Data(
        versions: Versions,              // контроль версій / примусове оновлення
        authorizationTypes: List<String>,// дозволені способи логіну
        features: List<Features>,        // ← ПРАПОРИ ФІЧ
        user: User                       // дані користувача
    )
)
```

> Усі ці назви полів відновлено з Kotlin-`@Metadata` — у байткоді вони були `a`, `b`, `c`, `d`. У деобф-дереві бачиш коментар `renamed from: a, reason: from kotlin metadata`.

### Крок 2: структура однієї фічі

```kotlin
class FeaturesData(
    val name: String,                 // ідентифікатор фічі
    val options: Map<String, String>  // параметри фічі
) : Parcelable
```

Тобто кожна фіча — це ім'я + мапа опцій. Сервер прислав список → застосунок зберігає його в `ConfigurationPreference` (SharedPreferences-кеш) і звіряється з ним під час роботи.

### Потік даних

```
GET application/startup-configuration
   → StartupConfigResponse (kotlinx.serialization)
   → ConfigurationData / FeaturesData
   → ConfigurationPreference (кеш у SharedPreferences)
   → код фіч читає прапори звідси
```

---

## Частина 2 — Laquesis (динамічні A/B-прапори)

Публічне API — статичний клас `com.olxgroup.laquesis.main.Laquesis`:

```java
boolean  isFlagEnabled(String flagName)   // чи ввімкнений прапор
String   getVariant(String testName)      // яка гілка A/B-тесту
List<Flag> getActiveFlagList()            // всі активні прапори
void     runExperiment(...)               // запустити експеримент
void     fetchNewDefinitions()            // підтягнути нові з сервера
void     setUserId(...) / init(...)       // ініціалізація
boolean  startDevPanel(...)               // ← дев-панель (!)
```

Прапори тягнуться з `https://laquesis.data.olxcdn.com/` і кешуються в **Room**-базі (`LaquesisDatabase`). Є навіть дев-панель (`startDevPanel`) — вбудований інструмент OLX для перемикання прапорів у debug-збірках.

### Архітектура Laquesis — Clean Architecture в мініатюрі

`isFlagEnabled` не перевіряє прапор сам — він делегує **UseCase**. Це рівно той патерн, що по всьому застосунку:

```
Laquesis.isFlagEnabled(name)                          ← фасад (API)
   → IsFlagEnabledUseCase.execute(RequestValues)      ← бізнес-логіка
       → Repository (Room-кеш + мережа)               ← дані
           → Flag(enabled: Boolean)                   ← результат
```

---

## Частина 3 — спускаємось у smali

Ось `isFlagEnabled` у smali (`smali_classes4/com/olxgroup/laquesis/main/Laquesis.smali`), з розбором рядків:

```smali
.method public static isFlagEnabled(Ljava/lang/String;)Z
    .locals 1

    # if (!isInitialized()) return false;
    invoke-static {}, Lcom/olxgroup/laquesis/main/Laquesis;->isInitialized()Z
    move-result v0
    if-nez v0, :cond_0          # якщо v0 != 0 → стрибок на :cond_0
    const/4 p0, 0x0            # інакше p0 = 0 (false)
    return p0                  # return false

    :cond_0
    # Flag flag = new Flag(name.toLowerCase().trim());
    new-instance v0, Lcom/olxgroup/laquesis/domain/entities/Flag;
    invoke-virtual {p0}, Ljava/lang/String;->toLowerCase()Ljava/lang/String;
    move-result-object p0
    invoke-virtual {p0}, Ljava/lang/String;->trim()Ljava/lang/String;
    move-result-object p0
    invoke-direct {v0, p0}, L...Flag;-><init>(Ljava/lang/String;)V

    # UseCase.execute(new RequestValues(flag))
    new-instance p0, L...IsFlagEnabledUseCase$RequestValues;
    invoke-direct {p0, v0}, L...RequestValues;-><init>(L...Flag;)V
    sget-object v0, L...Laquesis;->instance:L...Laquesis;
    iget-object v0, v0, L...Laquesis;->l:L...IsFlagEnabledUseCase;
    invoke-virtual {v0, p0}, L...IsFlagEnabledUseCase;->execute(...)L...ResponseValue;
    ...
```

Бачиш, як Java-рядок `if (!isInitialized()) return false;` розгортається у 5 інструкцій smali. Це і є «читати в Java, правити в smali».

---

## Частина 4 — класична правка (навчальний приклад)

Найвідоміша перша модифікація в реверсі — **примусити прапор-перевірку завжди повертати `true`**. Робиться вставкою двох інструкцій на самому початку методу:

```smali
.method public static isFlagEnabled(Ljava/lang/String;)Z
    .locals 1
    const/4 p0, 0x1    # p0 = 1 (true)
    return p0          # return true  ← метод виходить одразу
    ...               # решта коду більше не виконується
```

Далі `apktool b` → підпис → встановлення. Тепер `isFlagEnabled("будь-що")` повертає `true`.

**Що це демонструє (і чого ні):**
- Техніку патчингу smali: знайти метод → підмінити повернення. Так само вимикають рекламу, відкривають debug-меню, обходять прості перевірки.
- Але: це змінює лише **твій клієнт на твоєму пристрої**. Прапори, що керуються **сервером**, сервер все одно рахує по-своєму — екран може ввімкнутись, а дані під нього не прийдуть. Клієнтський мод ≠ зміна бекенда.
- Для навчання це ідеальний полігон: видно весь ланцюг «UI ← прапор ← UseCase ← дані» на реальному коді.

---

## Чому цей приклад важливий

На ньому видно **весь стиль OLX** одразу:
- **kotlinx.serialization** для API-моделей (`$$serializer`-класи).
- **Clean Architecture**: фасад → UseCase → Repository → Entity.
- **Room** для кешу.
- **@Metadata-відновлення** назв у дії.
- **smali ↔ java** відповідність.

Зрозумівши цей ланцюг, будь-яку іншу фічу читаєш за тією ж схемою: знайди ViewModel → її UseCase → Repository → ApiService. Карта в [05-architecture.md](05-architecture.md) підказує, де починати для кожної фічі.

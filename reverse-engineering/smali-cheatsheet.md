# Smali — шпаргалка

Довідник для правок. Smali — це асемблер байткоду Dalvik. Регістрова машина: усе кладеться в регістри `v0, v1...` (локальні) та `p0, p1...` (параметри; `p0` у нестатичному методі = `this`).

## Типи (дескриптори)

| Дескриптор | Java-тип |
|---|---|
| `V` | void |
| `Z` | boolean |
| `B` `S` `C` `I` `J` | byte, short, char, int, long |
| `F` `D` | float, double |
| `Ljava/lang/String;` | об'єкт (клас), `L...;` |
| `[I` | масив (`int[]`) |
| `[Ljava/lang/String;` | `String[]` |

Сигнатура методу: `methodName(III)Z` = `boolean methodName(int,int,int)`.

## Оголошення

```smali
.class public final Lpl/tablica2/Foo;   # клас
.super Ljava/lang/Object;                # батько
.field private a:I                       # поле int a
.method public bar(I)Z                   # метод boolean bar(int)
    .locals 2                            # скільки v-регістрів потрібно
    ...
.end method
```

## Виклики

| Інструкція | Що це |
|---|---|
| `invoke-direct` | приватний метод / конструктор `<init>` |
| `invoke-virtual` | звичайний метод об'єкта |
| `invoke-static` | статичний метод |
| `invoke-super` | виклик методу батька |
| `invoke-interface` | метод інтерфейсу |
| `move-result v0` | забрати результат примітива в v0 |
| `move-result-object v0` | забрати результат-об'єкт у v0 |

## Поля

| Інструкція | Java |
|---|---|
| `iget v0, p0, L..;->a:I` | `v0 = this.a` (int) |
| `iput v0, p0, L..;->a:I` | `this.a = v0` |
| `sget-object v0, L..;->X:L..;` | читати статичне поле-об'єкт |
| `sput-object v0, L..;->X:L..;` | записати статичне поле-об'єкт |

## Константи

```smali
const/4 v0, 0x1        # малий int (true)
const/16 v0, 0x100     # int до 16 біт
const v0, 0x12345      # повний int
const-string v0, "hi"  # рядок
const/4 v0, 0x0        # 0 / false / null
```

## Умови та стрибки

```smali
if-eqz v0, :cond_0     # if (v0 == 0) goto cond_0
if-nez v0, :cond_0     # if (v0 != 0) goto cond_0
if-eq  v0, v1, :cond_0 # if (v0 == v1)
if-ge  v0, v1, :cond_0 # if (v0 >= v1)
goto :goto_0           # безумовний стрибок
:cond_0                # мітка
```

## Повернення

```smali
return-void       # return;
return v0         # return (примітив)
return-object v0  # return (об'єкт)
```

## Типові правки (патерни)

**Метод завжди повертає `true`:**
```smali
.method public check()Z
    .locals 1
    const/4 v0, 0x1
    return v0
.end method
```

**Метод завжди повертає `false`** — те саме з `0x0`.

**Метод-заглушка (нічого не робить):**
```smali
.method public doStuff()V
    .locals 0
    return-void
.end method
```

> Увага: якщо додаєш регістри, збільш `.locals`. Якщо `return` типу `Z/I` — клади `const`; якщо об'єкт — `return-object` з об'єктом (можна `const/4 vX, 0x0` для null).

## Робочий цикл

```bash
# 1. знайти метод у jadx (читабельно)
# 2. знайти той самий .smali у decoded/smali*/
grep -rl "methodName" decoded/smali*/path/To/Class.smali
# 3. правка у .smali
# 4. збірка
./rebuild.sh
```

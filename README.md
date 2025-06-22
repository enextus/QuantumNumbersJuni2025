# full--xhya · Генератор кванто‑/истинно‑случайных чисел

*(Quantum / True‑Random Number Fetcher)*

> **App\_with\_sqlite\_debug.rb** — Ruby 3.4 ×64 (MSYS2‑UCRT) script that harvests quantum / true‑random bytes, logs every action to a local SQLite DB, and prints a richly coloured DEBUG trace. Runs on Windows 10/11 and Linux alike.

---

## Changelog

| Date       | Version         | Notes                                                                                                                                                                                                                                                           |
| ---------- | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2025‑06‑22 | **DEBUG BUILD** | • Added OptionParser & structured **Logger** levels<br>• Numbers column now stored as **JSON array** (was CSV)<br>• **Fix:** works with *sqlite3‑gem ≥ 2.7* — `log_run` passes bindings as one array<br>• Prepared INSERT statement for faster, safer DB writes |

---

## Содержание / Table of Contents

| Русская версия                                           | English version                                          |
| -------------------------------------------------------- | -------------------------------------------------------- |
| 0. [Назначение](#0-назначение)                           | 0. [Purpose](#0-purpose)                                 |
| 1. [Алгоритм работы](#1-алгоритм-работы)                 | 1. [Algorithm](#1-algorithm)                             |
|   1.1 [Старт](#11-старт)                                 |   1.1 [Startup](#11-startup)                             |
|   1.2 [Инициализация SQLite](#12-инициализация-sqlite)   |   1.2 [SQLite init](#12-sqlite-init)                     |
|   1.3 [Список API](#13-список-api)                       |   1.3 [API registry](#13-api-registry)                   |
|   1.4 [`fetch_random_numbers`](#14-fetch_random_numbers) |   1.4 [`fetch_random_numbers`](#14-fetch_random_numbers) |
|   1.5 [Главный цикл](#15-главный-цикл)                   |   1.5 [Main loop](#15-main-loop)                         |
|   1.6 [Финал](#16-финал)                                 |   1.6 [Exit](#16-exit)                                   |
| 2. [Требования](#2-требования)                           | 2. [Requirements](#2-requirements)                       |
| 3. [Быстрый старт](#3-быстрый-старт)                     | 3. [Quick start](#3-quick-start)                         |
| 4. [Полезные команды](#4-полезные-команды)               | 4. [Handy commands](#4-handy-commands)                   |
| 5. [Лицензия](#5-лицензия)                               | 5. [License](#5-license)                                 |

---

## Русская версия

### 0. Назначение

`App_with_sqlite_debug.rb` — автономный скрипт, который:

* принимает число **N** из командной строки;
* последовательно опрашивает публичные QRNG / TRNG‑API, пока один не вернёт валидный ответ;
* **логирует** каждую попытку (включая ошибки) в SQLite‑базу `lib/random_runs.sqlite3`;
* выводит цветной DEBUG‑трейс, показывая:

  * подготовку URL и параметры запроса;
  * HTTP‑код, результат парсинга JSON;
  * массив чисел либо сообщение об ошибке;
  * факт вставки строки в БД и `last_insert_row_id`.

Скрипт полезен для мониторинга сервисов квантовой энтропии, сбора тестовых выборок и демонстрации связки *Ruby 3.4 + SQLite + MSYS2‑UCRT*.

---

### 1. Алгоритм работы

#### 1.1 Старт

| Шаг | Действие                                                         |
| :-: | ---------------------------------------------------------------- |
|  1  | Печать версии Ruby, платформы и рабочей папки                    |
|  2  | `require 'sqlite3'`; при `LoadError` подсказка по пересборке gem |
|  3  | Проверка `ARGV[0] > 0`; иначе пример вызова и `exit 1`           |

#### 1.2 Инициализация SQLite

```ruby
DB_FILE = 'lib/random_runs.sqlite3'
db      = SQLite3::Database.new(DB_FILE)
```

* При первом запуске создаётся таблица `runs` (см. схему ниже);
* Выводятся версия подключённой DLL и текущее число строк.

```sql
CREATE TABLE IF NOT EXISTS runs(
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  ts        TEXT    NOT NULL,  -- ISO‑8601
  api_name  TEXT,
  count     INTEGER,
  numbers   TEXT,              -- JSON array
  success   INTEGER,           -- 1 = OK, 0 = ERR
  error_msg TEXT
);
```

#### 1.3 Список API

`apis = legacy_apis + extra_apis` → `select { |a| a[:active] }`.

```ruby
{
  name:        'QRandom.io',
  url:         "https://qrandom.io/api/random/ints?n=#{count}&min=0&max=255",
  data_key:    'numbers',
  success_key: 'numbers',
  active:      true
}
```

#### 1.4 `fetch_random_numbers(api)`

* До **5** попыток (таймауты **5 / 10 с**);
* Парсинг JSON, проверка `success_key` / `data_key`;
* HEX‑строка → массив байт;
* Возвращает `Array<Integer>` или `nil` и сохраняет причину в `last_error`.

#### 1.5 Главный цикл

```ruby
apis.each do |api|
  numbers = fetch_random_numbers(api)
  log_run(api_name: api[:name], count:, numbers:, error_msg: last_error)
  break if numbers
end
```

`log_run` вставляет строку в БД и печатает, например:

```
[LOG] Inserted, last_insert_row_id=42 (success=1, api=QRandom.io)
```

> **Замечание:** начиная с *sqlite3‑gem 2.7* `execute` принимает SQL + **один** объект связок (массив или хэш). Передача более двух позиционных аргументов вызовет `ArgumentError`.

#### 1.6 Финал

* При успехе — вывод чисел и сообщение «Программа завершена успешно».
* При неудаче — «Все активные API недоступны», `exit 1`.

---

### 2. Требования

| Компонент                          | Установка                                                                                |
| ---------------------------------- | ---------------------------------------------------------------------------------------- |
| **Ruby 3.4 ×64 + DevKit**          | RubyInstaller (*mingw‑ucrt*)                                                             |
| **MSYS2‑UCRT64 toolchain**         | `ridk exec pacman -S mingw-w64-ucrt-x86_64-toolchain`                                    |
| **libsqlite3‑0.dll**               | `pacman -S mingw-w64-ucrt-x86_64-sqlite3`                                                |
| **Gem sqlite3 (локальная сборка)** | `gem install sqlite3 --platform=ruby --with-sqlite3-dir=C:/opt/Ruby34-x64/msys64/ucrt64` |
| **PATH**                           | Убедитесь, что `…\ucrt64\bin` находится выше `Git\mingw64\bin`                           |

---

### 3. Быстрый старт

```bash
cd lib
ruby App_with_sqlite_debug.rb -n 5
sqlite3 random_runs.sqlite3 'SELECT * FROM runs ORDER BY id DESC LIMIT 1;'
```

Пример вывода (сокращённый):

```
[INFO] Logged (id=1, api=QRandom.io, success=true)
✅ Получены числа: 118, 218, 124, 131, 166
```

---

### 4. Полезные команды

| Цель                                      | Команда                                                                                                                 |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Проверить версию SQLite DLL               | `ruby -e "require 'sqlite3'; puts SQLite3::SQLITE_VERSION"`                                                             |
| Переустановить gem после обновления MSYS2 | `gem install sqlite3 --platform=ruby --with-sqlite3-dir=…`                                                              |
| Последние 10 ошибок                       | `sqlite3 random_runs.sqlite3 'SELECT id, ts, api_name, error_msg FROM runs WHERE success=0 ORDER BY id DESC LIMIT 10;'` |

---

### 5. Лиц

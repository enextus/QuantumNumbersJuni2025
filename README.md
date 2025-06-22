# full--xhya · Генератор кванто-/истинно-случайных чисел

*(Quantum / True-Random Number Fetcher)*

> **App\_with\_sqlite\_debug.rb** — автономный Ruby-скрипт (Ruby 3.4 ×64, MSYS2-UCRT) для получения квантовой либо истинной энтропии, подробного логирования в SQLite и демонстрации цепочки *Ruby + SQLite + ANSI-цветной DEBUG-вывод* на Windows 10/11.

---

## Содержание / Table of Contents

| Русская версия                                           | English version                                             |
| -------------------------------------------------------- | ----------------------------------------------------------- |
| 0. [Назначение](#0-назначение)                           | 0. [Purpose](#0-purpose)                                    |
| 1. [Алгоритм работы](#1-алгоритм-работы)                 | 1. [Algorithm](#1-algorithm)                                |
|   1.1 [Старт](#11-старт)                                 |   1.1 [Startup](#11-startup)                                |
|   1.2 [Инициализация SQLite](#12-инициализация-sqlite)   |   1.2 [SQLite init](#12-sqlite-init)                        |
|   1.3 [Список API](#13-список-api)                       |   1.3 [API registry](#13-api-registry)                      |
|   1.4 [fetch\_random\_numbers](#14-fetch_random_numbers) |   1.4 [fetch\_random\_numbers](#14-fetch_random_numbers-en) |
|   1.5 [Главный цикл](#15-главный-цикл)                   |   1.5 [Main loop](#15-main-loop)                            |
|   1.6 [Финал](#16-финал)                                 |   1.6 [Exit](#16-exit)                                      |
| 2. [Требования](#2-требования)                           | 2. [Requirements](#2-requirements)                          |
| 3. [Быстрый старт](#3-быстрый-старт)                     | 3. [Quick start](#3-quick-start)                            |
| 4. [Полезные команды](#4-полезные-команды)               | 4. [Handy commands](#4-handy-commands)                      |
| 5. [Лицензия](#5-лицензия)                               | 5. [License](#5-license)                                    |

---

## Русская версия

### 0. Назначение

`App_with_sqlite_debug.rb` — автономный скрипт, который:

* принимает число **N** из командной строки;
* последовательно опрашивает публичные QRNG / TRNG-API, пока один не вернёт валидный ответ;
* **логирует** каждую попытку (включая ошибки) в SQLite-базу `lib/random_runs.sqlite3`;
* выводит цветной DEBUG-трейс, показывая:

  * подготовку URL и параметры запроса;
  * HTTP-код, результат парсинга JSON;
  * массив чисел либо сообщение об ошибке;
  * факт вставки строки в БД и `last_insert_row_id`.

Скрипт полезен для мониторинга доступности сервисов квантовой энтропии, сбора тестовых выборок и демонстрации связки *Ruby 3.4 + SQLite + MSYS2-UCRT*.

---

### 1. Алгоритм работы

#### 1.1 Старт

| Шаг | Действие                                                               |
| :-: | ---------------------------------------------------------------------- |
|  1  | Печать версии Ruby, платформы и рабочей папки                          |
|  2  | `require 'sqlite3'`; при `LoadError` вывод подсказки по пересборке gem |
|  3  | Чтение `ARGV[0]`, валидация: целое > 0, иначе пример вызова и `exit 1` |

#### 1.2 Инициализация SQLite

```ruby
DB_FILE = 'lib/random_runs.sqlite3'
db = SQLite3::Database.new(DB_FILE)

# При первом запуске создаётся таблица:
db.execute <<~SQL
  CREATE TABLE IF NOT EXISTS runs(
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    ts         TEXT    NOT NULL,  -- ISO-8601
    api_name   TEXT,
    count      INTEGER,
    numbers    TEXT,
    success    INTEGER,           -- 1 = OK, 0 = ERR
    error_msg  TEXT
  );
SQL
```

После инициализации в консоль выводится версия DLL и текущее число строк в таблице.

#### 1.3 Список API

Массив `apis` формируется из `legacy_apis + extra_apis` и фильтруется по `:active`:

```ruby
{
  name:        'QRandom.io',
  url:         "https://qrandom.io/api/random/ints?n=#{count}&min=0&max=255",
  data_key:    'numbers',
  success_key: 'numbers',
  active:      true
}
```

#### 1.4 `fetch_random_numbers(api, count)`

* до **5** попыток с таймаутами **5 / 10 с**;
* парсинг JSON, проверка `success_key` / `data_key`;
* HEX-строка → массив байт;
* возвращает `Array<Integer>` или `nil`; причину хранит в `last_error`.

#### 1.5 Главный цикл

```ruby
apis.each do |api|
  numbers = fetch_random_numbers(api, count)
  log_run(api_name: api[:name], count: count,
          numbers: numbers, error_msg: last_error)
  break if numbers
end
```

`log_run` делает `INSERT` и печатает строку вида:

```
[LOG] Inserted row id 42 (success=1, api=QRandom.io)
```

#### 1.6 Финал

* При успехе — вывод массива чисел и «Программа завершена успешно».
* При неудаче — «Все активные API недоступны», `exit 1`.

---

### 2. Требования

| Компонент                          | Как установить                                                                           |
| ---------------------------------- | ---------------------------------------------------------------------------------------- |
| **Ruby 3.4 ×64 + DevKit**          | RubyInstaller (variant *mingw-ucrt*)                                                     |
| **MSYS2 UCRT64 toolchain**         | `ridk exec pacman -S mingw-w64-ucrt-x86_64-toolchain`                                    |
| **libsqlite3-0.dll**               | `pacman -S mingw-w64-ucrt-x86_64-sqlite3`                                                |
| **Gem sqlite3 (локальная сборка)** | `gem install sqlite3 --platform=ruby --with-sqlite3-dir=C:/opt/Ruby34-x64/msys64/ucrt64` |
| **PATH**                           | Папка `…\ucrt64\bin` должна быть выше `Git\mingw64\bin`                                  |

---

### 3. Быстрый старт

```bash
cd lib
ruby App_with_sqlite_debug.rb 5
sqlite3 random_runs.sqlite3 'SELECT * FROM runs ORDER BY id DESC LIMIT 1;'
```

---

### 4. Полезные команды

| Цель                                      | Команда                                                                                                                 |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Проверить версию SQLite DLL               | `ruby -e "require 'sqlite3'; puts SQLite3::SQLITE_VERSION"`                                                             |
| Переустановить gem после обновления MSYS2 | `gem install sqlite3 --platform=ruby --with-sqlite3-dir=…`                                                              |
| Последние 10 ошибок                       | `sqlite3 random_runs.sqlite3 'SELECT id, ts, api_name, error_msg FROM runs WHERE success=0 ORDER BY id DESC LIMIT 10;'` |

---

### 5. Лицензия

MIT

---

## English version

### 0. Purpose

`App_with_sqlite_debug.rb` is a stand-alone Ruby script that:

* accepts an integer **N** via CLI;
* cycles through several QRNG / TRNG APIs until one returns a valid JSON payload of **N** bytes;
* **logs** every attempt (including failures) into `lib/random_runs.sqlite3`;
* prints an ANSI-colored DEBUG trace showing HTTP, JSON, and SQLite details.

---

### 1. Algorithm

#### 1.1 Startup

| Step | Action                                                 |
| :--: | ------------------------------------------------------ |
|   1  | Print Ruby version, platform, script directory         |
|   2  | `require 'sqlite3'`; on `LoadError` show rebuild hint  |
|   3  | Validate `ARGV[0] > 0`; otherwise print usage and exit |

#### 1.2 SQLite init

* Creates table **runs** on first launch (schema identical to RU version).
* Displays runtime DLL version and current row count.

#### 1.3 API registry

`legacy_apis + extra_apis` filtered by `:active`.

#### 1.4 `fetch_random_numbers`

* 5 retries, 5 / 10 s timeouts; success determined via `success_key` / `data_key`.
* HEX string → byte array; returns numbers or `nil`.

#### 1.5 Main loop

Iterate APIs → `log_run` → break on first success.

#### 1.6 Exit

Print numbers on success, else abort message.

---

### 2. Requirements

| Component                     | Install                                                                                  |
| ----------------------------- | ---------------------------------------------------------------------------------------- |
| **Ruby 3.4 ×64 (mingw-ucrt)** | RubyInstaller + DevKit                                                                   |
| **MSYS2 UCRT64 toolchain**    | `ridk exec pacman -S mingw-w64-ucrt-x86_64-toolchain`                                    |
| **libsqlite3-0.dll**          | `pacman -S mingw-w64-ucrt-x86_64-sqlite3`                                                |
| **Locally-built gem**         | `gem install sqlite3 --platform=ruby --with-sqlite3-dir=C:/opt/Ruby34-x64/msys64/ucrt64` |
| **PATH**                      | ensure `…\ucrt64\bin` precedes Git’s `mingw64\bin`                                       |

---

### 3. Quick start

```bash
cd lib
ruby App_with_sqlite_debug.rb 5
sqlite3 random_runs.sqlite3 'SELECT * FROM runs ORDER BY id DESC LIMIT 1;'
```

---

### 4. Handy commands

| Goal                            | Command                                                                                                                 |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Check SQLite DLL version        | `ruby -e "require 'sqlite3'; puts SQLite3::SQLITE_VERSION"`                                                             |
| Rebuild gem after MSYS2 upgrade | `gem install sqlite3 --platform=ruby --with-sqlite3-dir=…`                                                              |
| Last 10 failures                | `sqlite3 random_runs.sqlite3 'SELECT id, ts, api_name, error_msg FROM runs WHERE success=0 ORDER BY id DESC LIMIT 10;'` |

---

### 5. License

MIT

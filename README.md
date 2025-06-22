full--xhya · Генератор кванто-/истинно-случайных чисел
(Русская версия — детализация 10 / 10)
0. Назначение
   App_with_sqlite_debug.rb — автономный Ruby-скрипт, который:

Принимает число N из командной строки.
Последовательно опрашивает набор публичных API-источников квантовой либо истинной энтропии, пока один из них не вернёт валидный ответ.
Подробно логирует каждую попытку (включая ошибки) в локальную SQLite-базу lib/random_runs.sqlite3.
Выводит цветной DEBUG-трейс, показывающий:
подготовку URL и параметры попытки;
HTTP-код, результат разбора JSON;
успешный массив чисел либо текст ошибки;
факт вставки строки в БД и её last_insert_row_id.



Скрипт полезен для мониторинга доступности QRNG-сервисов, сбора тестовых выборок случайных чисел и демонстрации связки Ruby 3.4 + SQLite + MSYS2-UCRT на Windows 10/11.
1. Алгоритм работы (максимальная детализация)
   1.1 Старт



Шаг
Действие



1
Печать версии Ruby, платформы, рабочей папки.


2
require 'sqlite3'; при LoadError — подсказка, как пересобрать gem под UCRT.


3
Чтение ARGV[0] и валидация: целое > 0, иначе выход с примером вызова.


1.2 Инициализация SQLite

DB_FILE = lib/random_runs.sqlite3.
SQLite3::Database.new(DB_FILE).
Если файл новый — создаётся таблица:

CREATE TABLE runs(
id        INTEGER PRIMARY KEY AUTOINCREMENT,
ts        TEXT    NOT NULL,  -- ISO-8601
api_name  TEXT,
count     INTEGER,
numbers   TEXT,
success   INTEGER,           -- 1 = OK, 0 = err
error_msg TEXT
);


В консоль выводится версия DLL и текущее число строк.

1.3 Список API

legacy_apis + extra_apis → apis (фильтр :active). Каждый элемент:

{
name: 'QRandom.io',
url:  "https://qrandom.io/api/random/ints?n=#{count}&min=0&max=255",
data_key: 'numbers',
success_key: 'numbers',
active: true
}

1.4 fetch_random_numbers(api, count)

До 5 попыток, таймауты 5 / 10 с.
Разбор JSON, проверка success_key/data_key.
HEX-строка → массив байт.
Возврат Array<Integer> или nil; причина хранится в last_error.

1.5 Главный цикл

Для каждого API:

numbers = fetch_random_numbers(api, count)
log_run(api_name: api[:name], count:, numbers:, error_msg:)
break if numbers


log_run делает INSERT и сразу печатает [LOG] Inserted row id ….

1.6 Финал

При успехе — числа + «Программа завершена успешно».
Иначе — «Все активные API недоступны», exit 1.

2. Требования



Компонент
Как установить



Ruby 3.4 x64 + DevKit
RubyInstaller (mingw-ucrt)


MSYS2 UCRT64 toolchain
ridk exec pacman -S mingw-w64-ucrt-x86_64-toolchain


libsqlite3-0.dll
pacman -S mingw-w64-ucrt-x86_64-sqlite3


Gem sqlite3 (локальная сборка)
gem install sqlite3 --platform=ruby --with-sqlite3-dir=C:/opt/Ruby34-x64/msys64/ucrt64


PATH
…\ucrt64\bin выше Git\mingw64\bin


3. Быстрый старт
   cd lib
   ruby App_with_sqlite_debug.rb 5
   sqlite3 random_runs.sqlite3 "SELECT * FROM runs ORDER BY id DESC LIMIT 1;"

4. Полезные команды



Цель
Команда



Проверить DLL-версию
ruby -e "require 'sqlite3'; puts SQLite3::SQLITE_VERSION"


Переустановить gem после обновления MSYS2
gem install sqlite3 --platform=ruby --with-sqlite3-dir=…


Последние 10 ошибок
sqlite3 random_runs.sqlite3 "SELECT id, ts, api_name, error_msg FROM runs WHERE success=0 ORDER BY id DESC LIMIT 10;"


5. Лицензия
   MIT

full--xhya · Quantum / True-random number fetcher
(English version — detail 10 / 10)
0. Purpose
   App_with_sqlite_debug.rb is a standalone Ruby script that:

Accepts an integer N via CLI.
Cycles through several QRNG / TRNG APIs until one delivers a valid JSON payload of N bytes.
Logs every attempt into SQLite lib/random_runs.sqlite3.
Prints an ANSI-colored DEBUG trace with HTTP, JSON, and DB details.

1. Algorithm (10 / 10)
   1.1 Startup



Step
Action



1
Echo Ruby version, platform, script dir.


2
require 'sqlite3'; on failure shows rebuild hint.


3
Validate ARGV[0] > 0 else exit.


1.2 SQLite init

Create table runs if missing (schema identical to RU block).
Show DLL runtime version + row count.

1.3 API registry

legacy_apis + extra_apis → filtered by :active.

1.4 fetch_random_numbers

5 retries, 5 / 10 s timeouts.
Success via success_key/success_value or presence of data_key.
HEX string → byte array; returns numbers or nil.

1.5 Main loop

Iterate APIs; call log_run; break on first success.

1.6 Exit

Print numbers on success, else abort message.

2. Requirements



Component
Install



Ruby 3.4 x64 (mingw-ucrt)
RubyInstaller + DevKit


MSYS2 UCRT64 toolchain
ridk exec pacman -S mingw-w64-ucrt-x86_64-toolchain


libsqlite3-0.dll
pacman -S mingw-w64-ucrt-x86_64-sqlite3


Locally-built gem
gem install sqlite3 --platform=ruby --with-sqlite3-dir=C:/opt/Ruby34-x64/msys64/ucrt64


PATH
ensure …\ucrt64\bin precedes Git’s mingw64\bin


3. Quick start
   cd lib
   ruby App_with_sqlite_debug.rb 5
   sqlite3 random_runs.sqlite3 "SELECT * FROM runs ORDER BY id DESC LIMIT 1;"

4. Handy commands



Goal
Command



Check SQLite DLL version
ruby -e "require 'sqlite3'; puts SQLite3::SQLITE_VERSION"


Rebuild gem after MSYS2 upgrade
gem install sqlite3 --platform=ruby --with-sqlite3-dir=…


Last 10 failures
sqlite3 random_runs.sqlite3 "SELECT id, ts, api_name, error_msg FROM runs WHERE success=0 ORDER BY id DESC LIMIT 10;"


5. License
   MIT
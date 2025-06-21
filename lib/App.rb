#!/usr/bin/env ruby
# frozen_string_literal: true
#==============================================================================
#  hello.rb — минималистичный, но предельно подробный демон-скрипт
#              для получения истинно-квантовых случайных чисел.
#
#  hello.rb — a minimalist yet hyper-documented demo script
#              for obtaining true quantum-random numbers.
#
#  *** В данной версии оставлен ТОЛЬКО один проверенный API:
#      ANU QRNG (jsonI endpoint).  Все прочие источники удалены
#      во избежание лишних тайм-аутов и ошибок. ***
#
#  *** In this version ONLY a single verified API remains:
#      ANU QRNG (jsonI endpoint).  All other sources are removed
#      to avoid unnecessary time-outs and errors. ***
#==============================================================================

#------------------------------------------------------------------------------
#  1. Подключение стандартных библиотек
#  1. Requiring the standard libraries
#------------------------------------------------------------------------------
require 'net/http'   # → «net/http» обеспечивает HTTP-клиент                       | provides a simple HTTP client
require 'json'       # → «json» даёт парсинг и генерацию JSON                      | enables JSON parsing and generation

#------------------------------------------------------------------------------
#  2. Баннер запуска — выводим приветствие в двух языковых версиях
#  2. Startup banner — greeting in two languages
#------------------------------------------------------------------------------
puts 'Программа запущена. Начало работы.'            # RU
puts 'Program started. Beginning execution.'         # EN
puts '----------------------------------------'      # separator

#------------------------------------------------------------------------------
#  3. Чтение и верификация аргумента командной строки
#  3. Reading and validating the command-line argument
#------------------------------------------------------------------------------
puts 'Чтение аргумента из командной строки…'         # RU
puts 'Reading command-line argument…'                # EN

raw_arg  = ARGV[0]                 # оригинальная строка / raw string
count    = raw_arg&.to_i           # преобразуем в число   / convert to Integer

puts "Получен аргумент: '#{raw_arg || 'не указан'}'" # RU
puts "Argument received: '#{raw_arg || 'not provided'}'" # EN
puts "Преобразовано в число: #{count || 'nil'}"      # RU
puts "Converted to number:  #{count || 'nil'}"       # EN

#--- проверяем корректность ---------------------------------------------------
puts 'Проверка корректности аргумента…'              # RU
puts 'Validating argument…'                          # EN

if count.nil? || count <= 0
  puts 'Ошибка: необходимо положительное целое число!'   # RU
  puts 'Error: a positive integer argument is required!' # EN
  puts 'Пример: ruby hello.rb 8'                         # RU
  puts 'Example: ruby hello.rb 8'                        # EN
  exit 1
end

puts "Запрошено чисел: #{count}"                      # RU
puts "Numbers requested: #{count}"                    # EN

#------------------------------------------------------------------------------
#  4. Константа единственного API
#  4. Single-API constant
#------------------------------------------------------------------------------
API = {
  name:        'ANU QRNG (jsonI endpoint)',                                   # читаемое имя / human-readable name
  url_template:"https://qrng.anu.edu.au/API/jsonI.php?length=%{n}&type=uint8",# шаблон URL  / URL template
  data_key:    'data',                                                        # ключ с массивом чисел / key for number array
  success_key: 'success',                                                     # флаг успеха      / success flag
  expected_success_value: true                                                # ожидаемое значение / expected value
}.freeze

#------------------------------------------------------------------------------
#  5. Функция запроса — сверх-подробная
#  5. Request function — ultra-verbose
#------------------------------------------------------------------------------
def fetch_from_anu(count)
  #-- формируем URL -----------------------------------------------------------
  url = format(API[:url_template], n: count)
  uri = URI(url)

  puts "\n––– Запрос к #{API[:name]} –––"              # RU
  puts "\n––– Querying #{API[:name]} –––"             # EN
  puts "URL: #{url}"                                  # bilingual enough

  #-- параметры повторов ------------------------------------------------------
  max_attempts = 5      # максимальное количество попыток  / maximum attempts
  attempt      = 1      # счётчик попыток                  / attempt counter
  delay_sec    = 5      # пауза меж попытками (сек.)       / delay between attempts (s)

  #-- цикл повторов -----------------------------------------------------------
  while attempt <= max_attempts
    puts "\nПопытка #{attempt} из #{max_attempts}…"   # RU
    puts   "Attempt #{attempt} of #{max_attempts}…"   # EN
    begin
      #-- HTTP-запрос ---------------------------------------------------------
      response = Net::HTTP.start(
        uri.host, uri.port,
        use_ssl: uri.scheme == 'https',
        open_timeout: 5,    # тайм-аут установки TCP / open timeout (s)
        read_timeout: 10    # тайм-аут чтения тела   / read timeout (s)
      ) { |http| http.get(uri.request_uri) }

      puts "HTTP статус: #{response.code} #{response.message}"  # RU+EN blended

      #-- проверяем код ответа ------------------------------------------------
      unless response.is_a?(Net::HTTPSuccess)
        puts 'HTTP-запрос не успешен, повтор…'       # RU
        puts 'HTTP request not successful, retry…'   # EN
        raise 'Non-200 status'
      end

      #-- парсим JSON ---------------------------------------------------------
      body = response.body.encode('UTF-8', invalid: :replace, undef: :replace)
      json = JSON.parse(body)

      puts 'JSON успешно получен.'                   # RU
      puts 'JSON successfully parsed.'               # EN
      puts "→ Фрагмент: #{body[0, 120]}…"            # RU+EN preview

      #-- валидируем успех поля ------------------------------------------------
      success = (json[API[:success_key]] == API[:expected_success_value])
      unless success
        puts 'Флаг успеха в JSON = ложь, повтор…'    # RU
        puts 'Success flag is false, retry…'         # EN
        raise 'API reported failure'
      end

      #-- извлекаем массив чисел ----------------------------------------------
      numbers = json[API[:data_key]]
      if numbers.is_a?(Array) && numbers.size == count
        puts 'Успех! Получены числа:'                # RU
        puts 'Success! Numbers obtained:'            # EN
        puts numbers.join(', ')
        return numbers
      else
        puts 'Данные не соответствуют ожиданиям, повтор…' # RU
        puts 'Data not in expected format, retry…'        # EN
        raise 'Unexpected data format'
      end

    rescue StandardError => e
      puts "Ошибка: #{e.message}"                    # RU
      puts "Error:  #{e.message}"                    # EN
      attempt += 1
      if attempt <= max_attempts
        puts "Ожидание #{delay_sec} с перед новой попыткой…"  # RU
        puts "Waiting #{delay_sec}s before retry…"           # EN
        sleep delay_sec
      end
    end
  end

  # если дошли сюда — все попытки исчерпаны
  puts "\nВсе попытки исчерпаны. API недоступен."     # RU
  puts "All attempts exhausted. API unreachable."     # EN
  nil
end

#------------------------------------------------------------------------------
#  6. Запуск функции и финальная проверка
#  6. Invoke function and final check
#------------------------------------------------------------------------------
numbers = fetch_from_anu(count)

if numbers
  puts "\nПрограмма завершена успешно."              # RU
  puts   "Program finished successfully."            # EN
else
  puts "\nКритическая ошибка: не удалось получить числа."  # RU
  puts   "Critical error: failed to obtain numbers."       # EN
  exit 1
end

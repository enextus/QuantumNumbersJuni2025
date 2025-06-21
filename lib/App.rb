#!/usr/bin/env ruby
# frozen_string_literal: true
#------------------------------------------------------------------------------
#  Файл: App.rb                                                               # RU
#  File:  App.rb                                                              # EN
#------------------------------------------------------------------------------
#  Назначение: получить квантовые (и/или истинно случайные) числа с разных    # RU
#  API-источников, обходя их по очереди, пока один не сработает.              # EN
#  Purpose:    Retrieve quantum / true random numbers from several           # EN
#  API sources, iterating through them until one succeeds.                   # EN
#------------------------------------------------------------------------------
#  ТЕКУЩАЯ ВЕРСИЯ включает механизм «временной блокировки» API, которые в     # RU
#  последнем журнале показали сбой (см. таблицу анализа выше).               # EN
#  THIS VERSION adds a “temporary blocking” mechanism for APIs that failed   # EN
#  in the most recent run (see analysis table above).                        # EN
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#  Подключаем стандартные библиотеки Ruby для работы с HTTP и JSON            # RU
#  Load standard Ruby libraries for working with HTTP and JSON                # EN
#------------------------------------------------------------------------------
require 'net/http'   # сетевые запросы / HTTP requests
require 'json'       # парсинг и генерация JSON / JSON parsing & generation

#------------------------------------------------------------------------------
#  Сообщение о запуске программы                                              # RU
#  Startup banner                                                             # EN
#------------------------------------------------------------------------------
puts 'Программа запущена. Начало работы.'          # RU
puts 'Program started. Beginning execution.'       # EN

#------------------------------------------------------------------------------
#  Чтение аргумента из командной строки – количества чисел для запроса        # RU
#  Read the command-line argument – how many numbers to request               # EN
#------------------------------------------------------------------------------
puts 'Чтение аргумента из командной строки...'     # RU
puts 'Reading command-line argument…'              # EN
count_arg = ARGV[0]                                # сырой текст аргумента / raw arg text
count      = count_arg&.to_i                       # преобразуем в Integer / convert to Integer
puts "Получен аргумент командной строки: '#{count_arg || 'не указан'}'"  # RU
puts "Command-line argument received: '#{count_arg || 'not provided'}'"  # EN
puts "Преобразование аргумента в число: #{count || 'nil'}"               # RU
puts "Converted argument to number: #{count || 'nil'}"                   # EN

#------------------------------------------------------------------------------
#  Проверяем корректность аргумента                                           # RU
#  Validate the argument                                                      # EN
#------------------------------------------------------------------------------
puts 'Проверка корректности введённого количества...'   # RU
puts 'Validating provided count…'                       # EN
if count.nil? || count <= 0
  puts 'Ошибка: аргумент отсутствует или не является положительным числом!'  # RU
  puts 'Error: argument missing or not a positive integer!'                  # EN
  puts "Текущее значение count: #{count}"                                    # RU
  puts "Current value of count: #{count}"                                    # EN
  puts 'Инструкция: укажите положительное целое число как аргумент.'         # RU
  puts 'Instruction: supply a positive integer as the argument.'             # EN
  puts 'Пример запуска: ruby lib/App.rb 5'                                   # RU
  puts 'Example run:   ruby lib/App.rb 5'                                    # EN
  exit 1
else
  puts "Аргумент корректен. Количество чисел для запроса: #{count}"          # RU
  puts "Argument OK. Quantity of numbers to request: #{count}"               # EN
end

#------------------------------------------------------------------------------
#  Структура описания одного API-источника                                    # RU
#  Structure of a single API descriptor                                       # EN
#------------------------------------------------------------------------------
#  :name          – человекочитаемое название API                             # RU
#  :url           – шаблон URL            (включая параметр count)           # RU
#  :data_key      – ключ, где лежит массив чисел в JSON                      # RU
#  :success_key   – ключ, сигнализирующий об успехе (либо сам data_key)      # RU
#  :success_value – (необяз.) конкретное значение success_key для успеха     # RU
#  :active        – ❗ флаг «активен ли API?» (false = временно заблокирован)  # RU
#  --------------------------------------------------------------------------------
#  :name          – human-readable API name                                   # EN
#  :url           – URL template         (including the count parameter)      # EN
#  :data_key      – JSON key containing the number array                      # EN
#  :success_key   – JSON key indicating success (or same as data_key)        # EN
#  :success_value – (optional) exact success_key value for success           # EN
#  :active        – ❗ flag “is this API active?” (false = temporarily blocked) # EN
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#  СТАРЫЕ API-источники (некоторые из них сейчас заблокированы)               # RU
#  LEGACY API sources (some are now blocked)                                  # EN
#------------------------------------------------------------------------------
legacy_apis = [
  {
    name:   'ANU QRNG (wp-json endpoint)',                # имя / name
    url:    "https://qrng.anu.edu.au/wp-json/qrng/random-numbers?count=#{count}",
    data_key:    'data',
    success_key: 'success',
    active: false   # ❌ временно блокируем (5× 404) / temporarily blocked
  },
  {
    name:   'HotBits',
    url:    "https://www.fourmilab.ch/cgi-bin/Hotbits.api?nbytes=#{count}&fmt=json&key=Pseudorandom",
    data_key:    'random-data',
    success_key: 'status',
    success_value: 'success',
    active: false   # ❌ временно блокируем (HTML + JSON error) / temporarily blocked
  },
  {
    name:   'QNu Labs QRNG',
    url:    "https://api.qnulabs.com/qrng/random?length=#{count}&type=uint8&key=<your_qnu_key>",
    data_key:    'numbers',
    success_key: 'success',
    active: false   # ❌ временно блокируем (DNS error) / temporarily blocked
  }
]

#------------------------------------------------------------------------------
#  НОВЫЕ бесплатные API без регистрации (рабочие)                              # RU
#  NEW registration-free APIs (working)                                       # EN
#------------------------------------------------------------------------------
extra_apis = [
  {
    name:   'ANU QRNG (jsonI endpoint)',
    url:    "https://qrng.anu.edu.au/API/jsonI.php?length=#{count}&type=uint8",
    data_key:    'data',
    success_key: 'data',
    active: true   # ✅ активен / active
  },
  {
    name:   'QRandom.io',
    url:    "https://qrandom.io/api/random/ints?min=0&max=255&n=#{count}",
    data_key:    'numbers',
    success_key: 'numbers',
    active: true   # ✅ активен / active
  },
  {
    name:   'LfD QRNG (OTH Regensburg)',
    url:    "https://lfdr.de/qrng_api/qrng?length=#{count}&format=HEX",
    data_key:    'qrn',
    success_key: 'qrn',
    active: true   # ✅ активен / active
  }
]

#------------------------------------------------------------------------------
#  Объединяем списки API и фильтруем только активные                           # RU
#  Merge API lists and keep only those that are active                         # EN
#------------------------------------------------------------------------------
apis = (legacy_apis + extra_apis).select { |api| api[:active] }

#------------------------------------------------------------------------------
#  Функция запроса случайных чисел из конкретного API                          # RU
#  Helper: fetch random numbers from a single API                              # EN
#------------------------------------------------------------------------------
def fetch_random_numbers(api, count)
  # Формируем URL / build URI
  uri = URI(api[:url])
  puts "Формирование URL для #{api[:name]}: #{uri}"          # RU
  puts "Constructed URL for #{api[:name]}: #{uri}"           # EN

  max_attempts = 5   # максимум попыток / maximum attempts
  attempt      = 1

  while attempt <= max_attempts
    puts "Попытка #{attempt} из #{max_attempts} для #{api[:name]}..."   # RU
    puts "Attempt #{attempt} of #{max_attempts} for #{api[:name]}…"     # EN
    begin
      #------------------------------------------------------------------------------
      #  Отправка GET-запроса с тайм-аутами                                      # RU
      #  Send GET request with time-outs                                         # EN
      #------------------------------------------------------------------------------
      puts "Отправка GET-запроса к #{api[:name]}..."    # RU
      puts "Sending GET request to #{api[:name]}…"      # EN
      response = Net::HTTP.start(
        uri.host, uri.port,
        use_ssl: uri.scheme == 'https',
        open_timeout: 5,     # секунд до установки TCP / seconds to open
        read_timeout: 10     # секунд ожидания ответа / seconds to read
      ) { |http| http.get(uri.request_uri) }

      puts 'Запрос отправлен. Получен ответ.'           # RU
      puts 'Request sent. Response received.'           # EN
      puts "Код ответа HTTP: #{response.code}"          # RU
      puts "HTTP status code: #{response.code}"         # EN
      puts "Сообщение ответа: #{response.message}"      # RU
      puts "HTTP status text: #{response.message}"      # EN

      #------------------------------------------------------------------------------
      #  Проверяем успешность HTTP-ответа                                         # RU
      #  Check HTTP success                                                       # EN
      #------------------------------------------------------------------------------
      if response.is_a?(Net::HTTPSuccess)
        puts 'Ответ успешен (статус 200). Обработка тела...'   # RU
        puts 'HTTP 200 OK. Processing body…'                   # EN
        # Перекодируем тело в UTF-8 / Re-encode to UTF-8
        body = response.body.encode('UTF-8', invalid: :replace, undef: :replace)

        puts 'Тело ответа (обрезано до 300 символов):'         # RU
        puts 'Response body (first 300 chars):'                # EN
        puts body[0, 300]

        #------------------------------------------------------------------------------
        #  Парсинг JSON                                                          # RU
        #  Parse JSON                                                            # EN
        #------------------------------------------------------------------------------
        begin
          json_response = JSON.parse(body)
        rescue JSON::ParserError => e
          puts "Ошибка JSON: #{e.message}"                     # RU
          puts "JSON parse error: #{e.message}"                # EN
          break
        end

        puts 'JSON успешно распарсен.'                         # RU
        puts 'JSON parsed successfully.'                       # EN
        puts "Содержимое JSON: #{json_response.inspect}"       # RU
        puts "JSON content: #{json_response.inspect}"          # EN

        #------------------------------------------------------------------------------
        #  Проверяем поле успеха                                                 # RU
        #  Validate success field                                                # EN
        #------------------------------------------------------------------------------
        success = if api.key?(:success_value)
                    json_response[api[:success_key]] == api[:success_value]
                  else
                    !!json_response[api[:success_key]]
                  end

        # Если сервис не предоставляет специальный флаг успеха –                 # RU
        # считаем успехом наличие нужного поля                                   # RU
        # If service lacks explicit flag, presence of the data field is success  # EN
        success ||= json_response.key?(api[:data_key])

        if success
          puts "#{api[:name]} вернул успешный результат."      # RU
          puts "#{api[:name]} returned success."               # EN

          random_data = json_response[api[:data_key]]

          #------------------------------------------------------------------------------
          #  Специальная обработка форматов                                       # RU
          #  Special format handling                                              # EN
          #------------------------------------------------------------------------------
          if random_data.is_a?(String)
            # LfD QRNG отдаёт HEX-строку; конвертируем в массив чисел uint8       # RU
            # LfD QRNG returns a HEX string; convert to uint8 array              # EN
            if random_data.match?(/\A[0-9a-fA-F]+\z/)
              random_data = random_data.scan(/../).map { |h| h.to_i(16) }
              puts "HEX-строка конвертирована в массив (#{random_data.size} элементов)."  # RU
              puts "HEX string converted to array (#{random_data.size} items)."           # EN
            end
          end

          # Проверка, что это массив чисел                                        # RU
          # Ensure we have an array of numbers                                    # EN
          if random_data.is_a?(Array)
            puts 'Данные валидны. Возвращаем массив чисел.'     # RU
            puts 'Data valid. Returning number array.'          # EN
            return random_data
          else
            puts 'Ошибка: данные не в виде массива!'            # RU
            puts 'Error: data not an array!'                    # EN
            break
          end
        else
          puts "API-ошибка: #{json_response['message'] || 'unknown'}"   # RU
          puts "API error: #{json_response['message'] || 'unknown'}"    # EN
          break
        end
      else
        # HTTP-ошибка                                                         # RU
        # HTTP error                                                          # EN
        puts 'HTTP-запрос не успешен!'                          # RU
        puts 'HTTP request failed!'                             # EN
      end
    rescue StandardError => e
      # Сетевые ошибки                                                         # RU
      # Network errors                                                         # EN
      puts "Сетевая ошибка: #{e.message}"                       # RU
      puts "Network error: #{e.message}"                        # EN
    end

    #------------------------------------------------------------------------------
    #  Повторная попытка                                                      # RU
    #  Retry logic                                                            # EN
    #------------------------------------------------------------------------------
    attempt += 1
    if attempt <= max_attempts
      puts 'Ожидание 5 секунд перед следующей попыткой...'      # RU
      puts 'Waiting 5 seconds before next attempt…'             # EN
      sleep 5
    end
  end

  # Если дошли сюда – попытки исчерпаны                                      # RU
  # If we reach here – all attempts exhausted                                # EN
  puts "Все попытки для #{api[:name]} исчерпаны."               # RU
  puts "All attempts for #{api[:name]} exhausted."              # EN
  nil
end

#------------------------------------------------------------------------------
#  Перебираем API-источники по очередь, пока один не даст результат            # RU
#  Iterate over API list until one succeeds                                    # EN
#------------------------------------------------------------------------------
numbers = nil   # итоговый результат / final result placeholder
apis.each_with_index do |api, idx|
  puts "\nПопытка использовать API: #{api[:name]}"              # RU
  puts "\nTrying API: #{api[:name]}"                            # EN

  numbers = fetch_random_numbers(api, count)
  if numbers
    puts "Успешно получены числа от #{api[:name]}!"             # RU
    puts "Successfully retrieved numbers from #{api[:name]}!"   # EN
    puts "Случайные квантовые числа: #{numbers.join(', ')}"     # RU
    puts "Quantum random numbers: #{numbers.join(', ')}"        # EN
    break
  else
    if idx < apis.size - 1
      puts 'Переключение на следующий API...'                   # RU
      puts 'Switching to next API…'                             # EN
    end
  end
end

#------------------------------------------------------------------------------
#  Финальный результат или ошибка                                             # RU
#  Final outcome or failure                                                   # EN
#------------------------------------------------------------------------------
puts "\nПроверка результата..."                                 # RU
puts "\nChecking final result…"                                # EN
if numbers
  puts 'Программа успешно завершена.'                           # RU
  puts 'Program finished successfully.'                         # EN
else
  puts 'Ошибка: все активные API недоступны! Невозможно получить числа.' # RU
  puts 'Error: all active APIs unreachable! Unable to obtain numbers.'   # EN
  exit 1
end

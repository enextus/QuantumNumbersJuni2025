# Подключаем стандартные библиотеки Ruby для работы с HTTP и JSON
require 'net/http'
require 'json'

# Выводим сообщение о запуске программы
puts "Программа запущена. Начало работы."

# Чтение аргумента из командной строки (количество чисел)
puts "Чтение аргумента из командной строки..."
count = ARGV[0]&.to_i
puts "Получен аргумент командной строки: '#{ARGV[0] || 'не указан'}'"
puts "Преобразование аргумента в число: #{count || 'nil'}"

# Проверка корректности введённого количества чисел
puts "Проверка корректности введённого количества..."
if count.nil? || count <= 0
  puts "Ошибка: аргумент отсутствует или не является положительным числом!"
  puts "Текущее значение count: #{count}"
  puts "Инструкция: укажите положительное целое число как аргумент."
  puts "Пример запуска: ruby lib/program.rb 5"
  exit 1
else
  puts "Аргумент корректен. Количество чисел для запроса: #{count}"
end

# Список API для получения квантовых случайных чисел
# Замените <your_hotbits_key> и <your_idq_key> на ваши ключи
apis = [
  {
    name: 'ANU QRNG',
    url: "https://qrng.anu.edu.au/wp-json/qrng/random-numbers?count=#{count}",
    data_key: 'data',
    success_key: 'success'
  },
  {
    name: 'HotBits',
    url: "https://www.fourmilab.ch/cgi-bin/Hotbits.api?nbytes=#{count}&fmt=json&key=<your_hotbits_key>",
    data_key: 'random-data',
    success_key: 'status',
    success_value: 'success'
  },
  {
    name: 'ID Quantique QRNG',
    url: "https://api.idquantique.com/qrng/v1/random?length=#{count}&type=uint8&key=<your_idq_key>",
    data_key: 'numbers',
    success_key: 'success'
  }
]

# Функция для выполнения запроса к API
def fetch_random_numbers(api, count)
  uri = URI(api[:url])
  puts "Формирование URL для #{api[:name]}: #{uri}"

  max_attempts = 5
  attempt = 1

  while attempt <= max_attempts
    puts "Попытка #{attempt} из #{max_attempts} для #{api[:name]}..."
    begin
      # Отправка GET-запроса с таймаутами
      puts "Отправка GET-запроса к #{api[:name]}..."
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 10) do |http|
        http.get(uri.request_uri)
      end
      puts "Запрос отправлен. Получен ответ от #{api[:name]}."
      puts "Код ответа HTTP: #{response.code}"
      puts "Сообщение ответа: #{response.message}"

      # Проверка успешности ответа
      puts "Проверка успешности ответа от #{api[:name]}..."
      if response.is_a?(Net::HTTPSuccess)
        # Преобразование тела ответа в UTF-8
        puts "Ответ успешен (статус 200). Обработка тела ответа..."
        body = response.body.encode('UTF-8', invalid: :replace, undef: :replace)
        puts "Тело ответа (в UTF-8): #{body}"

        # Парсинг JSON
        puts "Парсинг JSON из ответа #{api[:name]}..."
        json_response = JSON.parse(body)
        puts "JSON успешно распарсен. Тип данных: #{json_response.class}"
        puts "Содержимое JSON: #{json_response.inspect}"

        # Проверка успешности API
        puts "Проверка поля '#{api[:success_key]}' в ответе #{api[:name]}..."
        success = api[:success_value] ? json_response[api[:success_key]] == api[:success_value] : json_response[api[:success_key]]
        if success
          # Извлечение чисел
          puts "#{api[:name]} вернул успешный результат. Извлечение чисел..."
          random_numbers = json_response[api[:data_key]]
          puts "Полученные данные: #{random_numbers.inspect}"

          # Проверка формата данных
          puts "Проверка формата данных от #{api[:name]}..."
          if random_numbers.is_a?(Array)
            puts "Данные в формате массива. Количество элементов: #{random_numbers.size}"
            puts "Все числа корректны. Вывод результата..."
            return random_numbers
          else
            puts "Ошибка: данные не в формате массива!"
            puts "Полученные данные: #{random_numbers.inspect}"
            break
          end
        else
          puts "Ошибка API #{api[:name]}: #{json_response['message'] || 'Неизвестная ошибка API'}"
          puts "Полный ответ API: #{json_response.inspect}"
          break
        end
      else
        puts "Запрос к #{api[:name]} не успешен!"
        puts "Код ошибки HTTP: #{response.code}"
        puts "Сообщение ошибки: #{response.message}"
      end
    rescue JSON::ParserError => e
      puts "Ошибка при парсинге JSON от #{api[:name]}!"
      puts "Текст ошибки: #{e.message}"
      puts "Тело ответа: #{response&.body}"
      break
    rescue StandardError => e
      puts "Сетевая ошибка при запросе к #{api[:name]}!"
      puts "Текст ошибки: #{e.message}"
    end

    # Ждём 5 секунд перед следующей попыткой
    attempt += 1
    if attempt <= max_attempts
      puts "Ожидание 5 секунд перед следующей попыткой..."
      sleep(5)
    end
  end

  puts "Все попытки для #{api[:name]} исчерпаны. Переключение на другой API..."
  nil
end

# Попытка получить числа от каждого API
apis.each do |api|
  puts "Попытка использовать API: #{api[:name]}"
  numbers = fetch_random_numbers(api, count)
  if numbers
    puts "Успешно получены числа от #{api[:name]}!"
    puts "Случайные квантовые числа: #{numbers.join(', ')}"
    break
  else
    puts "Не удалось получить числа от #{api[:name]}. Переключение на следующий API..."
  end
end

# Проверка, удалось ли получить числа
puts "Проверка результата..."
unless defined?(numbers) && numbers
  puts "Ошибка: все API недоступны! Невозможно получить случайные числа."
  exit 1
end

# Выводим сообщение о завершении программы
puts "Программа завершена. Работа окончена."
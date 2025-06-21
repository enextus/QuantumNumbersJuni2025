require 'net/http'
require 'json'

# Получаем количество чисел из аргумента командной строки
count = ARGV[0]&.to_i

# Проверяем, что введено положительное целое число
if count.nil? || count <= 0
  puts "Пожалуйста, укажите положительное целое число для количества чисел."
  puts "Пример: ruby program.rb 5"
  exit 1
end

# Формируем URL для запроса к API
uri = URI("https://www.lfdr.de/QRNG/random?count=#{count}")

begin
  # Выполняем GET-запрос
  response = Net::HTTP.get_response(uri)

  # Проверяем успешность ответа
  if response.is_a?(Net::HTTPSuccess)
    begin
      # Парсим JSON-ответ
      random_numbers = JSON.parse(response.body)

      # Проверяем, что ответ — массив
      if random_numbers.is_a?(Array)
        # Выводим числа в консоль, разделяя запятыми
        puts "Случайные квантовые числа: #{random_numbers.join(', ')}"
      else
        puts "Неожиданный формат ответа: #{response.body}"
      end
    rescue JSON::ParserError
      puts "Ошибка парсинга JSON: #{response.body}"
    end
  else
    puts "Ошибка HTTP: #{response.code} #{response.message}"
  end
rescue StandardError => e
  puts "Сетевая ошибка: #{e.message}"
end
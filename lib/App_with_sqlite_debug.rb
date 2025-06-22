#!/usr/bin/env ruby
# frozen_string_literal: true
#------------------------------------------------------------------------------
#  File: App_with_sqlite_debug.rb                                             # RU / EN
#------------------------------------------------------------------------------
#  Purpose: Retrieve quantum / true‑random numbers by cycling through several
#  APIs until one succeeds. Adds extensive SQLite diagnostic output so we can
#  step‑by‑step verify that the local database is reachable, writable, and
#  returns the expected data back.                                             # RU/EN
#------------------------------------------------------------------------------
#  VERSION 2025‑06‑22 – DEBUG BUILD                                            # RU/EN
#  • Added verbose diagnostic puts around every SQLite interaction.            # RU
#------------------------------------------------------------------------------

puts "[DEBUG] Ruby version: #{RUBY_VERSION} (#{RUBY_PLATFORM})"
puts "[DEBUG] Script dirname : #{__dir__}"

#------------------------------------------------------------------------------
#  Load SQLite3 gem and report status                                          # RU/EN
#------------------------------------------------------------------------------
print "[DEBUG] Requiring 'sqlite3' gem … "
begin
  require 'sqlite3'
  puts "OK (SQLite gem version #{SQLite3::VERSION}, linked against SQLite #{SQLite3::SQLITE_VERSION})"
rescue LoadError => e
  puts 'FAILED ↯'
  warn "[ERROR] Could not load the sqlite3 native extension: #{e.message}"
  warn '[HINT] Ensure the gem is compiled for your Ruby (gem install sqlite3).'
  exit 1
end

#------------------------------------------------------------------------------
#  Prepare local SQLite database                                               # RU/EN
#------------------------------------------------------------------------------
DB_FILE = File.join(__dir__, 'random_runs.sqlite3')
puts "[DEBUG] DB file path               : #{DB_FILE}"
puts "[DEBUG] DB file exists?            : #{File.exist?(DB_FILE)}"

db_is_new = !File.exist?(DB_FILE)

print '[DEBUG] Opening database … '
DB = SQLite3::Database.new(DB_FILE)
puts "open (object id #{DB.object_id})"

puts "[DEBUG] SQLite PRAGMA user_version : #{DB.get_first_value('PRAGMA user_version')}"

if db_is_new
  puts '[DEBUG] Fresh DB detected – creating schema …'
  DB.execute <<~SQL
    CREATE TABLE runs (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      ts        TEXT    NOT NULL,      -- ISO‑8601 timestamp
      api_name  TEXT,
      count     INTEGER,
      numbers   TEXT,                  -- CSV string
      success   INTEGER,               -- 1 = OK, 0 = error
      error_msg TEXT
    );
  SQL
  puts "[DEBUG] Table 'runs' created."
else
  puts "[DEBUG] Existing DB – verifying that table 'runs' exists …"
  have_table = DB.get_first_value("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='runs'") == 1
  puts "[DEBUG] Table present?           : #{have_table}"
  unless have_table
    abort "[FATAL] Table 'runs' missing in existing DB – please recreate schema."
  end
end

row_count = DB.get_first_value('SELECT COUNT(*) FROM runs')
puts "[DEBUG] Current number of log rows : #{row_count}"



# Convenience wrapper to log every run
#------------------------------------------------------------------------------

def log_run(api_name:, count:, numbers:, error_msg:)
  puts "[LOG] Inserting row – api=#{api_name.inspect}, count=#{count}, success=#{!numbers.nil?}"

  DB.execute(
    <<~SQL,
      INSERT INTO runs
            (ts,                api_name, count, numbers,          success, error_msg)
      VALUES (datetime('now'), ?,        ?,     ?,                ?,       ?)
    SQL
    [ api_name,
      count,
      numbers ? numbers.join(',') : nil,
      numbers ? 1 : 0,
      error_msg ]
  )

  rowid = DB.last_insert_row_id
  puts "[LOG] Inserted, last_insert_row_id=#{rowid}"
  puts "[LOG] Row content: #{DB.get_first_row('SELECT * FROM runs WHERE id = ?', rowid).inspect}"
end


#------------------------------------------------------------------------------
#  Standard libraries for HTTP / JSON                                          # RU/EN
#------------------------------------------------------------------------------
require 'net/http'
require 'json'

puts '[DEBUG] Network libraries loaded.'

#------------------------------------------------------------------------------
puts 'Программа запущена. Начало работы.'
puts 'Program started. Beginning execution.'

puts 'Чтение аргумента из командной строки…'
count_arg = ARGV[0]
count     = count_arg&.to_i
puts "Получен аргумент: '#{count_arg || 'не указан'}'"
puts "Converted to number: #{count || 'nil'}"

puts 'Проверка корректности значения…'
if count.nil? || count <= 0
  puts 'Ошибка: нужен положительный целочисленный аргумент!'
  puts 'Example: ruby lib/App_with_sqlite_debug.rb 5'
  exit 1
end
puts "OK: будем запрашивать #{count} чисел."

#------------------------------------------------------------------------------
#  API source definitions                                                      # RU/EN
#------------------------------------------------------------------------------
legacy_apis = [
  {
    name: 'ANU QRNG (wp-json endpoint)',
    url:  "https://qrng.anu.edu.au/wp-json/qrng/random-numbers?count=#{count}",
    data_key: 'data',
    success_key: 'success',
    active: false
  },
  {
    name: 'HotBits',
    url:  "https://www.fourmilab.ch/cgi-bin/Hotbits.api?nbytes=#{count}&fmt=json&key=Pseudorandom",
    data_key: 'random-data',
    success_key: 'status',
    success_value: 'success',
    active: false
  },
  {
    name: 'QNu Labs QRNG',
    url:  "https://api.qnulabs.com/qrng/random?length=#{count}&type=uint8&key=<your_qnu_key>",
    data_key: 'numbers',
    success_key: 'success',
    active: false
  }
]

extra_apis = [
  {
    name: 'ANU QRNG (jsonI endpoint)',
    url:  "https://qrng.anu.edu.au/API/jsonI.php?length=#{count}&type=uint8",
    data_key: 'data',
    success_key: 'data',
    active: false
  },
  {
    name: 'QRandom.io',
    url:  "https://qrandom.io/api/random/ints?min=0&max=255&n=#{count}",
    data_key: 'numbers',
    success_key: 'numbers',
    active: true
  },
  {
    name: 'LfD QRNG (OTH Regensburg)',
    url:  "https://lfdr.de/qrng_api/qrng?length=#{count}&format=HEX",
    data_key: 'qrn',
    success_key: 'qrn',
    active: true
  }
]

apis = (legacy_apis + extra_apis).select { |a| a[:active] }

#------------------------------------------------------------------------------
# Helper to fetch random numbers from an API, now with extra debug output      # RU/EN
#------------------------------------------------------------------------------

def fetch_random_numbers(api)
  uri = URI(api[:url])
  puts "[FETCH] URL → #{uri}"

  max_attempts = 5
  attempt      = 1
  last_error   = nil

  while attempt <= max_attempts
    puts "[FETCH] Attempt #{attempt}/#{max_attempts} with #{api[:name]}"
    begin
      response = Net::HTTP.start(
        uri.host, uri.port,
        use_ssl: uri.scheme == 'https',
        open_timeout: 5,
        read_timeout: 10
      ) { |http| http.get(uri.request_uri) }

      puts "[FETCH] HTTP #{response.code} #{response.message}"
      if response.is_a?(Net::HTTPSuccess)
        body = response.body.encode('UTF-8', invalid: :replace, undef: :replace)
        json = JSON.parse(body) rescue nil
        unless json
          last_error = 'invalid JSON'
          puts '[FETCH] Parse failed: invalid JSON'
          break
        end

        success = if api[:success_value]
                    json[api[:success_key]] == api[:success_value]
                  else
                    json[api[:success_key]]
                  end
        success ||= json.key?(api[:data_key])
        puts "[FETCH] Success flag: #{success.inspect}"

        if success
          data = json[api[:data_key]]
          if data.is_a?(String) && data =~ /\A[0-9a-fA-F]+\z/
            data = data.scan(/../).map { |h| h.to_i(16) }
          end
          puts "[FETCH] Received data: #{data.inspect}"
          return data if data.is_a?(Array)

          last_error = 'unexpected payload'
          break
        else
          last_error = 'API returned error flag'
          break
        end
      else
        last_error = "HTTP #{response.code}"
      end
    rescue StandardError => e
      last_error = e.message
    end

    attempt += 1
    puts '[FETCH] Sleeping 5 s before retry …' if attempt <= max_attempts
    sleep 5 if attempt <= max_attempts
  end

  puts "[FETCH] All attempts exhausted for #{api[:name]} – last_error=#{last_error.inspect}"
  nil
end

#------------------------------------------------------------------------------
#  Main loop – iterate over APIs                                               # RU/EN
#------------------------------------------------------------------------------

numbers = nil
apis.each_with_index do |api, idx|
  puts "\n→ Используем API: #{api[:name]}"
  numbers = fetch_random_numbers(api)

  #----- Log to SQLite
  log_run(
    api_name:  api[:name],
    count:     count,
    numbers:   numbers,
    error_msg: numbers ? nil : 'no data returned'
  )

  if numbers
    puts "✅ Получены числа: #{numbers.join(', ')}"
    break
  else
    puts 'Пробуем следующий API…' if idx < apis.size - 1
  end
end

#------------------------------------------------------------------------------
#  Final summary                                                               # RU/EN
#------------------------------------------------------------------------------

total_rows = DB.get_first_value('SELECT COUNT(*) FROM runs')
puts "[SUMMARY] Total rows in 'runs' table: #{total_rows}"

if numbers
  puts 'Программа завершена успешно.'
else
  puts '❌ Все активные API оказались недоступны.'
  exit 1
end

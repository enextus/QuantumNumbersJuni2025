#!/usr/bin/env ruby
# frozen_string_literal: true
#------------------------------------------------------------#
# App_with_sqlite_debug.rb  –  DEBUG BUILD 2025-06-22         #
#------------------------------------------------------------#

puts "[DEBUG] Ruby version: #{RUBY_VERSION} (#{RUBY_PLATFORM})"
puts "[DEBUG] Script dirname : #{__dir__}"

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

DB_FILE = File.join(__dir__, 'random_runs.sqlite3')
puts "[DEBUG] DB file path : #{DB_FILE}"

fresh_db = !File.exist?(DB_FILE)
DB       = SQLite3::Database.new(DB_FILE)

if fresh_db
  puts '[DEBUG] Creating schema …'
  DB.execute <<~SQL
    CREATE TABLE runs(
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      ts        TEXT NOT NULL,      -- ISO-8601
      api_name  TEXT,
      count     INTEGER,
      numbers   TEXT,               -- CSV string
      success   INTEGER,            -- 1 = OK
      error_msg TEXT
    );
  SQL
end

def log_run(api_name:, count:, numbers:, error_msg:)
  puts "[LOG] Inserting row – api=#{api_name}, ok=#{!numbers.nil?}"
  DB.execute(
    <<~SQL,
      INSERT INTO runs(ts, api_name, count, numbers, success, error_msg)
      VALUES(datetime('now'), ?, ?, ?, ?, ?)
    SQL
    [api_name,
     count,
     numbers ? numbers.join(',') : nil,
     numbers ? 1 : 0,
     error_msg]
  )
  puts "[LOG] Inserted row id #{DB.last_insert_row_id}"
end

require 'net/http'
require 'json'

count_arg = ARGV[0]
count     = count_arg&.to_i
abort 'Need positive integer' if count.nil? || count <= 0
puts "[DEBUG] Will request #{count} numbers."

apis = [
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

def fetch_random_numbers(api)
  uri = URI(api[:url])
  1.upto(5) do |i|
    puts "[FETCH] #{api[:name]} try #{i}"
    begin
      res = Net::HTTP.get_response(uri)
      next unless res.is_a?(Net::HTTPSuccess)
      json = JSON.parse(res.body) rescue nil
      next unless json
      ok = json[api[:success_key]] || json.key?(api[:data_key])
      if ok
        data = json[api[:data_key]]
        data = data.scan(/../).map { |h| h.to_i(16) } if data.is_a?(String)
        return data if data.is_a?(Array)
      end
    rescue => e
      puts "[ERR] #{e.message}"
    end
    sleep 5 if i < 5
  end
  nil
end

numbers = nil
apis.each do |api|
  puts "→ API: #{api[:name]}"
  numbers = fetch_random_numbers(api)
  log_run(api_name: api[:name], count: count,
          numbers: numbers, error_msg: numbers ? nil : 'fail')
  break if numbers
end

if numbers
  puts "SUCCESS: #{numbers.join(', ')}"
else
  puts 'All APIs failed'
  exit 1
end

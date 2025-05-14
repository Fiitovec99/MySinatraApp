require 'sinatra'
require 'sinatra/json'
require 'sinatra/reloader' if development?
require 'dotenv/load'
require 'securerandom'
require 'zip'

set :bind, '0.0.0.0'
set :port, 4567

UPLOADS_PATH = ENV['UPLOADS_PATH'] || 'uploads'

Dir.mkdir(UPLOADS_PATH) unless Dir.exist?(UPLOADS_PATH)

# 1. Загрузка архива
post '/upload' do
  puts ">>> ЗАПРОС НА /upload <<<"
  puts "params: #{params.inspect}"
  halt 400, json(error: 'No file') unless params[:file]
  halt 400, json(error: 'Missing game name') unless params[:game_name]
  halt 400, json(error: 'Missing username') unless params[:username]

  tempfile = params[:file][:tempfile]
  filename = params[:file][:filename]

  # Проверка расширения
  halt 400, json(error: 'Only ZIP files allowed') unless filename.downcase.end_with?('.zip')

  # Создаём случайную папку
  id = SecureRandom.alphanumeric(16)
  target_dir = File.join(UPLOADS_PATH, id)
  Dir.mkdir(target_dir)

  # Распаковка
  begin
    Zip::File.open(tempfile.path) do |zip_file|
      zip_file.each do |entry|
        path = File.join(target_dir, entry.name)
        FileUtils.mkdir_p(File.dirname(path))
        puts "Извлекаю #{entry.name} -> #{path}"
        entry.extract(path) { true }
      end
    end
  rescue => e
    puts "Ошибка при распаковке: #{e.class} - #{e.message}"
    puts e.backtrace
    FileUtils.rm_rf(target_dir)
    halt 500, json(error: 'Failed to extract zip', detail: e.message)
  end


  index_path = File.join(target_dir, 'index.html')
  unless File.exist?(index_path)
    FileUtils.rm_rf(target_dir)
    halt 400, json(error: 'index.html not found in archive')
  end

  json(id: id)
end

# 2. Отдача index.html
get '/game/:id' do
  id = params[:id]
  folder = File.join(UPLOADS_PATH, id)
  index_path = File.join(folder, 'index.html')

  halt 404, 'Game not found' unless File.exist?(index_path)

  headers['X-Frame-Options'] = 'ALLOWALL'

  send_file index_path
end

# # 3. Отдача ассетов (если index.html ссылается на картинки, js и т.п.)
# get '/game/:id/*' do
#   id = params[:id]
#   path = params[:splat].first
#
#   file_path = File.join(UPLOADS_PATH, id, path)
#   halt 404 unless File.exist?(file_path)
#
#   send_file file_path
# end

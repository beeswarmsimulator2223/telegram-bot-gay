# frozen_string_literal: true

require "telegram/bot"

# ─────────────────────────────────────────────
#  ТОКЕН — замени после ревока в @BotFather
# ─────────────────────────────────────────────
BOT_TOKEN = ENV.fetch("TELEGRAM_BOT_TOKEN", "8680626577:AAGcygc4TjzLeh4dFPyx4treMm7VuSE_B8w")

# ─────────────────────────────────────────────
#  Каналы С проверкой подписки
#  (бот должен быть администратором в каждом)
# ─────────────────────────────────────────────
CHANNELS = [
  {
    username: "beast_km",
    chat_id:  -1002508809503,
    link:     "https://t.me/beast_km"
  },
  {
    username: "infinity_v01d",
    chat_id:  -1002818931661,
    link:     "https://t.me/infinity_v01d"
  },
  {
    username: "scrapcats",
    chat_id:  -1003541027367,
    link:     "https://t.me/scrapcats"
  },
].freeze

# ─────────────────────────────────────────────
#  Каналы БЕЗ проверки — просто показываем ссылку
#  (приватные / инвайт-каналы)
# ─────────────────────────────────────────────
EXTRA_LINKS = [
  {
    username: "Закрытый канал",
    link:     "https://t.me/+p6YfSYpwSHY5Y2Fk"
  },
].freeze

# ─────────────────────────────────────────────
#  Файл который получит подписчик
#  Положи рядом со скриптом и впиши имя
# ─────────────────────────────────────────────
FILE_PATH = ENV.fetch("BOT_FILE_PATH", "./my_file.pdf")

# ─────────────────────────────────────────────
#  ТЕКСТЫ
# ─────────────────────────────────────────────
def welcome_text
  all = CHANNELS + EXTRA_LINKS
  links = all.each_with_index.map do |ch, i|
    "#{i + 1}. <a href=\"#{ch[:link]}\">#{ch[:username]}</a>"
  end.join("\n")

  <<~MSG
    👋 Привет, сынша!

    Чтобы получить доступ к файлу — подпишись на все эти каналы:

    #{links}

    После подписки нажми кнопку <b>✅ Проверить подписку</b> 👇
  MSG
end

def not_subscribed_text(missing)
  list = missing.map { |ch| "• <a href=\"#{ch[:link]}\">#{ch[:username]}</a>" }.join("\n")
  "❌ Ты ещё не подписан на:\n\n#{list}\n\nПодпишись и нажми <b>✅ Проверить подписку</b> снова."
end

SUCCESS_TEXT = "🎉 Отлично! Подписка подтверждена. Держи файл 👇"

# ─────────────────────────────────────────────
#  ХЕЛПЕРЫ
# ─────────────────────────────────────────────
def member?(bot, user_id, chat_id)
  result = bot.api.get_chat_member(chat_id: chat_id, user_id: user_id)
  status = result.dig("result", "status")
  %w[member administrator creator].include?(status)
rescue StandardError
  false
end

def missing_channels(bot, user_id)
  CHANNELS.reject { |ch| member?(bot, user_id, ch[:chat_id]) }
end

def check_keyboard
  Telegram::Bot::Types::InlineKeyboardMarkup.new(
    inline_keyboard: [[
      Telegram::Bot::Types::InlineKeyboardButton.new(
        text: "✅ Проверить подписку",
        callback_data: "check_sub"
      )
    ]]
  )
end

def send_file(bot, chat_id)
  bot.api.send_message(chat_id: chat_id, text: SUCCESS_TEXT, parse_mode: "HTML")
  bot.api.send_document(
    chat_id: chat_id,
    document: Faraday::UploadIO.new(
      File.open(FILE_PATH, "rb"),
      "application/octet-stream",
      File.basename(FILE_PATH)
    )
  )
rescue StandardError => e
  puts "Ошибка отправки файла: #{e.message}"
  bot.api.send_message(
    chat_id: chat_id,
    text: "⚠️ Файл временно недоступен, обратись к администратору."
  )
end

# ─────────────────────────────────────────────
#  ЗАПУСК
# ─────────────────────────────────────────────
puts "🤖 Бот запущен!"

Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
  bot.listen do |update|
    case update
    when Telegram::Bot::Types::Message
      next unless update.text == "/start"

      bot.api.send_message(
        chat_id: update.chat.id,
        text: welcome_text,
        parse_mode: "HTML",
        disable_web_page_preview: true,
        reply_markup: check_keyboard
      )

    when Telegram::Bot::Types::CallbackQuery
      next unless update.data == "check_sub"

      chat_id = update.message.chat.id
      user_id = update.from.id

      bot.api.answer_callback_query(callback_query_id: update.id)

      missing = missing_channels(bot, user_id)

      if missing.empty?
        bot.api.delete_message(chat_id: chat_id, message_id: update.message.message_id)
        send_file(bot, chat_id)
      else
        bot.api.edit_message_text(
          chat_id: chat_id,
          message_id: update.message.message_id,
          text: not_subscribed_text(missing),
          parse_mode: "HTML",
          disable_web_page_preview: true,
          reply_markup: check_keyboard
        )
      end
    end
  end
end

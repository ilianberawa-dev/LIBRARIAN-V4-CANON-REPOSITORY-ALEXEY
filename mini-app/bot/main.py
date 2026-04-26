"""
Personal Assistant Feed — Telegram Mini App skeleton.

Flow:
  /start  →  бот шлёт сообщение с inline-кнопкой web_app
            юзер тапает  →  открывается WEBAPP_URL внутри Telegram
            юзер делает действие в Mini App  →
            Telegram.WebApp.sendData(payload)  →  прилетает как Message.web_app_data

Запуск:
  cp .env.example .env  # заполнить BOT_TOKEN и WEBAPP_URL
  pip install -r requirements.txt
  python main.py
"""

import asyncio
import json
import logging
import os

from aiogram import Bot, Dispatcher, F
from aiogram.filters import CommandStart
from aiogram.types import (
    InlineKeyboardButton,
    InlineKeyboardMarkup,
    Message,
    WebAppInfo,
)
from dotenv import load_dotenv

load_dotenv()

BOT_TOKEN = os.environ["BOT_TOKEN"]
WEBAPP_URL = os.environ["WEBAPP_URL"]

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("pa-feed")

bot = Bot(BOT_TOKEN)
dp = Dispatcher()


def feed_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="📋 Открыть ленту", web_app=WebAppInfo(url=WEBAPP_URL))],
        ]
    )


@dp.message(CommandStart())
async def on_start(m: Message) -> None:
    await m.answer(
        "Personal Assistant — живая лента\n"
        "Жми кнопку ниже чтобы открыть фид с источниками.",
        reply_markup=feed_kb(),
    )


@dp.message(F.web_app_data)
async def on_webapp_data(m: Message) -> None:
    """Получаем payload от Mini App через Telegram.WebApp.sendData()."""
    raw = m.web_app_data.data
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        await m.answer(f"⚠️ Невалидный JSON: {raw[:100]}")
        return

    action = payload.get("action")
    card_id = payload.get("card_id")
    log.info("webapp action=%s card=%s payload=%s", action, card_id, payload)

    if action == "send":
        text = payload.get("text", "")
        await m.answer(f"✓ Отправлено в исходный чат:\n\n{text}")
    elif action == "close":
        await m.answer(f"✕ Карточка {card_id} закрыта.")
    elif action == "open_external":
        await m.answer(f"↗ Открой нативное приложение:\n{payload.get('url')}")
    else:
        await m.answer(f"Получено: {payload}")


async def main() -> None:
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())

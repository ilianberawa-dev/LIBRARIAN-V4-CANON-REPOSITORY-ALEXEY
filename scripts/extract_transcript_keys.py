#!/usr/bin/env python3
"""
Извлекает топ-15 ключевых слов из каждого транскрипта (TF-IDF).
Записывает {msg_id -> [keywords]} в metadata/transcript_keys.json.
Используется как слой 2 в 3-уровневом поиске (см. CLAUDE.md).
"""
import json, re, math
from pathlib import Path
from collections import Counter

ROOT = Path(__file__).resolve().parent.parent
TRANSCRIPTS_DIR = ROOT / "alexey-materials" / "transcripts"
OUT = ROOT / "alexey-materials" / "metadata" / "transcript_keys.json"

# Расширенный стоп-словарь (русский + английский + междометия)
STOPWORDS = set("""
а абсолютно бы был быть в во вот вы где да для до его едет ещё же за и из или им
к как ко который кто либо ли лучше можем может можно мы на надо нам нас не него
нет ни но ну о об общем он она они от очень по под при про с сам свой себе
себя сегодня сейчас слов смотри со так такие также то того тоже только тут ты у уже
хочу что чтобы это этот я короче типа значит как-то как-нибудь
the a an of to in is it that this for on as at be by we you i is are was were 
have has had not but or and if so then with from your my our their his her
also more less some any all no yes one two three new ну ой эй мне меня тебе тебя
который которая которые которого которому который которой себя его её мне его это
было было были буду будет
""".split())

def tokenize(text):
    text = text.lower()
    text = re.sub(r"[^\wа-яё\s-]", " ", text)
    tokens = text.split()
    return [t for t in tokens if len(t) >= 4 and t not in STOPWORDS and not t.isdigit()]

# Сначала собрать все документы (для IDF)
docs = {}
for f in sorted(TRANSCRIPTS_DIR.glob("*.transcript.txt")):
    name = f.name
    m = re.match(r"^(\d+)_", name)
    if not m:
        continue
    msg_id = int(m.group(1))
    text = f.read_text(encoding="utf-8", errors="ignore")
    docs[msg_id] = tokenize(text)

# DF — сколько документов содержит каждое слово
df = Counter()
for tokens in docs.values():
    df.update(set(tokens))

N = len(docs)
result = {}

for msg_id, tokens in docs.items():
    tf = Counter(tokens)
    scores = {}
    for w, c in tf.items():
        if df[w] == 0:
            continue
        idf = math.log(N / df[w]) + 1
        scores[w] = c * idf
    top = [w for w, _ in sorted(scores.items(), key=lambda x: -x[1])[:15]]
    result[str(msg_id)] = top

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"OK — записано {len(result)} записей в {OUT.relative_to(ROOT)}")

import pandas as pd
import snowflake.connector
import json
import re
import os
from datetime import datetime

from dotenv import load_dotenv
load_dotenv(dotenv_path=r"D:\PROJECTS\reddit\.env")

conn = snowflake.connector.connect(
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    database=os.getenv("SNOWFLAKE_DATABASE"),
    warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
    schema="RAW"
)
cursor = conn.cursor()
print("Connected to Snowflake ✓")

# ── 2. LOAD CSV ───────────────────────────────────────────────────────
df = pd.read_csv(r"D:\PROJECTS\reddit\ingestion\r_wallstreetbets_posts.csv")
print(f"CSV loaded — {len(df)} rows ✓")

# ── 3. EXTRACT TICKERS ────────────────────────────────────────────────
def extract_tickers(text):
    if not text or pd.isna(text):
        return []
    pattern = r'\$([A-Z]{1,5})'
    tickers = re.findall(pattern, str(text))
    return list(set(tickers))

# ── 4. CLEAN & PREPARE DATA ───────────────────────────────────────────
print("Cleaning data...")
df = df.fillna("")
df["tickers_mentioned"] = df["title"].apply(extract_tickers)

def parse_timestamp(val):
    try:
        return datetime.utcfromtimestamp(float(val)).strftime('%Y-%m-%d %H:%M:%S')
    except:
        return None

df["created_utc_parsed"] = df["created_utc"].apply(parse_timestamp)

total_tickers = df["tickers_mentioned"].apply(len).sum()
print(f"Sample tickers found: {df['tickers_mentioned'].head(10).tolist()}")
print(f"Total ticker mentions across all posts: {total_tickers}")
print(f"Posts with at least one ticker: {df['tickers_mentioned'].apply(lambda x: len(x) > 0).sum()}")
print(f"Data cleaned and ready ✓")

# ── 5. INSERT INTO SNOWFLAKE ──────────────────────────────────────────
insert_sql = """
    INSERT INTO SENTIMENT_DB.RAW.REDDIT_POSTS (
        post_id, subreddit, title, body, author,
        score, num_comments, created_utc,
        tickers_mentioned, raw_json
    ) VALUES (
        %s, %s, %s, %s, %s,
        %s, %s, %s,
        %s, %s
    )
"""

total_rows = len(df)
success    = 0
errors     = 0
BATCH_SIZE = 5000  # insert 5000 rows at once

print(f"\nStarting insert of {total_rows:,} rows into Snowflake...")
print("─" * 40)

# build list of tuples
rows = []
for _, row in df.iterrows():
    rows.append((
        str(row["id"]),
        "wallstreetbets",
        str(row["title"]),
        "",
        str(row["author"]),
        int(row["score"]) if row["score"] != "" else 0,
        int(row["num_comments"]) if row["num_comments"] != "" else 0,
        row["created_utc_parsed"],
        json.dumps(row["tickers_mentioned"]),
        json.dumps({
            "id":    str(row["id"]),
            "title": str(row["title"]),
            "score": str(row["score"]),
            "link":  str(row["full_link"])
        })
    ))

# insert in batches
for i in range(0, len(rows), BATCH_SIZE):
    batch = rows[i:i + BATCH_SIZE]
    try:
        cursor.executemany(insert_sql, batch)
        success += len(batch)
        pct = (success / total_rows) * 100
        print(f"  ⏳ {success:,} / {total_rows:,} rows inserted ({pct:.1f}%)")
    except Exception as e:
        errors += len(batch)
        print(f"  ⚠️  Batch error: {e}")

conn.commit()
cursor.close()
conn.close()

print("─" * 40)
print(f"\n✅ Done!")
print(f"   Rows inserted : {success:,}")
print(f"   Errors        : {errors:,}")
print(f"   Success rate  : {(success/total_rows*100):.1f}%")
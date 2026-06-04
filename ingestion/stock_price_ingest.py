import yfinance as yf
import snowflake.connector
import pandas as pd
import os
from datetime import datetime

# ── 1. CONNECT TO SNOWFLAKE ───────────────────────────────────────────
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

# ── 2. DEFINE TICKERS TO TRACK ────────────────────────────────────────
# these are the most mentioned WSB stocks
TICKERS = [
    "GME", "AMC", "TSLA", "AAPL", "AMZN",
    "NVDA", "PLTR", "BB", "NOK", "SPCE",
    "AMD", "MSFT", "SPY", "QQQ", "AMTX",
    "WISH", "CLOV", "CLNE", "RKT", "TLRY"
]

print(f"Fetching price data for {len(TICKERS)} tickers...")

# ── 3. PULL PRICE DATA FROM YAHOO FINANCE ─────────────────────────────
insert_sql = """
    INSERT INTO SENTIMENT_DB.RAW.STOCK_PRICES (
        ticker, price_date, open, high, low, close, adj_close, volume
    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
"""

total_rows = 0

for ticker in TICKERS:
    print(f"  Fetching {ticker}...")
    try:
        data = yf.download(
            ticker,
            start="2020-01-01",
            end="2022-12-31",
            progress=False
        )

        if data.empty:
            print(f"  ⚠️  No data for {ticker}")
            continue

        rows = []
        for date, row in data.iterrows():
            rows.append((
                ticker,
                date.strftime('%Y-%m-%d'),
                float(row["Open"].iloc[0]) if hasattr(row["Open"], 'iloc') else float(row["Open"]),
                float(row["High"].iloc[0]) if hasattr(row["High"], 'iloc') else float(row["High"]),
                float(row["Low"].iloc[0])  if hasattr(row["Low"],  'iloc') else float(row["Low"]),
                float(row["Close"].iloc[0]) if hasattr(row["Close"], 'iloc') else float(row["Close"]),
                float(row["Close"].iloc[0]) if hasattr(row["Close"], 'iloc') else float(row["Close"]),
                int(row["Volume"].iloc[0])  if hasattr(row["Volume"], 'iloc') else int(row["Volume"])
            ))

        cursor.executemany(insert_sql, rows)
        total_rows += len(rows)
        print(f"  ✅ {ticker} — {len(rows)} days loaded")

    except Exception as e:
        print(f"  ⚠️  Error for {ticker}: {e}")

conn.commit()
cursor.close()
conn.close()

print(f"\n✅ Done! {total_rows:,} price rows inserted into Snowflake")
with source as (
    select * from SENTIMENT_DB.RAW.STOCK_PRICES
),

cleaned as (
    select
        ticker,
        price_date,
        open,
        high,
        low,
        close,
        adj_close,
        volume,
        ingested_at,

        -- daily price change
        close - open as daily_change,

        -- daily return as percentage
        round((close - open) / nullif(open, 0) * 100, 4) as daily_return_pct,

        -- price range for the day
        high - low as daily_range,

        -- flag unusual volume (will compare against average later)
        volume as raw_volume,

        -- date parts for joining with reddit data
        date_trunc('day', price_date)   as trade_date,
        date_trunc('month', price_date) as trade_month,
        year(price_date)                as trade_year

    from source
    where ticker is not null
      and price_date is not null
      and close > 0
)

select * from cleaned
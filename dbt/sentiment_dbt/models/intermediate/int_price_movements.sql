with prices as (
    select * from {{ ref('stg_stock_prices') }}
),

-- calculate forward returns after each date
-- this tells us what happened to the price 1, 3, 5, 10 days later
forward_returns as (
    select
        ticker,
        price_date,
        trade_date,
        trade_month,
        trade_year,
        open,
        close,
        volume,
        daily_return_pct,
        daily_change,
        daily_range,

        -- 1 day forward return
        lead(close, 1) over (
            partition by ticker order by price_date
        ) as close_1d_later,

        -- 3 day forward return
        lead(close, 3) over (
            partition by ticker order by price_date
        ) as close_3d_later,

        -- 5 day forward return
        lead(close, 5) over (
            partition by ticker order by price_date
        ) as close_5d_later,

        -- 10 day forward return
        lead(close, 10) over (
            partition by ticker order by price_date
        ) as close_10d_later

    from prices
),

-- calculate the actual return percentages
returns_pct as (
    select
        ticker,
        price_date,
        trade_date,
        trade_month,
        trade_year,
        open,
        close,
        volume,
        daily_return_pct,
        daily_range,

        -- forward return percentages
        round((close_1d_later  - close) / nullif(close, 0) * 100, 4) as return_1d_pct,
        round((close_3d_later  - close) / nullif(close, 0) * 100, 4) as return_3d_pct,
        round((close_5d_later  - close) / nullif(close, 0) * 100, 4) as return_5d_pct,
        round((close_10d_later - close) / nullif(close, 0) * 100, 4) as return_10d_pct,

        -- flag big moves
        case when abs(daily_return_pct) >= 5  then true else false end as is_big_move,
        case when abs(daily_return_pct) >= 10 then true else false end as is_huge_move

    from forward_returns
)

select * from returns_pct
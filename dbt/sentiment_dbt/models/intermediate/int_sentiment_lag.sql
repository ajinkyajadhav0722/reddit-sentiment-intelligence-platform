with mentions as (
    select * from {{ ref('int_ticker_mentions') }}
),

prices as (
    select * from {{ ref('int_price_movements') }}
),

-- join reddit mentions with price movements on same date
joined as (
    select
        m.ticker,
        m.post_date,
        m.post_month,
        m.post_year,
        m.mention_count,
        m.total_score,
        m.avg_score,
        m.total_comments,
        m.high_engagement_posts,
        m.mentions_per_hour,

        -- price data on the same day
        p.open,
        p.close,
        p.volume,
        p.daily_return_pct,
        p.daily_range,

        -- forward returns after the reddit mention spike
        p.return_1d_pct,
        p.return_3d_pct,
        p.return_5d_pct,
        p.return_10d_pct,
        p.is_big_move,
        p.is_huge_move,

        -- mention spike flag — more than 10x average mentions
        case
            when m.mention_count >= 10 then true
            else false
        end as is_mention_spike,

        -- sentiment divergence flag
        -- reddit is buzzing but price is falling
        case
            when m.mention_count >= 10 
             and p.daily_return_pct < -2 then 'BULLISH_DIVERGENCE'
            -- reddit is quiet but price is rising
            when m.mention_count < 5
             and p.daily_return_pct > 5  then 'BEARISH_DIVERGENCE'
            else 'NORMAL'
        end as divergence_signal

    from mentions m
    left join prices p
        on m.ticker    = p.ticker
        and m.post_date = p.price_date
)

select * from joined
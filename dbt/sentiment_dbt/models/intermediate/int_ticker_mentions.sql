with posts as (
    select * from {{ ref('stg_reddit_posts') }}
),

-- split the tickers_mentioned text into individual rows
ticker_posts as (
    select
        post_id,
        subreddit,
        post_date,
        post_month,
        post_year,
        score,
        num_comments,
        has_ticker,
        is_high_engagement,
        -- parse the JSON array of tickers
        f.value::string as ticker
    from posts,
        lateral flatten(input => try_parse_json(tickers_mentioned)) f
    where has_ticker = true
),

-- aggregate by ticker per day
daily_mentions as (
    select
        ticker,
        post_date,
        post_month,
        post_year,
        count(*)                                    as mention_count,
        sum(score)                                  as total_score,
        avg(score)                                  as avg_score,
        sum(num_comments)                           as total_comments,
        sum(case when is_high_engagement then 1 else 0 end) as high_engagement_posts,

        -- mention velocity: mentions in last 6 hours vs daily average
        count(*) / nullif(24, 0)                   as mentions_per_hour

    from ticker_posts
    group by ticker, post_date, post_month, post_year
)

select * from daily_mentions
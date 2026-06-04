with source as (
    select * from SENTIMENT_DB.RAW.REDDIT_POSTS
),

cleaned as (
    select
        post_id,
        subreddit,
        title,
        body,
        author,
        score,
        num_comments,
        created_utc,
        tickers_mentioned,
        ingested_at,

        -- clean up author name
        case 
            when author = '[deleted]' then null
            when author = 'AutoModerator' then null
            else author
        end as clean_author,

        -- extract year and month for easy filtering later
        date_trunc('day', created_utc)   as post_date,
        date_trunc('month', created_utc) as post_month,
        year(created_utc)                as post_year,

        -- flag posts with ticker mentions
        case 
            when tickers_mentioned = '[]' then false
            else true
        end as has_ticker,

        -- post length as a signal of quality
        length(title) as title_length,

        -- high engagement flag
        case
            when score >= 1000 then true
            else false
        end as is_high_engagement

    from source
    where post_id is not null
      and title is not null
    qualify row_number() over (partition by post_id order by ingested_at desc) = 1
)

select * from cleaned
with base as (
    select * from {{ ref('int_sentiment_lag') }}
),

-- calculate rolling averages to detect anomalies
rolling as (
    select
        ticker,
        post_date,
        mention_count,
        total_score,
        volume,
        daily_return_pct,
        return_3d_pct,
        divergence_signal,
        is_mention_spike,

        -- 7 day rolling average mentions
        avg(mention_count) over (
            partition by ticker
            order by post_date
            rows between 6 preceding and current row
        ) as avg_mentions_7d,

        -- 7 day rolling average score
        avg(total_score) over (
            partition by ticker
            order by post_date
            rows between 6 preceding and current row
        ) as avg_score_7d,

        -- 7 day rolling average volume
        avg(volume) over (
            partition by ticker
            order by post_date
            rows between 6 preceding and current row
        ) as avg_volume_7d

    from base
    where ticker is not null
),

anomalies as (
    select
        ticker,
        post_date,
        mention_count,
        total_score,
        volume,
        daily_return_pct,
        return_3d_pct,
        divergence_signal,
        is_mention_spike,
        avg_mentions_7d,
        avg_score_7d,
        avg_volume_7d,

        -- mention anomaly score
        round(
            mention_count / nullif(avg_mentions_7d, 0)
        , 2) as mention_anomaly_score,

        -- volume anomaly score
        round(
            volume / nullif(avg_volume_7d, 0)
        , 2) as volume_anomaly_score,

        -- combined anomaly flag
        case
            when mention_count / nullif(avg_mentions_7d, 0) >= 3
             and volume / nullif(avg_volume_7d, 0) >= 2
            then 'HIGH_ANOMALY'
            when mention_count / nullif(avg_mentions_7d, 0) >= 2
            then 'MEDIUM_ANOMALY'
            else 'NORMAL'
        end as anomaly_level,

        -- did this anomaly predict a price move?
        case
            when mention_count / nullif(avg_mentions_7d, 0) >= 3
             and abs(return_3d_pct) >= 5
            then true
            else false
        end as anomaly_was_predictive

    from rolling
)

select * from anomalies
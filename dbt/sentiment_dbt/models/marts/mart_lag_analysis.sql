with base as (
    select * from {{ ref('int_sentiment_lag') }}
),

lag_analysis as (
    select
        ticker,
        post_date,
        post_month,
        post_year,

        -- mention metrics
        mention_count,
        total_score,
        avg_score,
        total_comments,
        high_engagement_posts,
        mentions_per_hour,
        is_mention_spike,

        -- price on mention day
        open,
        close,
        volume,
        daily_return_pct,

        -- forward returns
        return_1d_pct,
        return_3d_pct,
        return_5d_pct,
        return_10d_pct,
        is_big_move,
        is_huge_move,

        -- divergence signal
        divergence_signal,

        -- which forward return was strongest
        case
            when abs(return_1d_pct)  = greatest(
                abs(return_1d_pct),
                abs(return_3d_pct),
                abs(return_5d_pct),
                abs(return_10d_pct)
            ) then '1 day'
            when abs(return_3d_pct)  = greatest(
                abs(return_1d_pct),
                abs(return_3d_pct),
                abs(return_5d_pct),
                abs(return_10d_pct)
            ) then '3 days'
            when abs(return_5d_pct)  = greatest(
                abs(return_1d_pct),
                abs(return_3d_pct),
                abs(return_5d_pct),
                abs(return_10d_pct)
            ) then '5 days'
            else '10 days'
        end as strongest_return_horizon,

        -- score the predictive power
        -- did a mention spike predict a price move?
        case
            when is_mention_spike = true
             and abs(return_3d_pct) >= 5 then 'PREDICTIVE'
            when is_mention_spike = true
             and abs(return_3d_pct) < 5  then 'NOT_PREDICTIVE'
            else 'NO_SPIKE'
        end as spike_prediction_result

    from base
)

select * from lag_analysis
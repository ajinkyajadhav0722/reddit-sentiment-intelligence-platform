with base as (
    select * from {{ ref('int_sentiment_lag') }}
),

scorecard as (
    select
        ticker,

        -- mention stats
        sum(mention_count)                              as total_mentions,
        avg(mention_count)                              as avg_daily_mentions,
        max(mention_count)                              as peak_daily_mentions,
        sum(case when is_mention_spike then 1 else 0 end) as total_spikes,

        -- engagement stats
        avg(avg_score)                                  as avg_post_score,
        sum(total_comments)                             as total_comments,
        sum(high_engagement_posts)                      as total_high_engagement_posts,

        -- price stats
        avg(daily_return_pct)                           as avg_daily_return_pct,
        max(daily_return_pct)                           as best_day_return_pct,
        min(daily_return_pct)                           as worst_day_return_pct,
        sum(case when is_big_move  then 1 else 0 end)   as total_big_moves,
        sum(case when is_huge_move then 1 else 0 end)   as total_huge_moves,

        -- lag analysis
        avg(return_1d_pct)                              as avg_return_1d_after_mention,
        avg(return_3d_pct)                              as avg_return_3d_after_mention,
        avg(return_5d_pct)                              as avg_return_5d_after_mention,
        avg(return_10d_pct)                             as avg_return_10d_after_mention,

        -- predictive accuracy
        sum(case when spike_prediction_result = 'PREDICTIVE'     then 1 else 0 end) as predictive_spikes,
        sum(case when spike_prediction_result = 'NOT_PREDICTIVE' then 1 else 0 end) as non_predictive_spikes,
        round(
            sum(case when spike_prediction_result = 'PREDICTIVE' then 1 else 0 end)
            / nullif(sum(case when is_mention_spike then 1 else 0 end), 0) * 100
        , 2)                                                                         as spike_accuracy_pct,

        -- divergence counts
        sum(case when divergence_signal = 'BULLISH_DIVERGENCE' then 1 else 0 end)   as bullish_divergences,
        sum(case when divergence_signal = 'BEARISH_DIVERGENCE' then 1 else 0 end)   as bearish_divergences

    from {{ ref('mart_lag_analysis') }}
    group by ticker
)

select * from scorecard
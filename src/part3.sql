-- @block
-- @conn school21
-- Write a function that returns the TransferredPoints table in a more
-- human-readable form
CREATE OR REPLACE FUNCTION fnc_transferred_points() RETURNS TABLE(
        peer1 VARCHAR,
        peer2 VARCHAR,
        points_amount INTEGER
    ) AS $$ WITH transfer_sum AS (
        SELECT checking_peer,
            checked_peer,
            SUM(points_amount) AS points_amount,
            -- min ID (to recognize the first appearance of a pair later)
            MIN(id) AS id,
            -- peers pairs (peer1-peer2 and peer2-peer1 will always have
            -- peer1-peer2 pair)
            CONCAT(
                LEAST(checking_peer, checked_peer),
                '_',
                GREATEST(checking_peer, checked_peer)
            ) AS pair
        FROM transferred_points
        GROUP BY checking_peer,
            checked_peer
    )
SELECT t1.checking_peer,
    t1.checked_peer,
    t1.points_amount - COALESCE(t2.points_amount, 0) AS points_amounts
FROM transfer_sum AS t1
    INNER JOIN (
        -- to remove the duplicates of forward and backward transfers
        SELECT pair,
            MIN(id) AS min_id
        FROM transfer_sum
        GROUP BY pair
    ) AS first_pair ON t1.pair = first_pair.pair
    AND t1.id = first_pair.min_id
    LEFT JOIN transfer_sum AS t2 -- to subtract the amount of a backward transfer
    ON t1.checking_peer = t2.checked_peer
    AND t1.checked_peer = t2.checking_peer
    AND t1.checked_peer = t2.checking_peer;

$$ LANGUAGE SQL;

-- @block
-- @conn school21
-- Write a function that returns a table of the following form: user name, name
-- of the checked task, number of XP received
CREATE OR REPLACE FUNCTION fnc_checked_tasks_xp() RETURNS TABLE(
        peer1 VARCHAR,
        task VARCHAR,
        XP INTEGER
    ) AS $$
SELECT checks.peer AS peer,
    SPLIT_PART(checks.task, '_', 1) AS task,
    xp.xp_amount AS XP
FROM xp
    JOIN checks ON xp."check" = checks.id
ORDER BY peer,
    task;

$$ LANGUAGE SQL;
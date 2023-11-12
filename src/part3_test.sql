-- @block
-- @conn school21
-- @label fnc_transferred_points
-- 3.1 Write a function that returns the TransferredPoints table in a more
-- human-readable form
SELECT *
FROM fnc_transferred_points();

-- @block
-- @conn school21
-- @label fnc_checked_tasks_xp
-- 3.2 Write a function that returns a table of the following form: user name,
-- name of the checked task, number of XP received
SELECT *
FROM fnc_checked_tasks_xp();

-- @block
-- @conn school21
-- @label fnc_peers_all_day_in_campus
-- 3.3 Write a function that finds the peers who have not left campus for the
-- whole day
SELECT *
FROM fnc_peers_all_day_in_campus ('2022-10-30');

-- @block
-- @conn school21
-- @label fnc_points_change
-- 3.4 Calculate the change in the number of peer points of each peer using the
-- TransferredPoints table
SELECT *
FROM fnc_points_change();

-- @block
-- @conn school21
-- @label fnc_points_change2
-- 3.5 Calculate the change in the number of peer points of each peer using the
-- table returned by the first function
SELECT *
FROM fnc_points_change2();

-- @block
-- @conn school21
-- @label fnc_most_frequently_checked_tasks
-- 3.6 Find the most frequently checked task for each day
SELECT *
FROM fnc_most_frequently_checked_tasks();

-- @block
-- @conn school21
-- @label prd_completed_blocks
-- 3.7 Find all peers who have completed the whole given block of tasks and the
-- completion date of the last task
BEGIN;

CALL prd_completed_blocks('C', 'prd_completed_blocks_cursor');

FETCH ALL IN "prd_completed_blocks_cursor";

END;

-- @block
-- @conn school21
-- @label fnc_recommended_peer
-- 3.8 Determine which peer each student should go to for a check
SELECT *
FROM fnc_recommended_peer();

-- @block
-- @conn school21
-- @label prd_percentage_peers_blocks
-- 3.9 Determine the percentage of peers who:
--     Started only block 1
--     Started only block 2
--     Started both
--     Have not started any of them
BEGIN;

CALL prd_percentage_peers_blocks('C', 'DO', 'prd_percentage_peers_blocks_cursor');

FETCH ALL IN "prd_percentage_peers_blocks_cursor";

END;

-- @block
-- @conn school21
-- @label fnc_checks_on_bday
-- 3.10 Determine the percentage of peers who have ever successfully passed a
-- check on their birthday
SELECT *
FROM fnc_checks_on_bday();

-- @block
-- @conn school21
-- @label prd_peers_task1_task2_not_task3
-- 3.11 Determine all peers who did the given tasks 1 and 2, but did not do task 3
BEGIN;

CALL prd_peers_task1_task2_not_task3(
    'C5_s21_decimal',
    'C4_s21_math',
    'DO1_Linux',
    'prd_peers_task1_task2_not_task3_cursor'
);

FETCH ALL IN "prd_peers_task1_task2_not_task3_cursor";

END;

-- @block
-- @conn school21
-- @label fnc_preceding_tasks
-- 3.12 Using recursive common table expression, output the number of preceding
-- tasks for each task
SELECT *
FROM fnc_preceding_tasks();

-- @block
-- @conn school21
-- @label prd_lucky_days
-- 3.13 Find "lucky" days for checks. A day is considered "lucky" if it has at
-- least N consecutive successful checks
BEGIN;

CALL prd_lucky_days(4, 'prd_lucky_days_cursor');

FETCH ALL IN "prd_lucky_days_cursor";

END;

-- @block
-- @conn school21
-- @label fnc_highest_xp
-- 3.14 Find the peer with the highest amount of XP
SELECT *
FROM fnc_highest_xp();

-- @block
-- @conn school21
-- @label prd_peers_arrival
-- 3.15 Determine the peers that came before the given time at least N times
-- during the whole time
BEGIN;

CALL prd_peers_arrival('04:00:00', 2, 'prd_peers_arrival_cursor');

FETCH ALL IN "prd_peers_arrival_cursor";

END;

-- @block
-- @conn school21
-- @label prd_peers_leave
--3.16 Determine the peers who left the campus more than M times during the last
--N days
BEGIN;

CALL prd_peers_leave(4, 1, 'prd_peers_leave_cursor');

FETCH ALL IN "prd_peers_leave_cursor";

END;

-- @block
-- @conn school21
-- @label fnc_percentage_of_early_entries
-- 3.17 Determine for each month the percentage of early entries
SELECT *
FROM fnc_percentage_of_early_entries();
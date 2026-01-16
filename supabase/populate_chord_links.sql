-- Populate Ultimate Guitar chord links for songs
-- Run this after migrations 005 and 006

-- GUITAR SONGS

-- Three Little Birds - Bob Marley (Guitar Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/bob-marley/three-little-birds-chords-166605'
WHERE title = 'Three Little Birds' AND artist = 'Bob Marley';

-- Horse With No Name - America (Guitar Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/america/a-horse-with-no-name-chords-59609'
WHERE title = 'Horse With No Name' AND artist = 'America';

-- Knockin' on Heaven's Door - Bob Dylan (Guitar Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/bob-dylan/knockin-on-heavens-door-chords-66559'
WHERE title = 'Knockin'' on Heaven''s Door' AND artist = 'Bob Dylan';

-- Bad Moon Rising - Creedence Clearwater Revival (Guitar Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/creedence-clearwater-revival/bad-moon-rising-chords-48327'
WHERE title = 'Bad Moon Rising' AND artist = 'Creedence Clearwater Revival';

-- Love Me Do - The Beatles (Guitar Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/the-beatles/love-me-do-chords-67652'
WHERE title = 'Love Me Do' AND artist = 'The Beatles';

-- Wonderwall - Oasis (Guitar Level 2)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/oasis/wonderwall-chords-27596'
WHERE title = 'Wonderwall' AND artist = 'Oasis';

-- Riptide - Vance Joy (Guitar Level 2)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/vance-joy/riptide-chords-1237247'
WHERE title = 'Riptide' AND artist = 'Vance Joy';

-- Brown Eyed Girl - Van Morrison (Guitar Level 2)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/van-morrison/brown-eyed-girl-chords-46671'
WHERE title = 'Brown Eyed Girl' AND artist = 'Van Morrison';

-- Dust in the Wind - Kansas (Guitar Level 3)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/kansas/dust-in-the-wind-chords-64282'
WHERE title = 'Dust in the Wind' AND artist = 'Kansas';

-- Blackbird - The Beatles (Guitar Level 3)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/the-beatles/blackbird-chords-62029'
WHERE title = 'Blackbird' AND artist = 'The Beatles';

-- Landslide - Fleetwood Mac (Guitar Level 3)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/fleetwood-mac/landslide-chords-61823'
WHERE title = 'Landslide' AND artist = 'Fleetwood Mac';

-- More Than Words - Extreme (Guitar Level 3)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/extreme/more-than-words-chords-60334'
WHERE title = 'More Than Words' AND artist = 'Extreme';

-- BASS GUITAR SONGS

-- Seven Nation Army - The White Stripes (Bass Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/the-white-stripes/seven-nation-army-bass-50374'
WHERE title = 'Seven Nation Army' AND artist = 'The White Stripes'
AND instrument_id = (SELECT id FROM instruments WHERE name = 'Bass Guitar');

-- Come As You Are - Nirvana (Bass Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/nirvana/come-as-you-are-bass-52125'
WHERE title = 'Come As You Are' AND artist = 'Nirvana';

-- Another One Bites the Dust - Queen (Bass Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/queen/another-one-bites-the-dust-bass-48834'
WHERE title = 'Another One Bites the Dust' AND artist = 'Queen';

-- DRUMS SONGS

-- We Will Rock You - Queen (Drums Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/queen/we-will-rock-you-drum-129438'
WHERE title = 'We Will Rock You' AND artist = 'Queen';

-- Highway to Hell - AC/DC (Drums Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/ac-dc/highway-to-hell-drum-157438'
WHERE title = 'Highway to Hell' AND artist = 'AC/DC';

-- Back in Black - AC/DC (Drums Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/ac-dc/back-in-black-drum-125641'
WHERE title = 'Back in Black' AND artist = 'AC/DC';

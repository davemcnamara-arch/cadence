-- Update songs with Ultimate Guitar chord links and YouTube tutorial links
-- Run this after running the 005_add_song_resources.sql migration

-- GUITAR SONGS

-- Three Little Birds - Bob Marley (Guitar Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/bob-marley/three-little-birds-chords-166605',
    tutorial_url = 'https://goodguitarist.com/youtube-post/three-little-birds-guitar-tutorial-bob-marley/'
WHERE title = 'Three Little Birds' AND artist = 'Bob Marley';

-- Horse With No Name - America (Guitar Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/america/a-horse-with-no-name-chords-59609',
    tutorial_url = 'https://goodguitarist.com/youtube-post/horse-with-no-name-guitar-tutorial-america/'
WHERE title = 'Horse With No Name' AND artist = 'America';

-- Knockin' on Heaven's Door - Bob Dylan (Guitar Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/bob-dylan/knockin-on-heavens-door-chords-66559',
    tutorial_url = 'https://goodguitarist.com/youtube-post/knockin-on-heavens-door-guitar-tutorial-bob-dylan/'
WHERE title = 'Knockin'' on Heaven''s Door' AND artist = 'Bob Dylan';

-- Wonderwall - Oasis (Guitar Level 2)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/oasis/wonderwall-chords-27596',
    tutorial_url = 'https://goodguitarist.com/youtube-post/wonderwall-guitar-tutorial-oasis-2/'
WHERE title = 'Wonderwall' AND artist = 'Oasis';

-- Riptide - Vance Joy (Guitar Level 2)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/vance-joy/riptide-chords-1237247',
    tutorial_url = 'https://www.justinguitar.com/songs/vance-joy-riptide-chords-tabs-guitar-lesson-bs-208'
WHERE title = 'Riptide' AND artist = 'Vance Joy';

-- Blackbird - The Beatles (Guitar Level 3)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/the-beatles/blackbird-chords-62029',
    tutorial_url = 'https://sixstringfingerpicking.com/songs/blackbird/'
WHERE title = 'Blackbird' AND artist = 'The Beatles';

-- BASS GUITAR SONGS

-- Seven Nation Army - The White Stripes (Bass Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/the-white-stripes/seven-nation-army-bass-50374',
    tutorial_url = 'https://www.youtube.com/watch?v=A7eQW6nwTKE'
WHERE title = 'Seven Nation Army' AND artist = 'The White Stripes'
AND instrument_id = (SELECT id FROM instruments WHERE name = 'Bass Guitar');

-- Come As You Are - Nirvana (Bass Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/nirvana/come-as-you-are-bass-52125',
    tutorial_url = 'https://www.youtube.com/watch?v=iZqS_UQYQX4'
WHERE title = 'Come As You Are' AND artist = 'Nirvana';

-- Another One Bites the Dust - Queen (Bass Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/queen/another-one-bites-the-dust-bass-48834',
    tutorial_url = 'https://www.youtube.com/watch?v=ZaQJsKuOqJk'
WHERE title = 'Another One Bites the Dust' AND artist = 'Queen';

-- PIANO/KEYBOARD SONGS

-- Imagine - John Lennon (Piano Level 1)
UPDATE songs
SET chords_url = 'https://www.pianote.com/chords/imagine-john-lennon/',
    tutorial_url = 'https://www.pianote.com/blog/how-to-play-imagine-on-piano/'
WHERE title = 'Imagine' AND artist = 'John Lennon';

-- Lean on Me - Bill Withers (Piano Level 1)
UPDATE songs
SET chords_url = 'https://www.musicnotes.com/sheetmusic/mtd.asp?ppn=MN0086289',
    tutorial_url = 'https://www.hdpiano.com/song/lean-on-me'
WHERE title = 'Lean on Me' AND artist = 'Bill Withers';

-- Clocks - Coldplay (Piano Level 2)
UPDATE songs
SET chords_url = 'https://www.musicnotes.com/sheetmusic/mtd.asp?ppn=MN0046783',
    tutorial_url = 'https://www.youtube.com/watch?v=1eMn2FMRgAw'
WHERE title = 'Clocks' AND artist = 'Coldplay';

-- DRUMS SONGS

-- We Will Rock You - Queen (Drums Level 1)
UPDATE songs
SET chords_url = 'https://www.songsterr.com/a/wsa/queen-we-will-rock-you-drum-tab-s4962',
    tutorial_url = 'https://www.youtube.com/watch?v=DX5aYzTR9wY'
WHERE title = 'We Will Rock You' AND artist = 'Queen';

-- Highway to Hell - AC/DC (Drums Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/ac-dc/highway-to-hell-drum-157438',
    tutorial_url = 'https://www.youtube.com/watch?v=SQsP0mhRWnA'
WHERE title = 'Highway to Hell' AND artist = 'AC/DC';

-- Back in Black - AC/DC (Drums Level 1)
UPDATE songs
SET chords_url = 'https://tabs.ultimate-guitar.com/tab/ac-dc/back-in-black-drum-125641',
    tutorial_url = 'https://www.youtube.com/watch?v=8F7Y8OrJqRI'
WHERE title = 'Back in Black' AND artist = 'AC/DC';

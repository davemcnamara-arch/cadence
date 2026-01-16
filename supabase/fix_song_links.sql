-- Fix songs to link them to instruments and levels
-- Run this if songs were inserted but instrument_id is NULL

DO $$
DECLARE
  guitar_id UUID;
  bass_id UUID;
  piano_id UUID;
  drums_id UUID;
  vocals_id UUID;
BEGIN
  SELECT id INTO guitar_id FROM instruments WHERE name = 'Guitar';
  SELECT id INTO bass_id FROM instruments WHERE name = 'Bass Guitar';
  SELECT id INTO piano_id FROM instruments WHERE name = 'Piano/Keyboard';
  SELECT id INTO drums_id FROM instruments WHERE name = 'Drums';
  SELECT id INTO vocals_id FROM instruments WHERE name = 'Vocals';

  -- Update Guitar songs
  UPDATE songs SET instrument_id = guitar_id, suggested_level = 1
  WHERE title IN ('Three Little Birds', 'Horse With No Name', 'Knockin'' on Heaven''s Door', 'Bad Moon Rising', 'Love Me Do');

  UPDATE songs SET instrument_id = guitar_id, suggested_level = 2
  WHERE title IN ('Wonderwall', 'Riptide', 'Brown Eyed Girl') AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = guitar_id, suggested_level = 2
  WHERE title = 'Let It Be' AND artist = 'The Beatles' AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = guitar_id, suggested_level = 2
  WHERE title = 'Stand By Me' AND artist = 'Ben E. King' AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = guitar_id, suggested_level = 3
  WHERE title IN ('Dust in the Wind', 'Blackbird', 'Landslide', 'More Than Words') AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = guitar_id, suggested_level = 3
  WHERE title = 'The Scientist' AND artist = 'Coldplay' AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = guitar_id, suggested_level = 4
  WHERE title IN ('Get Lucky', 'Superstition', 'Isn''t She Lovely', 'Tears in Heaven', 'Classical Gas', 'Wish You Were Here', 'Johnny B. Goode', 'Pride and Joy', 'Sweet Child O'' Mine') AND instrument_id IS NULL;

  -- Update Bass songs
  UPDATE songs SET instrument_id = bass_id, suggested_level = 1
  WHERE title IN ('Seven Nation Army', 'Come As You Are', 'Another One Bites the Dust', 'Feel Good Inc.') AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = bass_id, suggested_level = 2
  WHERE title IN ('Billie Jean', 'Money', 'Under Pressure') AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = bass_id, suggested_level = 2
  WHERE title = 'Stand By Me' AND artist = 'Ben E. King' AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = bass_id, suggested_level = 3
  WHERE title IN ('Good Times', 'Higher Ground', 'The Chicken') AND instrument_id IS NULL;

  -- Update Piano songs
  UPDATE songs SET instrument_id = piano_id, suggested_level = 1
  WHERE title IN ('Lean on Me', 'Imagine', 'Hey Jude') AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = piano_id, suggested_level = 1
  WHERE title = 'Let It Be' AND artist = 'The Beatles' AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = piano_id, suggested_level = 2
  WHERE title IN ('Clocks', 'Someone Like You', 'A Thousand Miles') AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = piano_id, suggested_level = 2
  WHERE title = 'The Scientist' AND artist = 'Coldplay' AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = piano_id, suggested_level = 3
  WHERE title IN ('River Flows in You', 'All of Me', 'Prelude in C Major', 'Comptine d''un autre été') AND instrument_id IS NULL;

  -- Update Drums songs
  UPDATE songs SET instrument_id = drums_id, suggested_level = 1
  WHERE title IN ('We Will Rock You', 'Highway to Hell', 'Back in Black') AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = drums_id, suggested_level = 1
  WHERE title = 'Billie Jean' AND artist = 'Michael Jackson' AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = drums_id, suggested_level = 2
  WHERE title IN ('Come Together', 'Sex on Fire', 'Mr. Brightside') AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = drums_id, suggested_level = 2
  WHERE title = 'Seven Nation Army' AND artist = 'The White Stripes' AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = drums_id, suggested_level = 3
  WHERE title IN ('Enter Sandman', 'Everlong', 'Good Times Bad Times') AND instrument_id IS NULL;

  -- Update Vocals songs
  UPDATE songs SET instrument_id = vocals_id, suggested_level = 1
  WHERE title IN ('Happy Birthday', 'You Are My Sunshine') AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = vocals_id, suggested_level = 1
  WHERE title = 'Let It Be' AND artist = 'The Beatles' AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = vocals_id, suggested_level = 1
  WHERE title = 'Stand By Me' AND artist = 'Ben E. King' AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = vocals_id, suggested_level = 2
  WHERE title IN ('Perfect', 'Thinking Out Loud', 'A Thousand Years') AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = vocals_id, suggested_level = 2
  WHERE title = 'Someone Like You' AND artist = 'Adele' AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = vocals_id, suggested_level = 3
  WHERE title IN ('All I Want', 'Hallelujah', 'At Last') AND instrument_id IS NULL;

  UPDATE songs SET instrument_id = vocals_id, suggested_level = 3
  WHERE title = 'Make You Feel My Love' AND artist = 'Adele' AND instrument_id IS NULL;

END $$;

-- Populate song library with at least one song for all instruments and levels
-- This ensures students have songs to learn across all level progressions
--
-- IMPORTANT: Run remove_duplicate_songs.sql first if you've previously run other song population scripts

-- ===== GUITAR LEVEL 5 SONGS =====

-- Guitar Level 5 songs (Advanced techniques)
-- Note: Superstition removed - already exists in clean_insert_songs.sql at Level 4

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Use Somebody', 'Kings of Leon', id, 5, 'https://www.youtube.com/watch?v=gnhXHvRoUd0', true
FROM instruments WHERE name = 'Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Neon', 'John Mayer', id, 5, 'https://www.youtube.com/watch?v=_DfQC5qHhbo', true
FROM instruments WHERE name = 'Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Little Wing', 'Jimi Hendrix', id, 5, 'https://www.youtube.com/watch?v=An4uDegHB8s', true
FROM instruments WHERE name = 'Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Sultans of Swing', 'Dire Straits', id, 5, 'https://www.youtube.com/watch?v=8Pa9x9fZBtY', true
FROM instruments WHERE name = 'Guitar'
ON CONFLICT DO NOTHING;

-- ===== BASS GUITAR LEVEL 4 & 5 SONGS =====

-- Bass Level 4 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Higher Ground', 'Red Hot Chili Peppers', id, 4, 'https://www.youtube.com/watch?v=6ADTPb2f0xE', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Forget Me Nots', 'Patrice Rushen', id, 4, 'https://www.youtube.com/watch?v=0hiUuL5uTKc', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Dear Prudence', 'The Beatles', id, 4, 'https://www.youtube.com/watch?v=wQA59IkCF8s', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Dani California', 'Red Hot Chili Peppers', id, 4, 'https://www.youtube.com/watch?v=Sb5aq5HcS1A', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Basket Case', 'Green Day', id, 4, 'https://www.youtube.com/watch?v=NUTGr5t3MoY', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

-- Bass Level 5 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Can''t Stop', 'Red Hot Chili Peppers', id, 5, 'https://www.youtube.com/watch?v=8DyziWtkfBw', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Tommy the Cat', 'Primus', id, 5, 'https://www.youtube.com/watch?v=r4OhIU-PmB8', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'So What', 'Miles Davis', id, 5, 'https://www.youtube.com/watch?v=ylXk1LBvIqU', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Schism', 'Tool', id, 5, 'https://www.youtube.com/watch?v=_yNAABKD4IA', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT '46 & 2', 'Tool', id, 5, 'https://www.youtube.com/watch?v=Tja6_h_Nbio', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

-- ===== PIANO/KEYBOARD LEVEL 4 & 5 SONGS =====

-- Piano Level 4 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Radioactive', 'Imagine Dragons', id, 4, 'https://www.youtube.com/watch?v=ktvTqknDobU', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Pompeii', 'Bastille', id, 4, 'https://www.youtube.com/watch?v=F90Cw4l-8NY', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'The A Team', 'Ed Sheeran', id, 4, 'https://www.youtube.com/watch?v=UAWcs5H-qgQ', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Say Something', 'A Great Big World', id, 4, 'https://www.youtube.com/watch?v=-2U0Ivkn2Ds', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Just the Two of Us', 'Bill Withers', id, 4, 'https://www.youtube.com/watch?v=v7gKGq_MYpU', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Ain''t No Sunshine', 'Bill Withers', id, 4, 'https://www.youtube.com/watch?v=tIdIqbv7SPo', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

-- Piano Level 5 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Comptine d''un autre été', 'Yann Tiersen', id, 5, 'https://www.youtube.com/watch?v=H2-1u8xvk54', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Mad World', 'Gary Jules', id, 5, 'https://www.youtube.com/watch?v=4N3N1MlvVc4', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Hallelujah', 'Leonard Cohen', id, 5, 'https://www.youtube.com/watch?v=ttEMYvpoR-k', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Fix You', 'Coldplay', id, 5, 'https://www.youtube.com/watch?v=k4V3Mo61fJM', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Autumn Leaves', 'Bill Evans', id, 5, 'https://www.youtube.com/watch?v=r-Z8KuwI7Gc', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Blue Bossa', 'Kenny Dorham', id, 5, 'https://www.youtube.com/watch?v=JCzkzWANssw', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

-- ===== DRUMS LEVEL 4 & 5 SONGS =====

-- Drums Level 4 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'In the Air Tonight', 'Phil Collins', id, 4, 'https://www.youtube.com/watch?v=YkADj0TPrJA', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'When the Levee Breaks', 'Led Zeppelin', id, 4, 'https://www.youtube.com/watch?v=fOEQTJV_3-w', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Cissy Strut', 'The Meters', id, 4, 'https://www.youtube.com/watch?v=4_iC0MyIykM', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Come Together', 'The Beatles', id, 4, 'https://www.youtube.com/watch?v=45cYwDMibGo', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Everlong', 'Foo Fighters', id, 4, 'https://www.youtube.com/watch?v=eBG7P-K-r1Y', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Basket Case', 'Green Day', id, 4, 'https://www.youtube.com/watch?v=NUTGr5t3MoY', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

-- Drums Level 5 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Tom Sawyer', 'Rush', id, 5, 'https://www.youtube.com/watch?v=auLBLk4ibAk', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Schism', 'Tool', id, 5, 'https://www.youtube.com/watch?v=_yNAABKD4IA', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Take Five', 'Dave Brubeck Quartet', id, 5, 'https://www.youtube.com/watch?v=vmDDOFXSgAs', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'My Favorite Things', 'John Coltrane', id, 5, 'https://www.youtube.com/watch?v=qWG2dsXV5HI', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Hot for Teacher', 'Van Halen', id, 5, 'https://www.youtube.com/watch?v=6M4_Ommfvv0', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'YYZ', 'Rush', id, 5, 'https://www.youtube.com/watch?v=LdpMpfp-J_I', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

-- ===== VOCALS LEVEL 4 & 5 SONGS =====

-- Vocals Level 4 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Rolling in the Deep', 'Adele', id, 4, 'https://www.youtube.com/watch?v=rYEDA3JcQqw', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Grenade', 'Bruno Mars', id, 4, 'https://www.youtube.com/watch?v=SR6iYWJxHqs', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'The A Team', 'Ed Sheeran', id, 4, 'https://www.youtube.com/watch?v=UAWcs5H-qgQ', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Skinny Love', 'Bon Iver', id, 4, 'https://www.youtube.com/watch?v=ssdgFoHLwnk', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Ain''t No Sunshine', 'Bill Withers', id, 4, 'https://www.youtube.com/watch?v=tIdIqbv7SPo', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Respect', 'Aretha Franklin', id, 4, 'https://www.youtube.com/watch?v=6FOUqQt3Kg0', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

-- Vocals Level 5 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'I Will Always Love You', 'Whitney Houston', id, 5, 'https://www.youtube.com/watch?v=3JWTaaS7LdU', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'And I Am Telling You', 'Jennifer Hudson', id, 5, 'https://www.youtube.com/watch?v=VODKZxsRa_E', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'The Blower''s Daughter', 'Damien Rice', id, 5, 'https://www.youtube.com/watch?v=5YXVMCHG-Nk', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Hurt', 'Johnny Cash', id, 5, 'https://www.youtube.com/watch?v=8AHCfZTRGiI', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'At Last', 'Etta James', id, 5, 'https://www.youtube.com/watch?v=S-cbOl96RFM', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Summertime', 'Ella Fitzgerald', id, 5, 'https://www.youtube.com/watch?v=MIDOEsQLRlU', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

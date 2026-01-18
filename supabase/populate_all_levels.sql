-- Populate song library with at least one song for all instruments and levels
-- This ensures students have songs to learn across all level progressions

-- ===== GUITAR LEVEL 5 SONGS =====

-- Guitar Level 5 songs (Advanced techniques)
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Superstition', 'Stevie Wonder', id, 5, 'https://www.youtube.com/watch?v=0CFuCYNx-1g', 'https://tabs.ultimateguitar.com/tab/stevie-wonder/superstition-chords-65436', true
FROM instruments WHERE name = 'Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Use Somebody', 'Kings of Leon', id, 5, 'https://www.youtube.com/watch?v=gnhXHvRoUd0', 'https://tabs.ultimateguitar.com/tab/kings-of-leon/use-somebody-chords-645739', true
FROM instruments WHERE name = 'Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Neon', 'John Mayer', id, 5, 'https://www.youtube.com/watch?v=_DfQC5qHhbo', 'https://tabs.ultimateguitar.com/tab/john-mayer/neon-chords-1059579', true
FROM instruments WHERE name = 'Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Little Wing', 'Jimi Hendrix', id, 5, 'https://www.youtube.com/watch?v=An4uDegHB8s', 'https://tabs.ultimateguitar.com/tab/jimi-hendrix/little-wing-chords-46540', true
FROM instruments WHERE name = 'Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Sultans of Swing', 'Dire Straits', id, 5, 'https://www.youtube.com/watch?v=8Pa9x9fZBtY', 'https://tabs.ultimateguitar.com/tab/dire-straits/sultans-of-swing-chords-26007', true
FROM instruments WHERE name = 'Guitar'
ON CONFLICT DO NOTHING;

-- ===== BASS GUITAR LEVEL 4 & 5 SONGS =====

-- Bass Level 4 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Higher Ground', 'Red Hot Chili Peppers', id, 4, 'https://www.youtube.com/watch?v=6ADTPb2f0xE', 'https://tabs.ultimateguitar.com/tab/red-hot-chili-peppers/higher-ground-bass-182371', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Forget Me Nots', 'Patrice Rushen', id, 4, 'https://www.youtube.com/watch?v=0hiUuL5uTKc', 'https://tabs.ultimateguitar.com/tab/patrice-rushen/forget-me-nots-bass-1588925', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Dear Prudence', 'The Beatles', id, 4, 'https://www.youtube.com/watch?v=wQA59IkCF8s', 'https://tabs.ultimateguitar.com/tab/the-beatles/dear-prudence-bass-1078064', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Dani California', 'Red Hot Chili Peppers', id, 4, 'https://www.youtube.com/watch?v=Sb5aq5HcS1A', 'https://tabs.ultimateguitar.com/tab/red-hot-chili-peppers/dani-california-bass-376752', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Basket Case', 'Green Day', id, 4, 'https://www.youtube.com/watch?v=NUTGr5t3MoY', 'https://tabs.ultimateguitar.com/tab/green-day/basket-case-bass-14892', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

-- Bass Level 5 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Can''t Stop', 'Red Hot Chili Peppers', id, 5, 'https://www.youtube.com/watch?v=8DyziWtkfBw', 'https://tabs.ultimateguitar.com/tab/red-hot-chili-peppers/cant-stop-bass-169296', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Tommy the Cat', 'Primus', id, 5, 'https://www.youtube.com/watch?v=r4OhIU-PmB8', 'https://tabs.ultimateguitar.com/tab/primus/tommy-the-cat-bass-104827', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'So What', 'Miles Davis', id, 5, 'https://www.youtube.com/watch?v=ylXk1LBvIqU', 'https://tabs.ultimateguitar.com/tab/miles-davis/so-what-bass-1242337', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Schism', 'Tool', id, 5, 'https://www.youtube.com/watch?v=_yNAABKD4IA', 'https://tabs.ultimateguitar.com/tab/tool/schism-bass-25946', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT '46 & 2', 'Tool', id, 5, 'https://www.youtube.com/watch?v=Tja6_h_Nbio', 'https://tabs.ultimateguitar.com/tab/tool/forty-six-2-bass-182374', true
FROM instruments WHERE name = 'Bass Guitar'
ON CONFLICT DO NOTHING;

-- ===== PIANO/KEYBOARD LEVEL 4 & 5 SONGS =====

-- Piano Level 4 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Radioactive', 'Imagine Dragons', id, 4, 'https://www.youtube.com/watch?v=ktvTqknDobU', 'https://tabs.ultimateguitar.com/tab/imagine-dragons/radioactive-chords-1173675', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Pompeii', 'Bastille', id, 4, 'https://www.youtube.com/watch?v=F90Cw4l-8NY', 'https://tabs.ultimateguitar.com/tab/bastille/pompeii-chords-1282917', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'The A Team', 'Ed Sheeran', id, 4, 'https://www.youtube.com/watch?v=UAWcs5H-qgQ', 'https://tabs.ultimateguitar.com/tab/ed-sheeran/the-a-team-chords-1038927', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Say Something', 'A Great Big World', id, 4, 'https://www.youtube.com/watch?v=-2U0Ivkn2Ds', 'https://tabs.ultimateguitar.com/tab/a-great-big-world/say-something-chords-1370177', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Just the Two of Us', 'Bill Withers', id, 4, 'https://www.youtube.com/watch?v=v7gKGq_MYpU', 'https://tabs.ultimateguitar.com/tab/bill-withers/just-the-two-of-us-chords-1214928', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Ain''t No Sunshine', 'Bill Withers', id, 4, 'https://www.youtube.com/watch?v=tIdIqbv7SPo', 'https://tabs.ultimateguitar.com/tab/bill-withers/aint-no-sunshine-chords-27562', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

-- Piano Level 5 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Comptine d''un autre été', 'Yann Tiersen', id, 5, 'https://www.youtube.com/watch?v=H2-1u8xvk54', 'https://tabs.ultimateguitar.com/tab/yann-tiersen/comptine-dun-autre-ete-lapres-midi-chords-1071653', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Mad World', 'Gary Jules', id, 5, 'https://www.youtube.com/watch?v=4N3N1MlvVc4', 'https://tabs.ultimateguitar.com/tab/gary-jules/mad-world-chords-303698', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Hallelujah', 'Leonard Cohen', id, 5, 'https://www.youtube.com/watch?v=ttEMYvpoR-k', 'https://tabs.ultimateguitar.com/tab/leonard-cohen/hallelujah-chords-71770', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Fix You', 'Coldplay', id, 5, 'https://www.youtube.com/watch?v=k4V3Mo61fJM', 'https://tabs.ultimateguitar.com/tab/coldplay/fix-you-chords-226682', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Autumn Leaves', 'Bill Evans', id, 5, 'https://www.youtube.com/watch?v=r-Z8KuwI7Gc', 'https://tabs.ultimateguitar.com/tab/bill-evans/autumn-leaves-chords-1923966', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Blue Bossa', 'Kenny Dorham', id, 5, 'https://www.youtube.com/watch?v=JCzkzWANssw', 'https://tabs.ultimateguitar.com/tab/kenny-dorham/blue-bossa-chords-1934732', true
FROM instruments WHERE name = 'Piano/Keyboard'
ON CONFLICT DO NOTHING;

-- ===== DRUMS LEVEL 4 & 5 SONGS =====

-- Drums Level 4 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'In the Air Tonight', 'Phil Collins', id, 4, 'https://www.youtube.com/watch?v=YkADj0TPrJA', 'https://tabs.ultimateguitar.com/tab/phil-collins/in-the-air-tonight-drums-1262086', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'When the Levee Breaks', 'Led Zeppelin', id, 4, 'https://www.youtube.com/watch?v=fOEQTJV_3-w', 'https://tabs.ultimateguitar.com/tab/led-zeppelin/when-the-levee-breaks-drums-1130604', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Cissy Strut', 'The Meters', id, 4, 'https://www.youtube.com/watch?v=4_iC0MyIykM', 'https://tabs.ultimateguitar.com/tab/the-meters/cissy-strut-drums-2009896', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Come Together', 'The Beatles', id, 4, 'https://www.youtube.com/watch?v=45cYwDMibGo', 'https://tabs.ultimateguitar.com/tab/the-beatles/come-together-drums-1262058', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Everlong', 'Foo Fighters', id, 4, 'https://www.youtube.com/watch?v=eBG7P-K-r1Y', 'https://tabs.ultimateguitar.com/tab/foo-fighters/everlong-drums-1165654', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Basket Case', 'Green Day', id, 4, 'https://www.youtube.com/watch?v=NUTGr5t3MoY', 'https://tabs.ultimateguitar.com/tab/green-day/basket-case-drums-1075506', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

-- Drums Level 5 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Tom Sawyer', 'Rush', id, 5, 'https://www.youtube.com/watch?v=auLBLk4ibAk', 'https://tabs.ultimateguitar.com/tab/rush/tom-sawyer-drums-873534', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Schism', 'Tool', id, 5, 'https://www.youtube.com/watch?v=_yNAABKD4IA', 'https://tabs.ultimateguitar.com/tab/tool/schism-drums-1202711', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Take Five', 'Dave Brubeck Quartet', id, 5, 'https://www.youtube.com/watch?v=vmDDOFXSgAs', 'https://tabs.ultimateguitar.com/tab/dave-brubeck/take-five-drums-2227773', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'My Favorite Things', 'John Coltrane', id, 5, 'https://www.youtube.com/watch?v=qWG2dsXV5HI', 'https://tabs.ultimateguitar.com/tab/john-coltrane/my-favorite-things-drums-1829377', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Hot for Teacher', 'Van Halen', id, 5, 'https://www.youtube.com/watch?v=6M4_Ommfvv0', 'https://tabs.ultimateguitar.com/tab/van-halen/hot-for-teacher-drums-1092934', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'YYZ', 'Rush', id, 5, 'https://www.youtube.com/watch?v=LdpMpfp-J_I', 'https://tabs.ultimateguitar.com/tab/rush/yyz-drums-1238671', true
FROM instruments WHERE name = 'Drums'
ON CONFLICT DO NOTHING;

-- ===== VOCALS LEVEL 4 & 5 SONGS =====

-- Vocals Level 4 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Rolling in the Deep', 'Adele', id, 4, 'https://www.youtube.com/watch?v=rYEDA3JcQqw', 'https://tabs.ultimateguitar.com/tab/adele/rolling-in-the-deep-chords-856039', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Grenade', 'Bruno Mars', id, 4, 'https://www.youtube.com/watch?v=SR6iYWJxHqs', 'https://tabs.ultimateguitar.com/tab/bruno-mars/grenade-chords-891558', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'The A Team', 'Ed Sheeran', id, 4, 'https://www.youtube.com/watch?v=UAWcs5H-qgQ', 'https://tabs.ultimateguitar.com/tab/ed-sheeran/the-a-team-chords-1038927', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Skinny Love', 'Bon Iver', id, 4, 'https://www.youtube.com/watch?v=ssdgFoHLwnk', 'https://tabs.ultimateguitar.com/tab/bon-iver/skinny-love-chords-711458', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Ain''t No Sunshine', 'Bill Withers', id, 4, 'https://www.youtube.com/watch?v=tIdIqbv7SPo', 'https://tabs.ultimateguitar.com/tab/bill-withers/aint-no-sunshine-chords-27562', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Respect', 'Aretha Franklin', id, 4, 'https://www.youtube.com/watch?v=6FOUqQt3Kg0', 'https://tabs.ultimateguitar.com/tab/aretha-franklin/respect-chords-89262', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

-- Vocals Level 5 songs
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'I Will Always Love You', 'Whitney Houston', id, 5, 'https://www.youtube.com/watch?v=3JWTaaS7LdU', 'https://tabs.ultimateguitar.com/tab/whitney-houston/i-will-always-love-you-chords-84621', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'And I Am Telling You', 'Jennifer Hudson', id, 5, 'https://www.youtube.com/watch?v=VODKZxsRa_E', 'https://tabs.ultimateguitar.com/tab/jennifer-hudson/and-i-am-telling-you-im-not-going-chords-815548', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'The Blower''s Daughter', 'Damien Rice', id, 5, 'https://www.youtube.com/watch?v=5YXVMCHG-Nk', 'https://tabs.ultimateguitar.com/tab/damien-rice/the-blowers-daughter-chords-182407', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Hurt', 'Johnny Cash', id, 5, 'https://www.youtube.com/watch?v=8AHCfZTRGiI', 'https://tabs.ultimateguitar.com/tab/johnny-cash/hurt-chords-120595', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'At Last', 'Etta James', id, 5, 'https://www.youtube.com/watch?v=S-cbOl96RFM', 'https://tabs.ultimateguitar.com/tab/etta-james/at-last-chords-1019012', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, chords_url, approved)
SELECT 'Summertime', 'Ella Fitzgerald', id, 5, 'https://www.youtube.com/watch?v=MIDOEsQLRlU', 'https://tabs.ultimateguitar.com/tab/ella-fitzgerald/summertime-chords-1730773', true
FROM instruments WHERE name = 'Vocals'
ON CONFLICT DO NOTHING;

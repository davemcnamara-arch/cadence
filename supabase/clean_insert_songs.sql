-- Delete existing songs and re-insert with proper links
-- This ensures clean data

DELETE FROM songs WHERE approved = true;

-- Guitar Level 1
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Three Little Birds', 'Bob Marley', id, 1, 'https://www.youtube.com/watch?v=zaGUr6wzyT8', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Horse With No Name', 'America', id, 1, 'https://www.youtube.com/watch?v=zSAJ0l4OBHM', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Knockin'' on Heaven''s Door', 'Bob Dylan', id, 1, 'https://www.youtube.com/watch?v=VLUqN3sWUkU', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Bad Moon Rising', 'Creedence Clearwater Revival', id, 1, 'https://www.youtube.com/watch?v=zUQiUFZ5RDw', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Love Me Do', 'The Beatles', id, 1, 'https://www.youtube.com/watch?v=0pGOFX1D_jg', true
FROM instruments WHERE name = 'Guitar';

-- Guitar Level 2
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Wonderwall', 'Oasis', id, 2, 'https://www.youtube.com/watch?v=bx1Bh8ZvH84', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Riptide', 'Vance Joy', id, 2, 'https://www.youtube.com/watch?v=uJ_1HMAGb4k', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Brown Eyed Girl', 'Van Morrison', id, 2, 'https://www.youtube.com/watch?v=UfmkgQRmmeE', true
FROM instruments WHERE name = 'Guitar';

-- Guitar Level 3
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Dust in the Wind', 'Kansas', id, 3, 'https://www.youtube.com/watch?v=tH2w6Oxx0kQ', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Blackbird', 'The Beatles', id, 3, 'https://www.youtube.com/watch?v=Man4t8kx8h8', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Landslide', 'Fleetwood Mac', id, 3, 'https://www.youtube.com/watch?v=WM7-PYtXtJM', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'More Than Words', 'Extreme', id, 3, 'https://www.youtube.com/watch?v=UrIiLvg58SY', true
FROM instruments WHERE name = 'Guitar';

-- Guitar Level 4
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Get Lucky', 'Daft Punk', id, 4, 'https://www.youtube.com/watch?v=5NV6Rdv1a3I', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Superstition', 'Stevie Wonder', id, 4, 'https://www.youtube.com/watch?v=0CFuCYNx-1g', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Isn''t She Lovely', 'Stevie Wonder', id, 4, 'https://www.youtube.com/watch?v=IVvkjuEAwgU', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Tears in Heaven', 'Eric Clapton', id, 4, 'https://www.youtube.com/watch?v=JxPj3GAYYZ0', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Classical Gas', 'Mason Williams', id, 4, 'https://www.youtube.com/watch?v=mREi_Bb85Sk', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Wish You Were Here', 'Pink Floyd', id, 4, 'https://www.youtube.com/watch?v=IXdNnw99-Ic', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Johnny B. Goode', 'Chuck Berry', id, 4, 'https://www.youtube.com/watch?v=ZFo8-JqzSCM', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Pride and Joy', 'Stevie Ray Vaughan', id, 4, 'https://www.youtube.com/watch?v=0vo23H9J8o8', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Sweet Child O'' Mine', 'Guns N'' Roses', id, 4, 'https://www.youtube.com/watch?v=1w7OgIMMRc4', true
FROM instruments WHERE name = 'Guitar';

-- Bass Level 1
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Seven Nation Army', 'The White Stripes', id, 1, 'https://www.youtube.com/watch?v=0J2QdDbelmY', true
FROM instruments WHERE name = 'Bass Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Come As You Are', 'Nirvana', id, 1, 'https://www.youtube.com/watch?v=vabnZ9-ex7o', true
FROM instruments WHERE name = 'Bass Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Another One Bites the Dust', 'Queen', id, 1, 'https://www.youtube.com/watch?v=rY0WxgSXdEE', true
FROM instruments WHERE name = 'Bass Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Feel Good Inc.', 'Gorillaz', id, 1, 'https://www.youtube.com/watch?v=HyHNuVaZJ-k', true
FROM instruments WHERE name = 'Bass Guitar';

-- Bass Level 2
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Billie Jean', 'Michael Jackson', id, 2, 'https://www.youtube.com/watch?v=Zi_XLOBDo_Y', true
FROM instruments WHERE name = 'Bass Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Money', 'Pink Floyd', id, 2, 'https://www.youtube.com/watch?v=-0kcet4aPpQ', true
FROM instruments WHERE name = 'Bass Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Under Pressure', 'Queen & David Bowie', id, 2, 'https://www.youtube.com/watch?v=a01QQZyl-_I', true
FROM instruments WHERE name = 'Bass Guitar';

-- Bass Level 3
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Good Times', 'Chic', id, 3, 'https://www.youtube.com/watch?v=Er9xGRolrT4', true
FROM instruments WHERE name = 'Bass Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Higher Ground', 'Red Hot Chili Peppers', id, 3, 'https://www.youtube.com/watch?v=sdOLFtk9joI', true
FROM instruments WHERE name = 'Bass Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'The Chicken', 'Jaco Pastorius', id, 3, 'https://www.youtube.com/watch?v=JW8UrTd6RGQ', true
FROM instruments WHERE name = 'Bass Guitar';

-- Piano Level 1
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Lean on Me', 'Bill Withers', id, 1, 'https://www.youtube.com/watch?v=fOZ-MySzAac', true
FROM instruments WHERE name = 'Piano/Keyboard';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Imagine', 'John Lennon', id, 1, 'https://www.youtube.com/watch?v=YkgkThdzX-8', true
FROM instruments WHERE name = 'Piano/Keyboard';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Hey Jude', 'The Beatles', id, 1, 'https://www.youtube.com/watch?v=A_MjCqQoLLA', true
FROM instruments WHERE name = 'Piano/Keyboard';

-- Piano Level 2
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Clocks', 'Coldplay', id, 2, 'https://www.youtube.com/watch?v=d020hcWA_Wg', true
FROM instruments WHERE name = 'Piano/Keyboard';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'A Thousand Miles', 'Vanessa Carlton', id, 2, 'https://www.youtube.com/watch?v=Cwkej79U3ek', true
FROM instruments WHERE name = 'Piano/Keyboard';

-- Piano Level 3
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'River Flows in You', 'Yiruma', id, 3, 'https://www.youtube.com/watch?v=7maJOI3QMu0', true
FROM instruments WHERE name = 'Piano/Keyboard';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'All of Me', 'John Legend', id, 3, 'https://www.youtube.com/watch?v=450p7goxZqg', true
FROM instruments WHERE name = 'Piano/Keyboard';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Prelude in C Major', 'J.S. Bach', id, 3, 'https://www.youtube.com/watch?v=PXMVkQ70I88', true
FROM instruments WHERE name = 'Piano/Keyboard';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Comptine d''un autre été', 'Yann Tiersen', id, 3, 'https://www.youtube.com/watch?v=H2-1u8xvk54', true
FROM instruments WHERE name = 'Piano/Keyboard';

-- Drums Level 1
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'We Will Rock You', 'Queen', id, 1, 'https://www.youtube.com/watch?v=-tJYN-eG1zk', true
FROM instruments WHERE name = 'Drums';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Highway to Hell', 'AC/DC', id, 1, 'https://www.youtube.com/watch?v=l482T0yNkeo', true
FROM instruments WHERE name = 'Drums';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Back in Black', 'AC/DC', id, 1, 'https://www.youtube.com/watch?v=pAgnJDJN4VA', true
FROM instruments WHERE name = 'Drums';

-- Drums Level 2
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Come Together', 'The Beatles', id, 2, 'https://www.youtube.com/watch?v=45cYwDMibGo', true
FROM instruments WHERE name = 'Drums';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Sex on Fire', 'Kings of Leon', id, 2, 'https://www.youtube.com/watch?v=RF0HhrwIwp0', true
FROM instruments WHERE name = 'Drums';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Mr. Brightside', 'The Killers', id, 2, 'https://www.youtube.com/watch?v=gGdGFtwCNBE', true
FROM instruments WHERE name = 'Drums';

-- Drums Level 3
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Enter Sandman', 'Metallica', id, 3, 'https://www.youtube.com/watch?v=CD-E-LDc384', true
FROM instruments WHERE name = 'Drums';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Everlong', 'Foo Fighters', id, 3, 'https://www.youtube.com/watch?v=eBG7P-K-r1Y', true
FROM instruments WHERE name = 'Drums';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Good Times Bad Times', 'Led Zeppelin', id, 3, 'https://www.youtube.com/watch?v=x8TkZeQkScw', true
FROM instruments WHERE name = 'Drums';

-- Vocals Level 1
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Happy Birthday', 'Traditional', id, 1, 'https://www.youtube.com/watch?v=inS9gAgSENE', true
FROM instruments WHERE name = 'Vocals';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'You Are My Sunshine', 'Traditional', id, 1, 'https://www.youtube.com/watch?v=cGa3zFRqDn4', true
FROM instruments WHERE name = 'Vocals';

-- Vocals Level 2
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Perfect', 'Ed Sheeran', id, 2, 'https://www.youtube.com/watch?v=2Vv-BfVoq4g', true
FROM instruments WHERE name = 'Vocals';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Thinking Out Loud', 'Ed Sheeran', id, 2, 'https://www.youtube.com/watch?v=lp-EO5I60KA', true
FROM instruments WHERE name = 'Vocals';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'A Thousand Years', 'Christina Perri', id, 2, 'https://www.youtube.com/watch?v=rtOvBOTyX00', true
FROM instruments WHERE name = 'Vocals';

-- Vocals Level 3
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'All I Want', 'Kodaline', id, 3, 'https://www.youtube.com/watch?v=mtf7hC17IBM', true
FROM instruments WHERE name = 'Vocals';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Hallelujah', 'Leonard Cohen', id, 3, 'https://www.youtube.com/watch?v=ttEMYvpoR-k', true
FROM instruments WHERE name = 'Vocals';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'At Last', 'Etta James', id, 3, 'https://www.youtube.com/watch?v=S-cbOl96RFM', true
FROM instruments WHERE name = 'Vocals';

-- Shared songs that appear on multiple instruments
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Let It Be', 'The Beatles', id, 1, 'https://www.youtube.com/watch?v=QDYfEBY9NM4', true
FROM instruments WHERE name IN ('Piano/Keyboard', 'Vocals');

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Stand By Me', 'Ben E. King', id, CASE WHEN name = 'Bass Guitar' THEN 2 WHEN name = 'Vocals' THEN 1 ELSE 2 END, 'https://www.youtube.com/watch?v=hwZNL7QVJjE', true
FROM instruments WHERE name IN ('Bass Guitar', 'Vocals');

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'The Scientist', 'Coldplay', id, CASE WHEN name = 'Piano/Keyboard' THEN 2 ELSE 3 END, 'https://www.youtube.com/watch?v=RB-RcX5DS5A', true
FROM instruments WHERE name IN ('Guitar', 'Piano/Keyboard');

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Someone Like You', 'Adele', id, 2, 'https://www.youtube.com/watch?v=hLQl3WQQoQ0', true
FROM instruments WHERE name IN ('Piano/Keyboard', 'Vocals');

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Make You Feel My Love', 'Adele', id, 3, 'https://www.youtube.com/watch?v=0put0_a--Ng', true
FROM instruments WHERE name = 'Vocals';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Billie Jean', 'Michael Jackson', id, CASE WHEN name = 'Drums' THEN 1 ELSE 2 END, 'https://www.youtube.com/watch?v=Zi_XLOBDo_Y', true
FROM instruments WHERE name IN ('Bass Guitar', 'Drums');

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, approved)
SELECT 'Seven Nation Army', 'The White Stripes', id, CASE WHEN name = 'Bass Guitar' THEN 1 ELSE 2 END, 'https://www.youtube.com/watch?v=0J2QdDbelmY', true
FROM instruments WHERE name IN ('Bass Guitar', 'Drums');

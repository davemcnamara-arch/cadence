-- Delete existing songs and re-insert with proper links
-- This ensures clean data

DELETE FROM songs WHERE approved = true;

-- Guitar Level 1
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Three Little Birds', 'Bob Marley', id, 1, 'https://www.youtube.com/watch?v=zaGUr6wzyT8', 'https://open.spotify.com/track/2Kx3Qhtl5gT1kNlBBnAIzc', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Horse With No Name', 'America', id, 1, 'https://www.youtube.com/watch?v=zSAJ0l4OBHM', 'https://open.spotify.com/track/3ZHhKKr4pT0gZAcJ3gKJsO', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Knockin'' on Heaven''s Door', 'Bob Dylan', id, 1, 'https://www.youtube.com/watch?v=VLUqN3sWUkU', 'https://open.spotify.com/track/3BNJHXp53Z2Rm0UWh1fWFw', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Bad Moon Rising', 'Creedence Clearwater Revival', id, 1, 'https://www.youtube.com/watch?v=zUQiUFZ5RDw', 'https://open.spotify.com/track/57bgtoPSgt236HzfBOd8kj', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Love Me Do', 'The Beatles', id, 1, 'https://www.youtube.com/watch?v=0pGOFX1D_jg', 'https://open.spotify.com/track/3jjsRKlGfKHTKq0Y9Y3Qq2', true
FROM instruments WHERE name = 'Guitar';

-- Guitar Level 2
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Wonderwall', 'Oasis', id, 2, 'https://www.youtube.com/watch?v=bx1Bh8ZvH84', 'https://open.spotify.com/track/1BxfuPKGuaTgP7aM0Bbdwr', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Riptide', 'Vance Joy', id, 2, 'https://www.youtube.com/watch?v=uJ_1HMAGb4k', 'https://open.spotify.com/track/5ELQATaGvEq4cqLxQsRY1t', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Brown Eyed Girl', 'Van Morrison', id, 2, 'https://www.youtube.com/watch?v=UfmkgQRmmeE', 'https://open.spotify.com/track/3yrSvt2jkB0subdivV5uXBh', true
FROM instruments WHERE name = 'Guitar';

-- Guitar Level 3
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Dust in the Wind', 'Kansas', id, 3, 'https://www.youtube.com/watch?v=tH2w6Oxx0kQ', 'https://open.spotify.com/track/0hResEBaM5K8Jp8dVw4nJJ', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Blackbird', 'The Beatles', id, 3, 'https://www.youtube.com/watch?v=Man4t8kx8h8', 'https://open.spotify.com/track/5jgFfDIR6FR0gvlA56Nakr', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Landslide', 'Fleetwood Mac', id, 3, 'https://www.youtube.com/watch?v=WM7-PYtXtJM', 'https://open.spotify.com/track/4TbcdHjuJIEgRS7FWJ3PDm', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'More Than Words', 'Extreme', id, 3, 'https://www.youtube.com/watch?v=UrIiLvg58SY', 'https://open.spotify.com/track/2QfiRTz5Yc8DdShCxBKhou', true
FROM instruments WHERE name = 'Guitar';

-- Guitar Level 4
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Get Lucky', 'Daft Punk', id, 4, 'https://www.youtube.com/watch?v=5NV6Rdv1a3I', 'https://open.spotify.com/track/2Foc5Q5nqNiosCNqttzHof', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Superstition', 'Stevie Wonder', id, 4, 'https://www.youtube.com/watch?v=0CFuCYNx-1g', 'https://open.spotify.com/track/1h2xVEoJORqrg71HocgqXd', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Isn''t She Lovely', 'Stevie Wonder', id, 4, 'https://www.youtube.com/watch?v=IVvkjuEAwgU', 'https://open.spotify.com/track/1yJDKmjqWCPJwQA2y3xI8X', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Tears in Heaven', 'Eric Clapton', id, 4, 'https://www.youtube.com/watch?v=JxPj3GAYYZ0', 'https://open.spotify.com/track/7xoUc6bQiJLSWY2kHEqW3i', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Classical Gas', 'Mason Williams', id, 4, 'https://www.youtube.com/watch?v=mREi_Bb85Sk', 'https://open.spotify.com/track/0TzdHTvEgKGoqwuV1oEhKr', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Wish You Were Here', 'Pink Floyd', id, 4, 'https://www.youtube.com/watch?v=IXdNnw99-Ic', 'https://open.spotify.com/track/6mFkJmJqdDVQ1REhVfGgd1', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Johnny B. Goode', 'Chuck Berry', id, 4, 'https://www.youtube.com/watch?v=ZFo8-JqzSCM', 'https://open.spotify.com/track/1jvWRFL3yPThJNObHiDc1x', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Pride and Joy', 'Stevie Ray Vaughan', id, 4, 'https://www.youtube.com/watch?v=0vo23H9J8o8', 'https://open.spotify.com/track/05fQlxQL2c7FvxOxlQ3yOW', true
FROM instruments WHERE name = 'Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Sweet Child O'' Mine', 'Guns N'' Roses', id, 4, 'https://www.youtube.com/watch?v=1w7OgIMMRc4', 'https://open.spotify.com/track/7o2CTH4ctstm8TNelqjb51', true
FROM instruments WHERE name = 'Guitar';

-- Bass Level 1
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Seven Nation Army', 'The White Stripes', id, 1, 'https://www.youtube.com/watch?v=0J2QdDbelmY', 'https://open.spotify.com/track/3dPQuX8Gs42Y7b454ybpMR', true
FROM instruments WHERE name = 'Bass Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Come As You Are', 'Nirvana', id, 1, 'https://www.youtube.com/watch?v=vabnZ9-ex7o', 'https://open.spotify.com/track/2RsAajgo0g7bMCHxwH3Sk0', true
FROM instruments WHERE name = 'Bass Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Another One Bites the Dust', 'Queen', id, 1, 'https://www.youtube.com/watch?v=rY0WxgSXdEE', 'https://open.spotify.com/track/5vdp5UmvTsnMEMESIF2Ym7', true
FROM instruments WHERE name = 'Bass Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Feel Good Inc.', 'Gorillaz', id, 1, 'https://www.youtube.com/watch?v=HyHNuVaZJ-k', 'https://open.spotify.com/track/0d28khcov6AiegSCpG5TuT', true
FROM instruments WHERE name = 'Bass Guitar';

-- Bass Level 2
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Billie Jean', 'Michael Jackson', id, 2, 'https://www.youtube.com/watch?v=Zi_XLOBDo_Y', 'https://open.spotify.com/track/5ChkMS8OtdzJeqyybCc9R5', true
FROM instruments WHERE name = 'Bass Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Money', 'Pink Floyd', id, 2, 'https://www.youtube.com/watch?v=-0kcet4aPpQ', 'https://open.spotify.com/track/6f1W4QHtQymBCaSmkB2k7u', true
FROM instruments WHERE name = 'Bass Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Under Pressure', 'Queen & David Bowie', id, 2, 'https://www.youtube.com/watch?v=a01QQZyl-_I', 'https://open.spotify.com/track/2fuCquhmrzHpu5xcfZOZOd', true
FROM instruments WHERE name = 'Bass Guitar';

-- Bass Level 3
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Good Times', 'Chic', id, 3, 'https://www.youtube.com/watch?v=Er9xGRolrT4', 'https://open.spotify.com/track/79cuOz3SPQTuFrp8WgftAu', true
FROM instruments WHERE name = 'Bass Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Higher Ground', 'Red Hot Chili Peppers', id, 3, 'https://www.youtube.com/watch?v=sdOLFtk9joI', 'https://open.spotify.com/track/6eU2ABH0VB4KTQ2L8qVdaL', true
FROM instruments WHERE name = 'Bass Guitar';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'The Chicken', 'Jaco Pastorius', id, 3, 'https://www.youtube.com/watch?v=JW8UrTd6RGQ', 'https://open.spotify.com/track/0uqxwpAgdFu0DH2K1yjIOX', true
FROM instruments WHERE name = 'Bass Guitar';

-- Piano Level 1
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Lean on Me', 'Bill Withers', id, 1, 'https://www.youtube.com/watch?v=fOZ-MySzAac', 'https://open.spotify.com/track/0x2vbqKYR85mz3CXbxLPNI', true
FROM instruments WHERE name = 'Piano/Keyboard';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Imagine', 'John Lennon', id, 1, 'https://www.youtube.com/watch?v=YkgkThdzX-8', 'https://open.spotify.com/track/7pKfPomDEeI4TPT6EOYjn9', true
FROM instruments WHERE name = 'Piano/Keyboard';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Hey Jude', 'The Beatles', id, 1, 'https://www.youtube.com/watch?v=A_MjCqQoLLA', 'https://open.spotify.com/track/0aym2LBJBk9DAYuHHutrIl', true
FROM instruments WHERE name = 'Piano/Keyboard';

-- Piano Level 2
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Clocks', 'Coldplay', id, 2, 'https://www.youtube.com/watch?v=d020hcWA_Wg', 'https://open.spotify.com/track/0BCPKOYdS2jbQ8iyB56Zns', true
FROM instruments WHERE name = 'Piano/Keyboard';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'A Thousand Miles', 'Vanessa Carlton', id, 2, 'https://www.youtube.com/watch?v=Cwkej79U3ek', 'https://open.spotify.com/track/07q0QVgO56EorrSGHC48y3', true
FROM instruments WHERE name = 'Piano/Keyboard';

-- Piano Level 3
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'River Flows in You', 'Yiruma', id, 3, 'https://www.youtube.com/watch?v=7maJOI3QMu0', 'https://open.spotify.com/track/37IUh6bJ72X50FvRz3xNjv', true
FROM instruments WHERE name = 'Piano/Keyboard';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'All of Me', 'John Legend', id, 3, 'https://www.youtube.com/watch?v=450p7goxZqg', 'https://open.spotify.com/track/3U4isOIWM3VvDubwSI3y7a', true
FROM instruments WHERE name = 'Piano/Keyboard';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Prelude in C Major', 'J.S. Bach', id, 3, 'https://www.youtube.com/watch?v=PXMVkQ70I88', 'https://open.spotify.com/track/5CJ2c4YPjvlj2i6iFz2cYo', true
FROM instruments WHERE name = 'Piano/Keyboard';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Comptine d''un autre été', 'Yann Tiersen', id, 3, 'https://www.youtube.com/watch?v=H2-1u8xvk54', 'https://open.spotify.com/track/4bRXPRj4gTpMiDJgPIX3fF', true
FROM instruments WHERE name = 'Piano/Keyboard';

-- Drums Level 1
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'We Will Rock You', 'Queen', id, 1, 'https://www.youtube.com/watch?v=-tJYN-eG1zk', 'https://open.spotify.com/track/54flyrjcdnQdco7300avMJ', true
FROM instruments WHERE name = 'Drums';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Highway to Hell', 'AC/DC', id, 1, 'https://www.youtube.com/watch?v=l482T0yNkeo', 'https://open.spotify.com/track/2zYzyRzz6pRmhPzyfMEC8s', true
FROM instruments WHERE name = 'Drums';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Back in Black', 'AC/DC', id, 1, 'https://www.youtube.com/watch?v=pAgnJDJN4VA', 'https://open.spotify.com/track/08mG3Y1vljYA6bvDt4Wqkj', true
FROM instruments WHERE name = 'Drums';

-- Drums Level 2
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Come Together', 'The Beatles', id, 2, 'https://www.youtube.com/watch?v=45cYwDMibGo', 'https://open.spotify.com/track/2EqlS6tkEnglzr7tkKAAYD', true
FROM instruments WHERE name = 'Drums';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Sex on Fire', 'Kings of Leon', id, 2, 'https://www.youtube.com/watch?v=RF0HhrwIwp0', 'https://open.spotify.com/track/0C0XDSWYcLT6yrXMGaNEWl', true
FROM instruments WHERE name = 'Drums';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Mr. Brightside', 'The Killers', id, 2, 'https://www.youtube.com/watch?v=gGdGFtwCNBE', 'https://open.spotify.com/track/7oK9VyNzrYvRFo7nQEYkWN', true
FROM instruments WHERE name = 'Drums';

-- Drums Level 3
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Enter Sandman', 'Metallica', id, 3, 'https://www.youtube.com/watch?v=CD-E-LDc384', 'https://open.spotify.com/track/1hKdDCpiI9mqz1jVHRKG0E', true
FROM instruments WHERE name = 'Drums';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Everlong', 'Foo Fighters', id, 3, 'https://www.youtube.com/watch?v=eBG7P-K-r1Y', 'https://open.spotify.com/track/5UWwZ5lm5PKu6eKsHAGxOk', true
FROM instruments WHERE name = 'Drums';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Good Times Bad Times', 'Led Zeppelin', id, 3, 'https://www.youtube.com/watch?v=x8TkZeQkScw', 'https://open.spotify.com/track/3uqXnY2LVJIvNCI84SN1Ag', true
FROM instruments WHERE name = 'Drums';

-- Vocals Level 1
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Happy Birthday', 'Traditional', id, 1, 'https://www.youtube.com/watch?v=inS9gAgSENE', NULL, true
FROM instruments WHERE name = 'Vocals';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'You Are My Sunshine', 'Traditional', id, 1, 'https://www.youtube.com/watch?v=cGa3zFRqDn4', NULL, true
FROM instruments WHERE name = 'Vocals';

-- Vocals Level 2
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Perfect', 'Ed Sheeran', id, 2, 'https://www.youtube.com/watch?v=2Vv-BfVoq4g', 'https://open.spotify.com/track/0tgVpDi06FyKpA1z0VMD4v', true
FROM instruments WHERE name = 'Vocals';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Thinking Out Loud', 'Ed Sheeran', id, 2, 'https://www.youtube.com/watch?v=lp-EO5I60KA', 'https://open.spotify.com/track/2lzGlmPrOEPqVTVLX9m9Rr', true
FROM instruments WHERE name = 'Vocals';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'A Thousand Years', 'Christina Perri', id, 2, 'https://www.youtube.com/watch?v=rtOvBOTyX00', 'https://open.spotify.com/track/6KhvKkHl8mPBCJUTEFFGHd', true
FROM instruments WHERE name = 'Vocals';

-- Vocals Level 3
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'All I Want', 'Kodaline', id, 3, 'https://www.youtube.com/watch?v=mtf7hC17IBM', 'https://open.spotify.com/track/3pyYKKBEXr9hGJWDCEKZd6', true
FROM instruments WHERE name = 'Vocals';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Hallelujah', 'Leonard Cohen', id, 3, 'https://www.youtube.com/watch?v=ttEMYvpoR-k', 'https://open.spotify.com/track/6NvRMScng5d4V0bn5Z9WKP', true
FROM instruments WHERE name = 'Vocals';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'At Last', 'Etta James', id, 3, 'https://www.youtube.com/watch?v=S-cbOl96RFM', 'https://open.spotify.com/track/4eHbdreAnSOrDDsFfc4Fpm', true
FROM instruments WHERE name = 'Vocals';

-- Shared songs that appear on multiple instruments
INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Let It Be', 'The Beatles', id, 1, 'https://www.youtube.com/watch?v=QDYfEBY9NM4', 'https://open.spotify.com/track/7iN1s7xHE4ifF5povM6A48', true
FROM instruments WHERE name IN ('Piano/Keyboard', 'Vocals');

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Stand By Me', 'Ben E. King', id, CASE WHEN name = 'Bass Guitar' THEN 2 WHEN name = 'Vocals' THEN 1 ELSE 2 END, 'https://www.youtube.com/watch?v=hwZNL7QVJjE', 'https://open.spotify.com/track/3SdTKo2uVsxFblQjpScoHy', true
FROM instruments WHERE name IN ('Bass Guitar', 'Vocals');

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'The Scientist', 'Coldplay', id, CASE WHEN name = 'Piano/Keyboard' THEN 2 ELSE 3 END, 'https://www.youtube.com/watch?v=RB-RcX5DS5A', 'https://open.spotify.com/track/75JFxkI2RXiU7L9VXzMkle', true
FROM instruments WHERE name IN ('Guitar', 'Piano/Keyboard');

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Someone Like You', 'Adele', id, 2, 'https://www.youtube.com/watch?v=hLQl3WQQoQ0', 'https://open.spotify.com/track/1zwMYTA5nlNjZxYrvBB2pV', true
FROM instruments WHERE name IN ('Piano/Keyboard', 'Vocals');

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Make You Feel My Love', 'Adele', id, 3, 'https://www.youtube.com/watch?v=0put0_a--Ng', 'https://open.spotify.com/track/37i9dQZF1DZ06evO3nMr04', true
FROM instruments WHERE name = 'Vocals';

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Billie Jean', 'Michael Jackson', id, CASE WHEN name = 'Drums' THEN 1 ELSE 2 END, 'https://www.youtube.com/watch?v=Zi_XLOBDo_Y', 'https://open.spotify.com/track/5ChkMS8OtdzJeqyybCc9R5', true
FROM instruments WHERE name IN ('Bass Guitar', 'Drums');

INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved)
SELECT 'Seven Nation Army', 'The White Stripes', id, CASE WHEN name = 'Bass Guitar' THEN 1 ELSE 2 END, 'https://www.youtube.com/watch?v=0J2QdDbelmY', 'https://open.spotify.com/track/3dPQuX8Gs42Y7b454ybpMR', true
FROM instruments WHERE name IN ('Bass Guitar', 'Drums');

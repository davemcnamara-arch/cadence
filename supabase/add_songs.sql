-- Add songs to the song library
-- These will be available for all students to grade and track

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

  -- ===== GUITAR SONGS =====

  -- Guitar Level 1
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Three Little Birds', 'Bob Marley', guitar_id, 1, 'https://www.youtube.com/watch?v=zaGUr6wzyT8', 'https://open.spotify.com/track/2Kx3Qhtl5gT1kNlBBnAIzc', true),
  ('Horse With No Name', 'America', guitar_id, 1, 'https://www.youtube.com/watch?v=zSAJ0l4OBHM', 'https://open.spotify.com/track/3ZHhKKr4pT0gZAcJ3gKJsO', true),
  ('Knockin'' on Heaven''s Door', 'Bob Dylan', guitar_id, 1, 'https://www.youtube.com/watch?v=VLUqN3sWUkU', 'https://open.spotify.com/track/3BNJHXp53Z2Rm0UWh1fWFw', true),
  ('Bad Moon Rising', 'Creedence Clearwater Revival', guitar_id, 1, 'https://www.youtube.com/watch?v=zUQiUFZ5RDw', 'https://open.spotify.com/track/57bgtoPSgt236HzfBOd8kj', true),
  ('Love Me Do', 'The Beatles', guitar_id, 1, 'https://www.youtube.com/watch?v=0pGOFX1D_jg', 'https://open.spotify.com/track/3jjsRKlGfKHTKq0Y9Y3Qq2', true);

  -- Guitar Level 2
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Wonderwall', 'Oasis', guitar_id, 2, 'https://www.youtube.com/watch?v=bx1Bh8ZvH84', 'https://open.spotify.com/track/1BxfuPKGuaTgP7aM0Bbdwr', true),
  ('Riptide', 'Vance Joy', guitar_id, 2, 'https://www.youtube.com/watch?v=uJ_1HMAGb4k', 'https://open.spotify.com/track/5ELQATaGvEq4cqLxQsRY1t', true),
  ('Let It Be', 'The Beatles', guitar_id, 2, 'https://www.youtube.com/watch?v=QDYfEBY9NM4', 'https://open.spotify.com/track/7iN1s7xHE4ifF5povM6A48', true),
  ('Brown Eyed Girl', 'Van Morrison', guitar_id, 2, 'https://www.youtube.com/watch?v=UfmkgQRmmeE', 'https://open.spotify.com/track/3yrSvt2jkB0subdivV5uXBh', true),
  ('Stand By Me', 'Ben E. King', guitar_id, 2, 'https://www.youtube.com/watch?v=hwZNL7QVJjE', 'https://open.spotify.com/track/3SdTKo2uVsxFblQjpScoHy', true);

  -- Guitar Level 3
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Dust in the Wind', 'Kansas', guitar_id, 3, 'https://www.youtube.com/watch?v=tH2w6Oxx0kQ', 'https://open.spotify.com/track/0hResEBaM5K8Jp8dVw4nJJ', true),
  ('Blackbird', 'The Beatles', guitar_id, 3, 'https://www.youtube.com/watch?v=Man4t8kx8h8', 'https://open.spotify.com/track/5jgFfDIR6FR0gvlA56Nakr', true),
  ('The Scientist', 'Coldplay', guitar_id, 3, 'https://www.youtube.com/watch?v=RB-RcX5DS5A', 'https://open.spotify.com/track/75JFxkI2RXiU7L9VXzMkle', true),
  ('Landslide', 'Fleetwood Mac', guitar_id, 3, 'https://www.youtube.com/watch?v=WM7-PYtXtJM', 'https://open.spotify.com/track/4TbcdHjuJIEgRS7FWJ3PDm', true),
  ('More Than Words', 'Extreme', guitar_id, 3, 'https://www.youtube.com/watch?v=UrIiLvg58SY', 'https://open.spotify.com/track/2QfiRTz5Yc8DdShCxBKhou', true);

  -- Guitar Level 4 Rhythm
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Get Lucky', 'Daft Punk', guitar_id, 4, 'https://www.youtube.com/watch?v=5NV6Rdv1a3I', 'https://open.spotify.com/track/2Foc5Q5nqNiosCNqttzHof', true),
  ('Superstition', 'Stevie Wonder', guitar_id, 4, 'https://www.youtube.com/watch?v=0CFuCYNx-1g', 'https://open.spotify.com/track/1h2xVEoJORqrg71HocgqXd', true),
  ('Isn''t She Lovely', 'Stevie Wonder', guitar_id, 4, 'https://www.youtube.com/watch?v=IVvkjuEAwgU', 'https://open.spotify.com/track/1yJDKmjqWCPJwQA2y3xI8X', true);

  -- Guitar Level 4 Fingerstyle
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Tears in Heaven', 'Eric Clapton', guitar_id, 4, 'https://www.youtube.com/watch?v=JxPj3GAYYZ0', 'https://open.spotify.com/track/7xoUc6bQiJLSWY2kHEqW3i', true),
  ('Classical Gas', 'Mason Williams', guitar_id, 4, 'https://www.youtube.com/watch?v=mREi_Bb85Sk', 'https://open.spotify.com/track/0TzdHTvEgKGoqwuV1oEhKr', true),
  ('Wish You Were Here', 'Pink Floyd', guitar_id, 4, 'https://www.youtube.com/watch?v=IXdNnw99-Ic', 'https://open.spotify.com/track/6mFkJmJqdDVQ1REhVfGgd1', true);

  -- Guitar Level 4 Lead
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Johnny B. Goode', 'Chuck Berry', guitar_id, 4, 'https://www.youtube.com/watch?v=ZFo8-JqzSCM', 'https://open.spotify.com/track/1jvWRFL3yPThJNObHiDc1x', true),
  ('Pride and Joy', 'Stevie Ray Vaughan', guitar_id, 4, 'https://www.youtube.com/watch?v=0vo23H9J8o8', 'https://open.spotify.com/track/05fQlxQL2c7FvxOxlQ3yOW', true),
  ('Sweet Child O'' Mine', 'Guns N'' Roses', guitar_id, 4, 'https://www.youtube.com/watch?v=1w7OgIMMRc4', 'https://open.spotify.com/track/7o2CTH4ctstm8TNelqjb51', true);

  -- ===== BASS GUITAR SONGS =====

  -- Bass Level 1
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Seven Nation Army', 'The White Stripes', bass_id, 1, 'https://www.youtube.com/watch?v=0J2QdDbelmY', 'https://open.spotify.com/track/3dPQuX8Gs42Y7b454ybpMR', true),
  ('Come As You Are', 'Nirvana', bass_id, 1, 'https://www.youtube.com/watch?v=vabnZ9-ex7o', 'https://open.spotify.com/track/2RsAajgo0g7bMCHxwH3Sk0', true),
  ('Another One Bites the Dust', 'Queen', bass_id, 1, 'https://www.youtube.com/watch?v=rY0WxgSXdEE', 'https://open.spotify.com/track/5vdp5UmvTsnMEMESIF2Ym7', true),
  ('Feel Good Inc.', 'Gorillaz', bass_id, 1, 'https://www.youtube.com/watch?v=HyHNuVaZJ-k', 'https://open.spotify.com/track/0d28khcov6AiegSCpG5TuT', true);

  -- Bass Level 2
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Billie Jean', 'Michael Jackson', bass_id, 2, 'https://www.youtube.com/watch?v=Zi_XLOBDo_Y', 'https://open.spotify.com/track/5ChkMS8OtdzJeqyybCc9R5', true),
  ('Stand By Me', 'Ben E. King', bass_id, 2, 'https://www.youtube.com/watch?v=hwZNL7QVJjE', 'https://open.spotify.com/track/3SdTKo2uVsxFblQjpScoHy', true),
  ('Money', 'Pink Floyd', bass_id, 2, 'https://www.youtube.com/watch?v=-0kcet4aPpQ', 'https://open.spotify.com/track/6f1W4QHtQymBCaSmkB2k7u', true),
  ('Under Pressure', 'Queen & David Bowie', bass_id, 2, 'https://www.youtube.com/watch?v=a01QQZyl-_I', 'https://open.spotify.com/track/2fuCquhmrzHpu5xcfZOZOd', true);

  -- Bass Level 3
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Good Times', 'Chic', bass_id, 3, 'https://www.youtube.com/watch?v=Er9xGRolrT4', 'https://open.spotify.com/track/79cuOz3SPQTuFrp8WgftAu', true),
  ('Higher Ground', 'Red Hot Chili Peppers', bass_id, 3, 'https://www.youtube.com/watch?v=sdOLFtk9joI', 'https://open.spotify.com/track/6eU2ABH0VB4KTQ2L8qVdaL', true),
  ('The Chicken', 'Jaco Pastorius', bass_id, 3, 'https://www.youtube.com/watch?v=JW8UrTd6RGQ', 'https://open.spotify.com/track/0uqxwpAgdFu0DH2K1yjIOX', true);

  -- ===== PIANO/KEYBOARD SONGS =====

  -- Piano Level 1
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Let It Be', 'The Beatles', piano_id, 1, 'https://www.youtube.com/watch?v=QDYfEBY9NM4', 'https://open.spotify.com/track/7iN1s7xHE4ifF5povM6A48', true),
  ('Lean on Me', 'Bill Withers', piano_id, 1, 'https://www.youtube.com/watch?v=fOZ-MySzAac', 'https://open.spotify.com/track/0x2vbqKYR85mz3CXbxLPNI', true),
  ('Imagine', 'John Lennon', piano_id, 1, 'https://www.youtube.com/watch?v=YkgkThdzX-8', 'https://open.spotify.com/track/7pKfPomDEeI4TPT6EOYjn9', true),
  ('Hey Jude', 'The Beatles', piano_id, 1, 'https://www.youtube.com/watch?v=A_MjCqQoLLA', 'https://open.spotify.com/track/0aym2LBJBk9DAYuHHutrIl', true);

  -- Piano Level 2
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Clocks', 'Coldplay', piano_id, 2, 'https://www.youtube.com/watch?v=d020hcWA_Wg', 'https://open.spotify.com/track/0BCPKOYdS2jbQ8iyB56Zns', true),
  ('Someone Like You', 'Adele', piano_id, 2, 'https://www.youtube.com/watch?v=hLQl3WQQoQ0', 'https://open.spotify.com/track/1zwMYTA5nlNjZxYrvBB2pV', true),
  ('The Scientist', 'Coldplay', piano_id, 2, 'https://www.youtube.com/watch?v=RB-RcX5DS5A', 'https://open.spotify.com/track/75JFxkI2RXiU7L9VXzMkle', true),
  ('A Thousand Miles', 'Vanessa Carlton', piano_id, 2, 'https://www.youtube.com/watch?v=Cwkej79U3ek', 'https://open.spotify.com/track/07q0QVgO56EorrSGHC48y3', true);

  -- Piano Level 3
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('River Flows in You', 'Yiruma', piano_id, 3, 'https://www.youtube.com/watch?v=7maJOI3QMu0', 'https://open.spotify.com/track/37IUh6bJ72X50FvRz3xNjv', true),
  ('All of Me', 'John Legend', piano_id, 3, 'https://www.youtube.com/watch?v=450p7goxZqg', 'https://open.spotify.com/track/3U4isOIWM3VvDubwSI3y7a', true),
  ('Prelude in C Major', 'J.S. Bach', piano_id, 3, 'https://www.youtube.com/watch?v=PXMVkQ70I88', 'https://open.spotify.com/track/5CJ2c4YPjvlj2i6iFz2cYo', true),
  ('Comptine d''un autre été', 'Yann Tiersen', piano_id, 3, 'https://www.youtube.com/watch?v=H2-1u8xvk54', 'https://open.spotify.com/track/4bRXPRj4gTpMiDJgPIX3fF', true);

  -- ===== DRUMS SONGS =====

  -- Drums Level 1
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('We Will Rock You', 'Queen', drums_id, 1, 'https://www.youtube.com/watch?v=-tJYN-eG1zk', 'https://open.spotify.com/track/54flyrjcdnQdco7300avMJ', true),
  ('Billie Jean', 'Michael Jackson', drums_id, 1, 'https://www.youtube.com/watch?v=Zi_XLOBDo_Y', 'https://open.spotify.com/track/5ChkMS8OtdzJeqyybCc9R5', true),
  ('Highway to Hell', 'AC/DC', drums_id, 1, 'https://www.youtube.com/watch?v=l482T0yNkeo', 'https://open.spotify.com/track/2zYzyRzz6pRmhPzyfMEC8s', true),
  ('Back in Black', 'AC/DC', drums_id, 1, 'https://www.youtube.com/watch?v=pAgnJDJN4VA', 'https://open.spotify.com/track/08mG3Y1vljYA6bvDt4Wqkj', true);

  -- Drums Level 2
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Come Together', 'The Beatles', drums_id, 2, 'https://www.youtube.com/watch?v=45cYwDMibGo', 'https://open.spotify.com/track/2EqlS6tkEnglzr7tkKAAYD', true),
  ('Seven Nation Army', 'The White Stripes', drums_id, 2, 'https://www.youtube.com/watch?v=0J2QdDbelmY', 'https://open.spotify.com/track/3dPQuX8Gs42Y7b454ybpMR', true),
  ('Sex on Fire', 'Kings of Leon', drums_id, 2, 'https://www.youtube.com/watch?v=RF0HhrwIwp0', 'https://open.spotify.com/track/0C0XDSWYcLT6yrXMGaNEWl', true),
  ('Mr. Brightside', 'The Killers', drums_id, 2, 'https://www.youtube.com/watch?v=gGdGFtwCNBE', 'https://open.spotify.com/track/7oK9VyNzrYvRFo7nQEYkWN', true);

  -- Drums Level 3
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Enter Sandman', 'Metallica', drums_id, 3, 'https://www.youtube.com/watch?v=CD-E-LDc384', 'https://open.spotify.com/track/1hKdDCpiI9mqz1jVHRKG0E', true),
  ('Everlong', 'Foo Fighters', drums_id, 3, 'https://www.youtube.com/watch?v=eBG7P-K-r1Y', 'https://open.spotify.com/track/5UWwZ5lm5PKu6eKsHAGxOk', true),
  ('Good Times Bad Times', 'Led Zeppelin', drums_id, 3, 'https://www.youtube.com/watch?v=x8TkZeQkScw', 'https://open.spotify.com/track/3uqXnY2LVJIvNCI84SN1Ag', true);

  -- ===== VOCALS SONGS =====

  -- Vocals Level 1
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Happy Birthday', 'Traditional', vocals_id, 1, 'https://www.youtube.com/watch?v=inS9gAgSENE', NULL, true),
  ('Let It Be', 'The Beatles', vocals_id, 1, 'https://www.youtube.com/watch?v=QDYfEBY9NM4', 'https://open.spotify.com/track/7iN1s7xHE4ifF5povM6A48', true),
  ('Stand By Me', 'Ben E. King', vocals_id, 1, 'https://www.youtube.com/watch?v=hwZNL7QVJjE', 'https://open.spotify.com/track/3SdTKo2uVsxFblQjpScoHy', true),
  ('You Are My Sunshine', 'Traditional', vocals_id, 1, 'https://www.youtube.com/watch?v=cGa3zFRqDn4', NULL, true);

  -- Vocals Level 2
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('Someone Like You', 'Adele', vocals_id, 2, 'https://www.youtube.com/watch?v=hLQl3WQQoQ0', 'https://open.spotify.com/track/1zwMYTA5nlNjZxYrvBB2pV', true),
  ('Perfect', 'Ed Sheeran', vocals_id, 2, 'https://www.youtube.com/watch?v=2Vv-BfVoq4g', 'https://open.spotify.com/track/0tgVpDi06FyKpA1z0VMD4v', true),
  ('Thinking Out Loud', 'Ed Sheeran', vocals_id, 2, 'https://www.youtube.com/watch?v=lp-EO5I60KA', 'https://open.spotify.com/track/2lzGlmPrOEPqVTVLX9m9Rr', true),
  ('A Thousand Years', 'Christina Perri', vocals_id, 2, 'https://www.youtube.com/watch?v=rtOvBOTyX00', 'https://open.spotify.com/track/6KhvKkHl8mPBCJUTEFFGHd', true);

  -- Vocals Level 3
  INSERT INTO songs (title, artist, instrument_id, suggested_level, youtube_url, spotify_url, approved) VALUES
  ('All I Want', 'Kodaline', vocals_id, 3, 'https://www.youtube.com/watch?v=mtf7hC17IBM', 'https://open.spotify.com/track/3pyYKKBEXr9hGJWDCEKZd6', true),
  ('Hallelujah', 'Leonard Cohen', vocals_id, 3, 'https://www.youtube.com/watch?v=ttEMYvpoR-k', 'https://open.spotify.com/track/6NvRMScng5d4V0bn5Z9WKP', true),
  ('Make You Feel My Love', 'Adele', vocals_id, 3, 'https://www.youtube.com/watch?v=0put0_a--Ng', 'https://open.spotify.com/track/37i9dQZF1DZ06evO3nMr04', true),
  ('At Last', 'Etta James', vocals_id, 3, 'https://www.youtube.com/watch?v=S-cbOl96RFM', 'https://open.spotify.com/track/4eHbdreAnSOrDDsFfc4Fpm', true);

END $$;

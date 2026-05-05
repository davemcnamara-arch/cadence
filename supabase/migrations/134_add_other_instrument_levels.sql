-- Levels for the "Other Instrument" instrument (single-note melody focus).
-- Levels 1–3 are linear. Levels 4–5 branch into three paths:
--   A: Classical & Traditional
--   B: Contemporary & Folk
--   C: Jazz & Improvisation

DO $$
DECLARE
  other_id UUID;
BEGIN
  SELECT id INTO other_id FROM instruments WHERE name = 'Other Instrument';

  -- ===== LEVEL 1: Finding Your Notes =====
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (other_id, 1, 'Finding Your Notes', 'Learning to produce a clear tone and play simple melodies',
    '[
      "Consistent, clear tone production",
      "Simple 5-note melodies within one octave",
      "Steady pulse and basic rhythm (quarter and half notes)",
      "Basic posture and instrument hold",
      "Playing familiar tunes by ear or from memory"
    ]'::jsonb,
    '{
      "Melody range": ["3-5 notes", "5-7 notes", "full octave"],
      "Tone quality": ["inconsistent", "developing", "clear"],
      "Rhythm": ["quarter notes only", "includes half notes", "includes eighth notes"],
      "Technique": ["basic hold", "developing", "consistent"]
    }'::jsonb,
    ARRAY['Hot Cross Buns', 'Mary Had a Little Lamb', 'Twinkle Twinkle Little Star']
  );

  -- ===== LEVEL 2: Building Melodies =====
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (other_id, 2, 'Building Melodies', 'Expanding range and adding expression to your playing',
    '[
      "Full one-octave scale with good intonation",
      "Simple melodies with dynamics (loud/soft)",
      "Eighth notes and dotted rhythms",
      "Basic articulation (slurs or tonguing)",
      "Short pieces with verse/chorus or ABA structure"
    ]'::jsonb,
    '{
      "Range": ["single octave", "octave and a few extra notes", "wider"],
      "Intonation": ["inconsistent", "mostly in tune", "solid"],
      "Rhythm": ["simple patterns", "eighth notes", "dotted rhythms"],
      "Dynamics": ["none", "basic loud/soft", "varied"],
      "Articulation": ["none", "basic", "varied"]
    }'::jsonb,
    ARRAY['Ode to Joy', 'Amazing Grace', 'Simple Gifts']
  );

  -- ===== LEVEL 3: Developing Technique =====
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (other_id, 3, 'Developing Technique', 'Growing your range and control across multiple octaves',
    '[
      "Two-octave range with consistent intonation",
      "Varied articulation (legato, staccato, accents)",
      "Syncopated rhythms and rests",
      "Multiple song sections with contrasting moods",
      "Basic ornamentation or expressive techniques (e.g. vibrato, bends)"
    ]'::jsonb,
    '{
      "Range": ["one octave", "octave and a half", "two octaves"],
      "Intonation": ["developing", "good", "excellent"],
      "Articulation variety": ["single style", "two styles", "varied"],
      "Rhythm complexity": ["simple", "some syncopation", "complex"],
      "Ornamentation": ["none", "basic", "expressive"]
    }'::jsonb,
    ARRAY['Canon in D (melody)', 'Somewhere Over the Rainbow', 'Hallelujah']
  );

  -- ===== LEVEL 4A: Classical & Traditional =====
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (other_id, 4, 'Classical & Traditional', 'Repertoire focused on classical and traditional styles',
    '[
      "Sight-reading simple notation",
      "Extended two-octave-plus range",
      "Nuanced bow/breath/finger control for phrasing",
      "Classical or folk repertoire with stylistic accuracy",
      "Consistent intonation across the full range"
    ]'::jsonb,
    '{
      "Repertoire style": ["classical", "traditional/folk", "mixed"],
      "Sight-reading": ["none", "basic", "solid"],
      "Range": ["two octaves", "two-plus octaves", "full instrument range"],
      "Intonation": ["good", "very good", "excellent"],
      "Phrasing": ["basic", "musical", "expressive"]
    }'::jsonb,
    ARRAY['Bach Minuet in G', 'Scarborough Fair', 'Danny Boy'],
    true, 'Classical & Traditional'
  );

  -- ===== LEVEL 4B: Contemporary & Folk =====
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (other_id, 4, 'Contemporary & Folk', 'Playing pop, folk, and contemporary music by ear and from notation',
    '[
      "Playing melodies by ear across two octaves",
      "Pop and folk song repertoire",
      "Rhythmic feel — steady groove and natural phrasing",
      "Dynamic shaping matching the song mood",
      "Basic riffs, hooks, or recurring melodic ideas"
    ]'::jsonb,
    '{
      "Repertoire style": ["folk", "pop/contemporary", "mixed"],
      "Learning method": ["by ear", "from notation", "both"],
      "Range": ["one octave", "two octaves", "extended"],
      "Groove & feel": ["developing", "solid", "musical"],
      "Melodic hooks": ["none", "simple", "developed"]
    }'::jsonb,
    ARRAY['Shape of You (melody)', 'Counting Stars (melody)', 'The Sound of Silence (melody)'],
    true, 'Contemporary & Folk'
  );

  -- ===== LEVEL 4C: Jazz & Improvisation =====
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (other_id, 4, 'Jazz & Improvisation', 'Exploring scales, modes, and melodic improvisation',
    '[
      "Major and minor pentatonic scales across two octaves",
      "Blues scale and blue notes",
      "Call-and-response improvisation over simple chord progressions",
      "Swing feel and jazz phrasing",
      "Simple jazz or blues melody heads"
    ]'::jsonb,
    '{
      "Scales used": ["pentatonic", "blues scale", "modes/extended"],
      "Improvisation": ["none", "simple phrases", "developing vocabulary"],
      "Swing feel": ["none", "developing", "natural"],
      "Repertoire style": ["blues", "jazz standards", "mixed"],
      "Melodic vocabulary": ["limited", "developing", "expressive"]
    }'::jsonb,
    ARRAY['Autumn Leaves (melody)', 'St. James Infirmary (melody)', 'Summertime (melody)'],
    true, 'Jazz & Improvisation'
  );

  -- ===== LEVEL 5A: Advanced Classical =====
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (other_id, 5, 'Advanced Classical', 'Advanced technique and expressive classical performance',
    '[
      "Full instrument range with secure intonation",
      "Complex classical or traditional repertoire",
      "Advanced technique specific to the instrument",
      "Stylistically informed performance",
      "Sight-reading intermediate level notation"
    ]'::jsonb,
    '{
      "Technical demand": ["intermediate", "advanced", "virtuosic"],
      "Range used": ["two octaves", "extended", "full range"],
      "Stylistic accuracy": ["basic", "good", "excellent"],
      "Sight-reading": ["basic", "intermediate", "advanced"],
      "Intonation": ["very good", "excellent", "outstanding"]
    }'::jsonb,
    ARRAY['Vivaldi Concerto (movement)', 'Celtic/folk showpieces', 'Advanced art songs'],
    true, 'Advanced Classical'
  );

  -- ===== LEVEL 5B: Advanced Contemporary =====
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (other_id, 5, 'Advanced Contemporary', 'Sophisticated melodic writing and performance in modern styles',
    '[
      "Complex contemporary or folk repertoire",
      "Extended techniques for the instrument (e.g. effects, extended range)",
      "Own arrangements or original melodic ideas",
      "Confident performance with musical phrasing and dynamics",
      "Cross-genre awareness"
    ]'::jsonb,
    '{
      "Technical demand": ["intermediate", "advanced", "virtuosic"],
      "Musical expression": ["basic", "developed", "highly expressive"],
      "Originality": ["covers only", "some arrangements", "original material"],
      "Performance confidence": ["developing", "solid", "commanding"],
      "Genre fluency": ["one genre", "two genres", "cross-genre"]
    }'::jsonb,
    ARRAY['Complex pop/folk arrangements', 'Film/TV themes', 'Original compositions'],
    true, 'Advanced Contemporary'
  );

  -- ===== LEVEL 5C: Advanced Improvisation =====
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (other_id, 5, 'Advanced Improvisation', 'Fluent melodic improvisation and advanced harmonic awareness',
    '[
      "Improvising over complex chord progressions",
      "Modes and advanced scales (Dorian, Mixolydian, etc.)",
      "Strong personal melodic voice",
      "Playing over rhythm changes or jazz standards",
      "Interplay with other musicians"
    ]'::jsonb,
    '{
      "Harmonic awareness": ["basic", "intermediate", "advanced"],
      "Scale/mode vocabulary": ["pentatonic/blues", "modes", "advanced harmony"],
      "Personal voice": ["limited", "developing", "distinctive"],
      "Repertoire complexity": ["simple progressions", "standards", "complex changes"],
      "Interplay": ["solo focus", "some interaction", "conversational"]
    }'::jsonb,
    ARRAY['Jazz standards (improvisation)', 'Blues jams', 'Free improvisation'],
    true, 'Advanced Improvisation'
  );

END;
$$;

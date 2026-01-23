-- Cadence Music Tracker - Seed Data
-- All 5 instruments with complete level progressions

-- Insert instruments
INSERT INTO instruments (name, icon, description, display_order) VALUES
  ('Guitar', '🎸', 'Acoustic and electric guitar skills progression', 1),
  ('Bass Guitar', '🎸', 'Electric bass guitar fundamentals and advanced techniques', 2),
  ('Piano/Keyboard', '🎹', 'Piano and keyboard playing from basics to advanced', 3),
  ('Drums', '🥁', 'Drumming techniques across multiple styles', 4),
  ('Vocals', '🎤', 'Singing and vocal performance development', 5);

-- Get instrument IDs for reference
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

  -- ===== GUITAR LEVELS =====

  -- Guitar Level 1
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (guitar_id, 1, 'Foundation', 'Building basic chord vocabulary and strumming fundamentals',
    '[
      "2-3 basic open chords (G, C, D, Em, Am)",
      "Single strumming pattern throughout",
      "Same chord progression repeated",
      "4/4 time signature only",
      "Smooth chord transitions developing"
    ]'::jsonb,
    '{
      "Number of chords": ["2-3", "4-5", "6+"],
      "Chord types": ["open chords only", "includes minors", "includes 7ths"],
      "Strumming patterns": ["single pattern", "2 patterns", "varies"],
      "Time signature": ["4/4 only", "includes other"],
      "Song structure": ["repeating progression", "verse/chorus", "multiple sections"]
    }'::jsonb,
    ARRAY['Three Little Birds', 'Horse With No Name', 'Knockin on Heaven''s Door']
  );

  -- Guitar Level 2
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (guitar_id, 2, 'Expanding Vocabulary', 'Growing chord knowledge and introducing variations',
    '[
      "5-6 chords including minors and 7ths",
      "2-3 different strumming patterns",
      "Verse/chorus structure",
      "Basic dynamics (loud/soft)",
      "Introduction to fingerpicking OR first barre chord"
    ]'::jsonb,
    '{
      "Number of chords": ["4-5", "6-7", "8+"],
      "Chord types": ["open only", "includes 7ths", "includes barre"],
      "Strumming patterns": ["1-2", "3-4", "5+"],
      "Playing techniques": ["strumming only", "basic fingerpicking", "both"],
      "Dynamics": ["none", "basic loud/soft", "varied"],
      "Song structure": ["verse/chorus", "includes bridge", "complex"]
    }'::jsonb,
    ARRAY['Wonderwall', 'Riptide', 'Let It Be']
  );

  -- Guitar Level 3
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (guitar_id, 3, 'Technical Development', 'Advanced techniques and musical expression',
    '[
      "8+ chords including several barre chords",
      "Fingerpicking patterns with alternating bass",
      "Multiple sections (verse/chorus/bridge)",
      "Consistent rhythm and timing",
      "Basic palm muting or percussive strumming"
    ]'::jsonb,
    '{
      "Barre chords": ["none", "1-2", "several", "primarily barre"],
      "Fingerpicking": ["none", "basic patterns", "alternating bass", "complex"],
      "Techniques": ["palm muting", "percussive", "hammer-ons/pull-offs"],
      "Song sections": ["2 sections", "3 sections", "4+ sections"],
      "Timing complexity": ["straight rhythm", "some syncopation", "complex"]
    }'::jsonb,
    ARRAY['Dust in the Wind', 'Blackbird', 'The Scientist']
  );

  -- Guitar Level 4A - Rhythm Focus
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (guitar_id, 4, 'Rhythm Focus', 'Complex strumming and rhythm guitar mastery',
    '[
      "Complex strumming patterns",
      "Funk/reggae rhythms",
      "Advanced muting techniques",
      "6+ barre chords fluently"
    ]'::jsonb,
    '{
      "Primary style": ["rhythm", "fingerstyle", "lead"],
      "Strumming complexity": ["basic patterns", "complex patterns", "funk/reggae"],
      "Barre chords": ["some", "many", "primarily barre"],
      "Multiple song sections": ["yes", "no"],
      "Improvisation elements": ["none", "minimal", "moderate"]
    }'::jsonb,
    ARRAY['I''m Yours', 'Soul Man'],
    true, 'Rhythm Focus'
  );

  -- Guitar Level 4B - Fingerstyle Focus
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (guitar_id, 4, 'Fingerstyle Focus', 'Advanced fingerpicking techniques',
    '[
      "Travis picking",
      "Thumb independence",
      "Melody + bass simultaneously",
      "Harmonics introduction"
    ]'::jsonb,
    '{
      "Primary style": ["rhythm", "fingerstyle", "lead"],
      "Fingerpicking technique": ["basic", "travis picking", "advanced"],
      "Thumb independence": ["developing", "good", "mastered"],
      "Multiple song sections": ["yes", "no"],
      "Improvisation elements": ["none", "minimal", "moderate"]
    }'::jsonb,
    ARRAY['Landslide', 'Tears in Heaven'],
    true, 'Fingerstyle Focus'
  );

  -- Guitar Level 4C - Lead Introduction
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (guitar_id, 4, 'Lead Introduction', 'Beginning lead guitar and soloing',
    '[
      "Pentatonic scales",
      "Simple solos",
      "String bending and slides",
      "Playing over chord changes"
    ]'::jsonb,
    '{
      "Primary style": ["rhythm", "fingerstyle", "lead"],
      "Scale knowledge": ["none", "pentatonic", "multiple scales"],
      "Bending technique": ["none", "basic", "controlled"],
      "Multiple song sections": ["yes", "no"],
      "Improvisation elements": ["none", "minimal", "moderate"]
    }'::jsonb,
    ARRAY['Sunshine of Your Love', 'Come As You Are'],
    true, 'Lead Introduction'
  );

  -- Guitar Level 5A - Advanced Rhythm
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (guitar_id, 5, 'Advanced Rhythm', 'Mastery of rhythm guitar across styles',
    '[
      "Syncopation mastery",
      "Jazz/funk chords (9ths, 13ths)",
      "Advanced muting and percussive techniques"
    ]'::jsonb,
    '{
      "Style mastery level": ["developing", "competent", "advanced"],
      "Extended chords": ["7ths only", "9ths/13ths", "alterations"],
      "Syncopation": ["basic", "moderate", "mastered"],
      "Key changes": ["none", "one", "multiple"],
      "Expression/dynamics": ["basic", "good", "exceptional"],
      "Improvisation": ["none", "structured", "free"]
    }'::jsonb,
    ARRAY['Superstition', 'Use Somebody'],
    true, 'Advanced Rhythm'
  );

  -- Guitar Level 5B - Advanced Fingerstyle
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (guitar_id, 5, 'Advanced Fingerstyle', 'Complex fingerstyle arrangements',
    '[
      "Harmonics (natural and artificial)",
      "Percussive elements integrated",
      "Complex arrangements"
    ]'::jsonb,
    '{
      "Style mastery level": ["developing", "competent", "advanced"],
      "Harmonics": ["none", "natural", "natural & artificial"],
      "Percussive elements": ["none", "some", "integrated"],
      "Key changes": ["none", "one", "multiple"],
      "Expression/dynamics": ["basic", "good", "exceptional"],
      "Improvisation": ["none", "structured", "free"]
    }'::jsonb,
    ARRAY['Classical Gas', 'Neon'],
    true, 'Advanced Fingerstyle'
  );

  -- Guitar Level 5C - Lead Development
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (guitar_id, 5, 'Lead Development', 'Advanced soloing and improvisation',
    '[
      "Full scales and modes",
      "Improvisation over changes",
      "String bending with vibrato",
      "Advanced phrasing"
    ]'::jsonb,
    '{
      "Style mastery level": ["developing", "competent", "advanced"],
      "Scale knowledge": ["pentatonic", "major/minor scales", "modes"],
      "Vibrato": ["none", "basic", "controlled"],
      "Key changes": ["none", "one", "multiple"],
      "Expression/dynamics": ["basic", "good", "exceptional"],
      "Improvisation": ["none", "structured", "free"]
    }'::jsonb,
    ARRAY['Little Wing', 'Sultans of Swing'],
    true, 'Lead Development'
  );

  -- ===== BASS GUITAR LEVELS =====

  -- Bass Level 1
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (bass_id, 1, 'Foundation', 'Basic bass fundamentals and timing',
    '[
      "Root notes only, following chord changes",
      "Finger-style technique (index and middle)",
      "Quarter notes and half notes",
      "4/4 time, simple rock/pop patterns",
      "Consistent timing with metronome"
    ]'::jsonb,
    '{
      "Note choice": ["roots only", "roots + fifths", "chromatic approaches"],
      "Technique": ["fingers only", "pick only", "both"],
      "Rhythm": ["quarter/half notes", "eighth notes", "sixteenth notes"],
      "Time signature": ["4/4 only", "includes other"],
      "Timing": ["with metronome", "locked with drums", "independent"]
    }'::jsonb,
    ARRAY['Seven Nation Army', 'Another One Bites the Dust', 'Stand By Me']
  );

  -- Bass Level 2
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (bass_id, 2, 'Rhythm Development', 'Building rhythmic complexity',
    '[
      "Root and fifth patterns",
      "Basic eighth note patterns",
      "Introduction to pick technique OR three-finger",
      "Simple fills (approach notes)",
      "Locked in with drums"
    ]'::jsonb,
    '{
      "Note patterns": ["roots only", "roots/fifths", "octaves"],
      "Rhythm complexity": ["quarters/eighths", "sixteenth notes", "syncopated"],
      "Fills": ["none", "simple", "moderate"],
      "Technique variety": ["one technique", "two techniques", "multiple"],
      "Groove": ["basic", "solid", "locked"]
    }'::jsonb,
    ARRAY['Billie Jean', 'Come Together', 'Uptown Funk']
  );

  -- Bass Level 3
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (bass_id, 3, 'Melodic Playing', 'Introducing melodic elements and expression',
    '[
      "Octaves and basic scales",
      "Walking bass lines (quarter notes)",
      "Chord tones (root, 3rd, 5th)",
      "Simple syncopation",
      "Dynamics and note length variation"
    ]'::jsonb,
    '{
      "Melodic elements": ["octaves", "scales", "chord tones", "walking lines"],
      "Syncopation": ["none", "basic", "moderate", "complex"],
      "Dynamics": ["static", "some variation", "expressive"],
      "Note articulation": ["basic", "staccato/legato", "advanced"],
      "Song complexity": ["simple", "moderate", "complex"]
    }'::jsonb,
    ARRAY['The Chain', 'Longview', 'Hysteria']
  );

  -- Bass Level 4A - Groove Focus
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (bass_id, 4, 'Groove Focus', 'Funk and groove-oriented playing',
    '[
      "Funk patterns",
      "Ghost notes",
      "Locked 16th notes",
      "Pocket playing"
    ]'::jsonb,
    '{
      "Primary style": ["groove/funk", "melodic/walking", "rock/punk"],
      "Ghost notes": ["none", "some", "mastered"],
      "16th note patterns": ["basic", "moderate", "complex"],
      "Speed/tempo": ["slow/medium", "medium/fast", "fast/very fast"],
      "Complexity": ["moderate", "advanced", "very advanced"]
    }'::jsonb,
    ARRAY['Higher Ground', 'Forget Me Nots'],
    true, 'Groove Focus'
  );

  -- Bass Level 4B - Melodic Focus
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (bass_id, 4, 'Melodic Focus', 'Walking bass and melodic phrasing',
    '[
      "Walking bass lines",
      "Chord tone arpeggios",
      "Fills between changes",
      "Melodic phrasing"
    ]'::jsonb,
    '{
      "Primary style": ["groove/funk", "melodic/walking", "rock/punk"],
      "Walking lines": ["none", "basic", "complex"],
      "Chord tone usage": ["basic", "moderate", "advanced"],
      "Speed/tempo": ["slow/medium", "medium/fast", "fast/very fast"],
      "Complexity": ["moderate", "advanced", "very advanced"]
    }'::jsonb,
    ARRAY['Dear Prudence', 'Money'],
    true, 'Melodic Focus'
  );

  -- Bass Level 4C - Rock/Punk Focus
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (bass_id, 4, 'Rock/Punk Focus', 'Driving rock and punk bass',
    '[
      "Pick technique mastery",
      "Driving eighth notes",
      "Power and energy",
      "Fast passages"
    ]'::jsonb,
    '{
      "Primary style": ["groove/funk", "melodic/walking", "rock/punk"],
      "Pick technique": ["basic", "good", "mastered"],
      "Energy level": ["moderate", "high", "intense"],
      "Speed/tempo": ["slow/medium", "medium/fast", "fast/very fast"],
      "Complexity": ["moderate", "advanced", "very advanced"]
    }'::jsonb,
    ARRAY['Dani California', 'Basket Case'],
    true, 'Rock/Punk Focus'
  );

  -- Bass Level 5A - Slap/Pop
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (bass_id, 5, 'Slap/Pop', 'Advanced slap bass techniques',
    '[
      "Thumb slap technique",
      "Finger pop",
      "Dead notes and muting",
      "Funk grooves"
    ]'::jsonb,
    '{
      "Advanced techniques": ["slap", "pop", "dead notes", "double-thumb"],
      "Multiple time signatures": ["no", "yes"],
      "Improvisation": ["none", "structured", "extensive"],
      "Musical complexity": ["moderate", "high", "very high"],
      "Style mastery": ["developing", "competent", "advanced"]
    }'::jsonb,
    ARRAY['Can''t Stop', 'Tommy the Cat'],
    true, 'Slap/Pop'
  );

  -- Bass Level 5B - Jazz/Walking
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (bass_id, 5, 'Jazz/Walking', 'Jazz bass and walking lines',
    '[
      "Complex walking lines",
      "Jazz phrasing",
      "Chord substitutions",
      "Swing feel"
    ]'::jsonb,
    '{
      "Advanced techniques": ["walking lines", "chord subs", "swing feel", "jazz phrasing"],
      "Multiple time signatures": ["no", "yes"],
      "Improvisation": ["none", "structured", "extensive"],
      "Musical complexity": ["moderate", "high", "very high"],
      "Style mastery": ["developing", "competent", "advanced"]
    }'::jsonb,
    ARRAY['All Blues', 'So What'],
    true, 'Jazz/Walking'
  );

  -- Bass Level 5C - Modern Rock
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (bass_id, 5, 'Modern Rock', 'Progressive and modern rock bass',
    '[
      "Complex rhythms",
      "Effects pedals integration",
      "Aggressive playing",
      "Extended techniques"
    ]'::jsonb,
    '{
      "Advanced techniques": ["complex rhythms", "effects", "tapping", "harmonics"],
      "Multiple time signatures": ["no", "yes"],
      "Improvisation": ["none", "structured", "extensive"],
      "Musical complexity": ["moderate", "high", "very high"],
      "Style mastery": ["developing", "competent", "advanced"]
    }'::jsonb,
    ARRAY['Schism', '46 & 2'],
    true, 'Modern Rock'
  );

  -- ===== PIANO/KEYBOARD LEVELS =====

  -- Piano Level 1
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (piano_id, 1, 'Foundation', 'Basic hand coordination and simple melodies',
    '[
      "Right hand melody (5-finger position)",
      "Left hand single notes or simple chords",
      "Hands separately first, then together",
      "Reading basic notation or chord symbols",
      "Simple pop melodies"
    ]'::jsonb,
    '{
      "Playing approach": ["chord chart only", "simple notation only", "both"],
      "Number of chords": ["2-3", "4-5", "6+"],
      "Hand coordination": ["separate hands", "hands together - simple", "hands together - complex"],
      "Left hand technique": ["single notes", "basic chords", "chord progressions"],
      "Right hand technique": ["single notes/chords", "simple melody", "melody + chords"],
      "Song structure": ["single section", "verse/chorus", "multiple sections"]
    }'::jsonb,
    ARRAY['Let It Be (simplified)', 'Imagine (basic)', 'Clocks (riff only)']
  );

  -- Piano Level 2
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (piano_id, 2, 'Coordination Development', 'Building hand independence',
    '[
      "Both hands playing simultaneously",
      "Basic chord progressions (I-IV-V)",
      "Simple rhythmic patterns",
      "Major and minor triads",
      "Verse/chorus structure"
    ]'::jsonb,
    '{
      "Playing approach": ["chord chart only", "notation only", "both"],
      "Number of chords": ["4-5", "6-7", "8+"],
      "Chord types": ["major/minor only", "includes 7ths", "extended chords"],
      "Patterns": ["block chords only", "arpeggios/broken chords", "mixed patterns"],
      "Hand independence": ["basic", "moderate", "advanced"],
      "Rhythm complexity": ["simple/steady", "some variation", "syncopated"],
      "Dynamics": ["none", "basic loud/soft", "expressive"]
    }'::jsonb,
    ARRAY['Someone Like You', 'A Thousand Years', 'The Scientist']
  );

  -- Piano Level 3
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (piano_id, 3, 'Independence Building', 'Advanced coordination and expression',
    '[
      "Right hand melody + left hand chords",
      "Inversions and chord voicings",
      "Basic pedal technique",
      "Arpeggios and broken chords",
      "Simple accompaniment patterns"
    ]'::jsonb,
    '{
      "Playing approach": ["chord chart only", "notation only", "both"],
      "Chord complexity": ["basic triads", "inversions", "7ths and inversions"],
      "Number of chords": ["6-8", "8-10", "10+"],
      "Pedal use": ["none", "basic sustain", "controlled pedaling"],
      "Accompaniment patterns": ["block chords", "alberti bass/arpeggios", "varied patterns"],
      "Hand independence": ["moderate", "good", "excellent"],
      "Expression/dynamics": ["basic", "moderate", "expressive"]
    }'::jsonb,
    ARRAY['River Flows in You', 'All of Me', 'Stay With Me']
  );

  -- Piano Level 4A - Contemporary/Pop
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (piano_id, 4, 'Contemporary/Pop', 'Modern pop and electronic keyboard',
    '[
      "Modern chord voicings",
      "Synth sounds",
      "Loops and layers",
      "Electronic elements"
    ]'::jsonb,
    '{
      "Primary style": ["contemporary/pop", "singer-songwriter", "jazz/blues", "classical pieces"],
      "Playing approach": ["chord charts", "notation", "both/mixed"],
      "Chord voicings": ["basic triads", "7ths", "extended/jazz chords"],
      "Complexity": ["straightforward", "moderate", "complex arrangements"],
      "Modern elements": ["none", "some", "well integrated"],
      "Performance/expression": ["technique focus", "some expression", "fully expressive"]
    }'::jsonb,
    ARRAY['Radioactive', 'Pompeii'],
    true, 'Contemporary/Pop'
  );

  -- Piano Level 4B - Singer-Songwriter
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (piano_id, 4, 'Singer-Songwriter', 'Accompaniment and storytelling',
    '[
      "Accompaniment patterns",
      "Following vocals",
      "Dynamics and expression",
      "Storytelling through playing"
    ]'::jsonb,
    '{
      "Primary style": ["contemporary/pop", "singer-songwriter", "jazz/blues", "classical pieces"],
      "Playing approach": ["chord charts", "notation", "both/mixed"],
      "Chord voicings": ["basic triads", "7ths", "extended/jazz chords"],
      "Complexity": ["straightforward", "moderate", "complex arrangements"],
      "Vocal integration": ["instrumental only", "basic accompaniment", "integrated with vocals"],
      "Performance/expression": ["technique focus", "some expression", "fully expressive"]
    }'::jsonb,
    ARRAY['The A Team', 'Say Something'],
    true, 'Singer-Songwriter'
  );

  -- Piano Level 4C - Jazz/Blues
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (piano_id, 4, 'Jazz/Blues', 'Jazz and blues piano fundamentals',
    '[
      "7th chords",
      "Swing feel",
      "Blues scales",
      "Comping patterns"
    ]'::jsonb,
    '{
      "Primary style": ["contemporary/pop", "singer-songwriter", "jazz/blues", "classical pieces"],
      "Playing approach": ["chord charts", "notation", "both/mixed"],
      "Chord voicings": ["basic triads", "7ths", "extended/jazz chords"],
      "Complexity": ["straightforward", "moderate", "complex arrangements"],
      "Swing/groove": ["none", "basic feel", "strong swing/groove"],
      "Performance/expression": ["technique focus", "some expression", "fully expressive"]
    }'::jsonb,
    ARRAY['Just the Two of Us', 'Ain''t No Sunshine'],
    true, 'Jazz/Blues'
  );

  -- Piano Level 5A - Extended Chords
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (piano_id, 5, 'Extended Chords', 'Advanced harmony and reharmonization',
    '[
      "9ths, 11ths, 13ths",
      "Sus chords",
      "Modern progressions",
      "Reharmonization"
    ]'::jsonb,
    '{
      "Playing approach": ["chord charts", "notation", "both/mixed"],
      "Harmonic complexity": ["7ths", "9ths/11ths/13ths", "alterations/substitutions"],
      "Technical demands": ["moderate", "high", "very high"],
      "Two-hand independence": ["good", "very good", "mastered"],
      "Improvisation elements": ["none", "structured", "free improvisation"],
      "Style mastery": ["developing", "competent", "advanced"]
    }'::jsonb,
    ARRAY['Comptine d''un autre été', 'Mad World'],
    true, 'Extended Chords'
  );

  -- Piano Level 5B - Performance Skills
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (piano_id, 5, 'Performance Skills', 'Complex arrangements and performance',
    '[
      "Complex arrangements",
      "Vocal + piano integration",
      "Stage presence elements",
      "Dynamic control"
    ]'::jsonb,
    '{
      "Playing approach": ["chord charts", "notation", "both/mixed"],
      "Harmonic complexity": ["7ths", "9ths/11ths/13ths", "alterations/substitutions"],
      "Technical demands": ["moderate", "high", "very high"],
      "Two-hand independence": ["good", "very good", "mastered"],
      "Improvisation elements": ["none", "structured", "free improvisation"],
      "Style mastery": ["developing", "competent", "advanced"]
    }'::jsonb,
    ARRAY['Hallelujah (full arrangement)', 'Fix You'],
    true, 'Performance Skills'
  );

  -- Piano Level 5C - Improvisation
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (piano_id, 5, 'Improvisation', 'Jazz improvisation and soloing',
    '[
      "Soloing",
      "Comping",
      "Chord substitutions",
      "Jazz vocabulary"
    ]'::jsonb,
    '{
      "Playing approach": ["chord charts", "notation", "both/mixed"],
      "Harmonic complexity": ["7ths", "9ths/11ths/13ths", "alterations/substitutions"],
      "Technical demands": ["moderate", "high", "very high"],
      "Two-hand independence": ["good", "very good", "mastered"],
      "Improvisation elements": ["none", "structured", "free improvisation"],
      "Style mastery": ["developing", "competent", "advanced"]
    }'::jsonb,
    ARRAY['Autumn Leaves', 'Blue Bossa'],
    true, 'Improvisation'
  );

  -- ===== DRUMS LEVELS =====

  -- Drums Level 1
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (drums_id, 1, 'Foundation', 'Basic drumming fundamentals and timing',
    '[
      "Basic rock beat (bass on 1&3, snare on 2&4)",
      "Consistent tempo with metronome",
      "4/4 time only",
      "Hi-hat, snare, bass drum coordination",
      "Simple fills (quarter notes on snare)"
    ]'::jsonb,
    '{
      "Basic beat": ["yes", "no"],
      "Tempo consistency": ["with metronome", "mostly steady", "very steady"],
      "Coordination": ["basic", "moderate", "good"],
      "Fills": ["none", "simple quarter notes", "eighth notes"],
      "Time signature": ["4/4 only", "includes other"]
    }'::jsonb,
    ARRAY['We Will Rock You', 'Billie Jean', 'Back in Black']
  );

  -- Drums Level 2
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (drums_id, 2, 'Pattern Development', 'Expanding beat vocabulary',
    '[
      "3-4 different basic beats",
      "Simple variations (ride cymbal, open hi-hat)",
      "8th note hi-hat patterns",
      "Basic fills using toms",
      "Introduction to dynamics (loud/soft)"
    ]'::jsonb,
    '{
      "Beat variations": ["1-2", "3-4", "5+"],
      "Hi-hat patterns": ["quarters only", "eighths", "sixteenths"],
      "Cymbal work": ["hi-hat only", "includes ride", "includes crashes"],
      "Fill complexity": ["simple", "moderate", "complex"],
      "Dynamics": ["static", "some variation", "dynamic"]
    }'::jsonb,
    ARRAY['Seven Nation Army', 'Smells Like Teen Spirit', 'Sweet Child O'' Mine']
  );

  -- Drums Level 3
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (drums_id, 3, 'Coordination & Fills', 'Advanced coordination and dynamic playing',
    '[
      "16th notes on hi-hat",
      "Multiple fill variations",
      "Crash cymbal accents",
      "Verse/chorus differentiation",
      "Ghost notes introduction"
    ]'::jsonb,
    '{
      "Hi-hat technique": ["eighths", "sixteenths", "variations"],
      "Fills": ["basic", "varied", "complex"],
      "Ghost notes": ["none", "some", "integrated"],
      "Song sections": ["minimal variation", "verse/chorus different", "multiple variations"],
      "Coordination": ["good", "very good", "excellent"]
    }'::jsonb,
    ARRAY['Uptown Funk', 'Superstition', 'Rosanna']
  );

  -- Drums Level 4A - Rock/Pop
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (drums_id, 4, 'Rock/Pop', 'Power drumming for rock and pop',
    '[
      "Power playing",
      "Tom work",
      "Dynamic builds",
      "Fills and transitions"
    ]'::jsonb,
    '{
      "Primary style": ["rock/pop", "funk/R&B", "punk/alternative"],
      "Tom work": ["basic", "moderate", "advanced"],
      "Dynamic builds": ["none", "some", "mastered"],
      "Time signatures": ["4/4 only", "includes 3/4 or 6/8", "odd meters"],
      "Speed": ["slow/medium", "medium/fast", "fast/very fast"]
    }'::jsonb,
    ARRAY['In the Air Tonight', 'When the Levee Breaks'],
    true, 'Rock/Pop'
  );

  -- Drums Level 4B - Funk/R&B
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (drums_id, 4, 'Funk/R&B', 'Groove-focused funk and R&B',
    '[
      "Ghost notes mastery",
      "Syncopation",
      "Groove pocket",
      "Linear patterns"
    ]'::jsonb,
    '{
      "Primary style": ["rock/pop", "funk/R&B", "punk/alternative"],
      "Ghost notes": ["basic", "moderate", "mastered"],
      "Groove pocket": ["developing", "good", "locked"],
      "Time signatures": ["4/4 only", "includes 3/4 or 6/8", "odd meters"],
      "Speed": ["slow/medium", "medium/fast", "fast/very fast"]
    }'::jsonb,
    ARRAY['Cissy Strut', 'Come Together'],
    true, 'Funk/R&B'
  );

  -- Drums Level 4C - Punk/Alternative
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (drums_id, 4, 'Punk/Alternative', 'High-energy punk and alternative',
    '[
      "Speed and intensity",
      "Creative fills",
      "Energy and drive",
      "Fast transitions"
    ]'::jsonb,
    '{
      "Primary style": ["rock/pop", "funk/R&B", "punk/alternative"],
      "Energy level": ["moderate", "high", "intense"],
      "Speed": ["moderate", "fast", "very fast"],
      "Time signatures": ["4/4 only", "includes 3/4 or 6/8", "odd meters"],
      "Speed": ["slow/medium", "medium/fast", "fast/very fast"]
    }'::jsonb,
    ARRAY['Everlong', 'Basket Case'],
    true, 'Punk/Alternative'
  );

  -- Drums Level 5A - Progressive/Complex
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (drums_id, 5, 'Progressive/Complex', 'Complex progressive drumming',
    '[
      "Odd time signatures",
      "Polyrhythms",
      "Technical fills",
      "Complex patterns"
    ]'::jsonb,
    '{
      "Advanced techniques": ["odd meters", "polyrhythms", "complex fills"],
      "Four-limb independence": ["basic", "good", "mastered"],
      "Time signatures": ["standard", "includes odd meters", "complex polyrhythms"],
      "Dynamics": ["basic", "expressive", "masterful"],
      "Style mastery": ["developing", "competent", "advanced"]
    }'::jsonb,
    ARRAY['Tom Sawyer', 'Schism'],
    true, 'Progressive/Complex'
  );

  -- Drums Level 5B - Jazz/Swing
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (drums_id, 5, 'Jazz/Swing', 'Jazz drumming and swing feel',
    '[
      "Swing feel",
      "Brushes",
      "Ride patterns",
      "Independence"
    ]'::jsonb,
    '{
      "Advanced techniques": ["swing feel", "brushes", "ride patterns", "comping"],
      "Four-limb independence": ["basic", "good", "mastered"],
      "Time signatures": ["standard", "includes odd meters", "complex polyrhythms"],
      "Dynamics": ["basic", "expressive", "masterful"],
      "Style mastery": ["developing", "competent", "advanced"]
    }'::jsonb,
    ARRAY['Take Five', 'My Favorite Things'],
    true, 'Jazz/Swing'
  );

  -- Drums Level 5C - Double Bass/Metal
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (drums_id, 5, 'Double Bass/Metal', 'Advanced double bass techniques',
    '[
      "Double bass drum",
      "Blast beats",
      "Speed techniques",
      "Aggressive playing"
    ]'::jsonb,
    '{
      "Advanced techniques": ["double bass", "blast beats", "speed runs", "aggressive fills"],
      "Four-limb independence": ["basic", "good", "mastered"],
      "Time signatures": ["standard", "includes odd meters", "complex polyrhythms"],
      "Dynamics": ["basic", "expressive", "masterful"],
      "Style mastery": ["developing", "competent", "advanced"]
    }'::jsonb,
    ARRAY['Hot for Teacher', 'YYZ'],
    true, 'Double Bass/Metal'
  );

  -- ===== VOCALS LEVELS =====

  -- Vocals Level 1
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (vocals_id, 1, 'Foundation', 'Basic singing fundamentals',
    '[
      "Simple melodies, limited range (octave or less)",
      "Clear pitch on repeated phrases",
      "Comfortable speaking/chest voice",
      "Basic breath support",
      "Singing along to familiar songs"
    ]'::jsonb,
    '{
      "Range": ["less than octave", "1 octave", "more than octave"],
      "Pitch accuracy": ["mostly accurate", "accurate", "very accurate"],
      "Breath control": ["basic", "moderate", "good"],
      "Melody complexity": ["very simple", "simple", "moderate"],
      "Confidence": ["developing", "moderate", "confident"]
    }'::jsonb,
    ARRAY['Happy Birthday', 'Lean on Me', 'Stand By Me']
  );

  -- Vocals Level 2
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (vocals_id, 2, 'Range Development', 'Expanding vocal range and dynamics',
    '[
      "Expanded range (1-1.5 octaves)",
      "Simple harmonies (thirds/fifths)",
      "Basic dynamics (loud/soft)",
      "Verse/chorus navigation",
      "Microphone technique introduction"
    ]'::jsonb,
    '{
      "Range": ["1 octave", "1-1.5 octaves", "1.5+ octaves"],
      "Harmonies": ["melody only", "simple harmonies", "complex harmonies"],
      "Dynamics": ["static", "some variation", "expressive"],
      "Song structure": ["single section", "verse/chorus", "multiple sections"],
      "Performance": ["basic", "developing", "moderate"]
    }'::jsonb,
    ARRAY['Let It Be', 'Hallelujah', 'Someone Like You']
  );

  -- Vocals Level 3
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs)
  VALUES (vocals_id, 3, 'Technique Building', 'Developing vocal control and expression',
    '[
      "Breath control developing",
      "Range: 1.5-2 octaves",
      "Smooth register transitions",
      "Sustained notes with vibrato",
      "Simple runs and melisma",
      "Performance confidence"
    ]'::jsonb,
    '{
      "Breath support": ["sustained notes", "phrases without breaks", "long passages"],
      "Register transitions": ["noticeable breaks", "smooth", "seamless"],
      "Vibrato": ["none", "developing", "controlled"],
      "Runs/melisma": ["none", "simple", "moderate"],
      "Expression": ["basic", "moderate", "good"]
    }'::jsonb,
    ARRAY['All of Me', 'Make You Feel My Love', 'Stay With Me']
  );

  -- Vocals Level 4A - Pop/Contemporary
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (vocals_id, 4, 'Pop/Contemporary', 'Modern pop vocal techniques',
    '[
      "Belt technique",
      "Runs and riffs",
      "Modern phrasing",
      "Power vocals"
    ]'::jsonb,
    '{
      "Primary style": ["pop/contemporary", "singer-songwriter", "soul/R&B"],
      "Belting": ["none", "developing", "strong"],
      "Runs/riffs": ["basic", "moderate", "advanced"],
      "Range": ["1.5-2 octaves", "2-2.5 octaves", "2.5+ octaves"],
      "Expression": ["good", "very good", "exceptional"]
    }'::jsonb,
    ARRAY['Rolling in the Deep', 'Grenade'],
    true, 'Pop/Contemporary'
  );

  -- Vocals Level 4B - Singer-Songwriter
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (vocals_id, 4, 'Singer-Songwriter', 'Intimate storytelling vocals',
    '[
      "Storytelling delivery",
      "Intimate expression",
      "Guitar + vocal coordination",
      "Nuanced phrasing"
    ]'::jsonb,
    '{
      "Primary style": ["pop/contemporary", "singer-songwriter", "soul/R&B"],
      "Storytelling": ["basic", "good", "masterful"],
      "Intimacy": ["moderate", "strong", "exceptional"],
      "Range": ["1.5-2 octaves", "2-2.5 octaves", "2.5+ octaves"],
      "Expression": ["good", "very good", "exceptional"]
    }'::jsonb,
    ARRAY['The A Team', 'Skinny Love'],
    true, 'Singer-Songwriter'
  );

  -- Vocals Level 4C - Soul/R&B
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (vocals_id, 4, 'Soul/R&B', 'Soul and R&B vocal style',
    '[
      "Power and emotion",
      "Improvisation",
      "Riffs and runs",
      "Gospel influences"
    ]'::jsonb,
    '{
      "Primary style": ["pop/contemporary", "singer-songwriter", "soul/R&B"],
      "Soul elements": ["basic", "moderate", "strong"],
      "Improvisation": ["none", "some", "extensive"],
      "Range": ["1.5-2 octaves", "2-2.5 octaves", "2.5+ octaves"],
      "Expression": ["good", "very good", "exceptional"]
    }'::jsonb,
    ARRAY['Ain''t No Sunshine', 'Respect'],
    true, 'Soul/R&B'
  );

  -- Vocals Level 5A - Powerful Vocals
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (vocals_id, 5, 'Powerful Vocals', 'Advanced belting and power',
    '[
      "Mixed voice",
      "Belting mastery",
      "Extended range (2+ octaves)",
      "Control at all dynamics"
    ]'::jsonb,
    '{
      "Advanced technique": ["mixed voice", "belting", "head voice", "whistle tone"],
      "Range control": ["2 octaves", "2.5 octaves", "3 octaves"],
      "Head voice/falsetto": ["basic", "developing", "mastered"],
      "Improvisation": ["none", "structured", "free"],
      "Performance quality": ["good", "very good", "professional"]
    }'::jsonb,
    ARRAY['I Will Always Love You', 'And I Am Telling You'],
    true, 'Powerful Vocals'
  );

  -- Vocals Level 5B - Nuanced Performance
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (vocals_id, 5, 'Nuanced Performance', 'Subtle control and interpretation',
    '[
      "Dynamics mastery",
      "Emotional delivery",
      "Interpretive skills",
      "Subtle control"
    ]'::jsonb,
    '{
      "Advanced technique": ["dynamics", "interpretation", "control", "emotion"],
      "Range control": ["2 octaves", "2.5 octaves", "3 octaves"],
      "Head voice/falsetto": ["basic", "developing", "mastered"],
      "Improvisation": ["none", "structured", "free"],
      "Performance quality": ["good", "very good", "professional"]
    }'::jsonb,
    ARRAY['The Blower''s Daughter', 'Hurt'],
    true, 'Nuanced Performance'
  );

  -- Vocals Level 5C - Improvisation
  INSERT INTO levels (instrument_id, level_number, name, description, skills_json, grading_checklist_json, example_songs, is_branch, branch_name)
  VALUES (vocals_id, 5, 'Improvisation', 'Vocal jazz and improvisation',
    '[
      "Scat singing",
      "Ornaments and runs",
      "Riffs",
      "Jazz phrasing"
    ]'::jsonb,
    '{
      "Advanced technique": ["scat", "jazz phrasing", "ornaments", "runs"],
      "Range control": ["2 octaves", "2.5 octaves", "3 octaves"],
      "Head voice/falsetto": ["basic", "developing", "mastered"],
      "Improvisation": ["none", "structured", "free"],
      "Performance quality": ["good", "very good", "professional"]
    }'::jsonb,
    ARRAY['At Last', 'Summertime'],
    true, 'Improvisation'
  );

END $$;

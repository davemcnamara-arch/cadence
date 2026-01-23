-- Update Piano grading checklists to include chord charts and piano pieces

-- Piano Level 1
UPDATE levels
SET grading_checklist_json = '{
  "Playing approach": ["chord chart only", "simple notation only", "both"],
  "Number of chords": ["2-3", "4-5", "6+"],
  "Hand coordination": ["separate hands", "hands together - simple", "hands together - complex"],
  "Left hand technique": ["single notes", "basic chords", "chord progressions"],
  "Right hand technique": ["single notes/chords", "simple melody", "melody + chords"],
  "Song structure": ["single section", "verse/chorus", "multiple sections"]
}'::jsonb
WHERE instrument_id = (SELECT id FROM instruments WHERE name = 'Piano')
  AND level_number = 1;

-- Piano Level 2
UPDATE levels
SET grading_checklist_json = '{
  "Playing approach": ["chord chart only", "notation only", "both"],
  "Number of chords": ["4-5", "6-7", "8+"],
  "Chord types": ["major/minor only", "includes 7ths", "extended chords"],
  "Patterns": ["block chords only", "arpeggios/broken chords", "mixed patterns"],
  "Hand independence": ["basic", "moderate", "advanced"],
  "Rhythm complexity": ["simple/steady", "some variation", "syncopated"],
  "Dynamics": ["none", "basic loud/soft", "expressive"]
}'::jsonb
WHERE instrument_id = (SELECT id FROM instruments WHERE name = 'Piano')
  AND level_number = 2;

-- Piano Level 3
UPDATE levels
SET grading_checklist_json = '{
  "Playing approach": ["chord chart only", "notation only", "both"],
  "Chord complexity": ["basic triads", "inversions", "7ths and inversions"],
  "Number of chords": ["6-8", "8-10", "10+"],
  "Pedal use": ["none", "basic sustain", "controlled pedaling"],
  "Accompaniment patterns": ["block chords", "alberti bass/arpeggios", "varied patterns"],
  "Hand independence": ["moderate", "good", "excellent"],
  "Expression/dynamics": ["basic", "moderate", "expressive"]
}'::jsonb
WHERE instrument_id = (SELECT id FROM instruments WHERE name = 'Piano')
  AND level_number = 3;

-- Piano Level 4A - Contemporary/Pop
UPDATE levels
SET grading_checklist_json = '{
  "Primary style": ["contemporary/pop", "singer-songwriter", "jazz/blues", "classical pieces"],
  "Playing approach": ["chord charts", "notation", "both/mixed"],
  "Chord voicings": ["basic triads", "7ths", "extended/jazz chords"],
  "Complexity": ["straightforward", "moderate", "complex arrangements"],
  "Modern elements": ["none", "some", "well integrated"],
  "Performance/expression": ["technique focus", "some expression", "fully expressive"]
}'::jsonb
WHERE instrument_id = (SELECT id FROM instruments WHERE name = 'Piano')
  AND level_number = 4
  AND branch_name = 'Contemporary/Pop';

-- Piano Level 4B - Singer-Songwriter
UPDATE levels
SET grading_checklist_json = '{
  "Primary style": ["contemporary/pop", "singer-songwriter", "jazz/blues", "classical pieces"],
  "Playing approach": ["chord charts", "notation", "both/mixed"],
  "Chord voicings": ["basic triads", "7ths", "extended/jazz chords"],
  "Complexity": ["straightforward", "moderate", "complex arrangements"],
  "Vocal integration": ["instrumental only", "basic accompaniment", "integrated with vocals"],
  "Performance/expression": ["technique focus", "some expression", "fully expressive"]
}'::jsonb
WHERE instrument_id = (SELECT id FROM instruments WHERE name = 'Piano')
  AND level_number = 4
  AND branch_name = 'Singer-Songwriter';

-- Piano Level 4C - Jazz/Blues
UPDATE levels
SET grading_checklist_json = '{
  "Primary style": ["contemporary/pop", "singer-songwriter", "jazz/blues", "classical pieces"],
  "Playing approach": ["chord charts", "notation", "both/mixed"],
  "Chord voicings": ["basic triads", "7ths", "extended/jazz chords"],
  "Complexity": ["straightforward", "moderate", "complex arrangements"],
  "Swing/groove": ["none", "basic feel", "strong swing/groove"],
  "Performance/expression": ["technique focus", "some expression", "fully expressive"]
}'::jsonb
WHERE instrument_id = (SELECT id FROM instruments WHERE name = 'Piano')
  AND level_number = 4
  AND branch_name = 'Jazz/Blues';

-- Piano Level 5A - Extended Chords
UPDATE levels
SET grading_checklist_json = '{
  "Playing approach": ["chord charts", "notation", "both/mixed"],
  "Harmonic complexity": ["7ths", "9ths/11ths/13ths", "alterations/substitutions"],
  "Technical demands": ["moderate", "high", "very high"],
  "Two-hand independence": ["good", "very good", "mastered"],
  "Improvisation elements": ["none", "structured", "free improvisation"],
  "Style mastery": ["developing", "competent", "advanced"]
}'::jsonb
WHERE instrument_id = (SELECT id FROM instruments WHERE name = 'Piano')
  AND level_number = 5
  AND branch_name = 'Extended Chords';

-- Piano Level 5B - Performance Skills
UPDATE levels
SET grading_checklist_json = '{
  "Playing approach": ["chord charts", "notation", "both/mixed"],
  "Harmonic complexity": ["7ths", "9ths/11ths/13ths", "alterations/substitutions"],
  "Technical demands": ["moderate", "high", "very high"],
  "Two-hand independence": ["good", "very good", "mastered"],
  "Improvisation elements": ["none", "structured", "free improvisation"],
  "Style mastery": ["developing", "competent", "advanced"]
}'::jsonb
WHERE instrument_id = (SELECT id FROM instruments WHERE name = 'Piano')
  AND level_number = 5
  AND branch_name = 'Performance Skills';

-- Piano Level 5C - Improvisation
UPDATE levels
SET grading_checklist_json = '{
  "Playing approach": ["chord charts", "notation", "both/mixed"],
  "Harmonic complexity": ["7ths", "9ths/11ths/13ths", "alterations/substitutions"],
  "Technical demands": ["moderate", "high", "very high"],
  "Two-hand independence": ["good", "very good", "mastered"],
  "Improvisation elements": ["none", "structured", "free improvisation"],
  "Style mastery": ["developing", "competent", "advanced"]
}'::jsonb
WHERE instrument_id = (SELECT id FROM instruments WHERE name = 'Piano')
  AND level_number = 5
  AND branch_name = 'Improvisation';

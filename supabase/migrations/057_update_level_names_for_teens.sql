-- Update level names and descriptions to be more approachable for 12-16 year olds
-- These match the updated labels in the grading questionnaire dropdowns

-- Guitar levels 1-3
UPDATE levels SET name = 'Getting Started', description = 'Learning your first chords and basic strumming'
WHERE level_number = 1 AND name = 'Foundation'
AND instrument_id = (SELECT id FROM instruments WHERE name = 'Guitar');

UPDATE levels SET name = 'Expanding Skills', description = 'Growing your chord knowledge and trying new things'
WHERE level_number = 2 AND name = 'Expanding Vocabulary'
AND instrument_id = (SELECT id FROM instruments WHERE name = 'Guitar');

UPDATE levels SET name = 'Building Technique', description = 'Picking up new techniques and expressing yourself musically'
WHERE level_number = 3 AND name = 'Technical Development'
AND instrument_id = (SELECT id FROM instruments WHERE name = 'Guitar');

-- Bass levels 1
UPDATE levels SET name = 'Getting Started', description = 'Learning the basics of bass and keeping time'
WHERE level_number = 1 AND name = 'Foundation'
AND instrument_id = (SELECT id FROM instruments WHERE name = 'Bass Guitar');

-- Piano levels 1
UPDATE levels SET name = 'Getting Started', description = 'Learning to use both hands and play simple melodies'
WHERE level_number = 1 AND name = 'Foundation'
AND instrument_id = (SELECT id FROM instruments WHERE name ILIKE '%piano%' OR name ILIKE '%keyboard%');

-- Drums levels 1-2
UPDATE levels SET name = 'Getting Started', description = 'Learning basic beats and keeping steady time'
WHERE level_number = 1 AND name = 'Foundation'
AND instrument_id = (SELECT id FROM instruments WHERE name = 'Drums');

UPDATE levels SET description = 'Learning more beat patterns'
WHERE level_number = 2 AND name = 'Pattern Development'
AND instrument_id = (SELECT id FROM instruments WHERE name = 'Drums');

-- Vocals level 1
UPDATE levels SET name = 'Getting Started', description = 'Learning the basics of singing'
WHERE level_number = 1 AND name = 'Foundation'
AND instrument_id = (SELECT id FROM instruments WHERE name = 'Vocals');

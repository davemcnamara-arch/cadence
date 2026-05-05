-- Add "Other Instrument" to the instruments table.
-- Students who play instruments not in the standard list (violin, clarinet, trumpet, etc.)
-- select this and then enter their specific instrument name.

INSERT INTO instruments (name, icon, description, display_order)
VALUES (
  'Other Instrument',
  '🎵',
  'For melody instruments not listed above — enter your specific instrument name when you add it',
  6
);

-- Add columns to support pre-populated suggested songs

ALTER TABLE songs
ADD COLUMN instrument_id UUID REFERENCES instruments(id) ON DELETE CASCADE,
ADD COLUMN suggested_level INTEGER;

-- Update the approved column to default true for pre-populated songs
-- (user-submitted songs will still default to false)

-- Add index for faster queries
CREATE INDEX idx_songs_instrument_level ON songs(instrument_id, suggested_level);

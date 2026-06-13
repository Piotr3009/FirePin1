-- FirePin Migration 002: Enhancements
-- Ports the valuable parts of the Codex prototype into the Supabase schema.
-- Run this in Supabase SQL Editor AFTER 001_initial_schema.sql.
-- Everything here is additive: it does not drop or rewrite existing tables/data.

-- ============================================
-- 1. NEW PROJECT STATUS: on_hold
-- ============================================
ALTER TYPE project_status ADD VALUE IF NOT EXISTS 'on_hold';

-- ============================================
-- 2. EXPANDED PRICING MODELS
-- Existing values stay and now mean:
--   per_unit          -> flat price per pin
--   per_m2            -> price per square metre (uses width_mm x height_mm)
--   per_metre         -> price per linear metre (uses diameter or longest side)
-- New values:
--   quantity_based    -> unit_price x quantity
--   base_plus_overage -> base_price + overage beyond an included area
--   manual_override   -> admin types the price by hand
-- ============================================
ALTER TYPE pricing_method ADD VALUE IF NOT EXISTS 'quantity_based';
ALTER TYPE pricing_method ADD VALUE IF NOT EXISTS 'base_plus_overage';
ALTER TYPE pricing_method ADD VALUE IF NOT EXISTS 'manual_override';

-- ============================================
-- 3. SYSTEM CATALOG: dimension matching + base/overage pricing + instructions + active flag
-- ============================================
ALTER TABLE system_catalog
  ADD COLUMN IF NOT EXISTS instructions        TEXT,
  ADD COLUMN IF NOT EXISTS min_width_mm        INTEGER,
  ADD COLUMN IF NOT EXISTS max_width_mm        INTEGER,
  ADD COLUMN IF NOT EXISTS min_height_mm       INTEGER,
  ADD COLUMN IF NOT EXISTS max_height_mm       INTEGER,
  ADD COLUMN IF NOT EXISTS min_diameter_mm     INTEGER,
  ADD COLUMN IF NOT EXISTS max_diameter_mm     INTEGER,
  ADD COLUMN IF NOT EXISTS base_price          NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS included_area_mm2   INTEGER,
  ADD COLUMN IF NOT EXISTS included_length_mm  INTEGER,
  ADD COLUMN IF NOT EXISTS overage_unit_price  NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS is_active           BOOLEAN NOT NULL DEFAULT true;

-- ============================================
-- 4. MARKERS: numeric dimensions, snapshots, confirmation
-- width_mm/height_mm/diameter_mm are needed so pricing can actually be calculated
-- (opening_size TEXT stays for free-text display / legacy).
-- *_snapshot columns freeze the system + price + instructions at the moment the pin
-- is filled in, so later catalog edits never change historical pins.
-- confirmed = false means an operative found this penetration on site and it is
-- awaiting admin review + pricing (shown PURPLE). Admin-created pins are confirmed.
-- ============================================
ALTER TABLE markers
  ADD COLUMN IF NOT EXISTS width_mm               INTEGER,
  ADD COLUMN IF NOT EXISTS height_mm              INTEGER,
  ADD COLUMN IF NOT EXISTS diameter_mm            INTEGER,
  ADD COLUMN IF NOT EXISTS quantity               INTEGER,
  ADD COLUMN IF NOT EXISTS system_snapshot_json   JSONB,
  ADD COLUMN IF NOT EXISTS price_calculation_json JSONB,
  ADD COLUMN IF NOT EXISTS instruction_snapshot   TEXT,
  ADD COLUMN IF NOT EXISTS confirmed              BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS confirmed_by           UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS confirmed_at           TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_markers_confirmed ON markers(confirmed);

COMMENT ON COLUMN markers.confirmed IS
  'false = pin created by an operative (penetration found on site), awaiting admin confirmation and pricing. Rendered purple until confirmed.';

-- ============================================
-- 5. DRAWINGS: revision number (UK drawings get re-issued often)
-- ============================================
ALTER TABLE drawings ADD COLUMN IF NOT EXISTS revision TEXT;

-- ============================================
-- 6. SAFE SERVER-SIDE MARKER NUMBERING (race-safe via per-project advisory lock)
-- Call from the app:  select next_marker_number('<project-uuid>');
-- ============================================
CREATE OR REPLACE FUNCTION next_marker_number(p_project_id UUID)
RETURNS TEXT AS $$
DECLARE
  max_n INTEGER;
BEGIN
  -- Serialize concurrent pin inserts within the same project.
  PERFORM pg_advisory_xact_lock(hashtext(p_project_id::text));

  SELECT COALESCE(MAX(CAST(SUBSTRING(marker_number FROM 'P-([0-9]+)') AS INTEGER)), 0)
    INTO max_n
  FROM markers
  WHERE project_id = p_project_id
    AND marker_number ~ '^P-[0-9]+$';

  RETURN 'P-' || LPAD((max_n + 1)::text, 3, '0');
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. RLS: operatives may CREATE pins in their own projects, but only UNCONFIRMED ones
-- Admins keep their existing "FOR ALL" policy (can create confirmed pins).
-- ============================================
DROP POLICY IF EXISTS "Operatives create unconfirmed pins" ON markers;
CREATE POLICY "Operatives create unconfirmed pins" ON markers
  FOR INSERT WITH CHECK (
    confirmed = false
    AND created_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM project_users
      WHERE project_id = markers.project_id AND user_id = auth.uid()
    )
  );

-- Tighten operative UPDATE: an operative can edit a pin assigned to them,
-- but cannot self-approve (only admins approve).
DROP POLICY IF EXISTS "Operatives update assigned markers" ON markers;
CREATE POLICY "Operatives update assigned markers" ON markers
  FOR UPDATE
  USING (assigned_to = auth.uid())
  WITH CHECK (assigned_to = auth.uid() AND status <> 'approved');

-- ============================================
-- 8. MONEY-SAFE CONFIRMATION: only admins can flip confirmed -> true.
-- Auto-stamps confirmed_by / confirmed_at on the confirming action.
-- ============================================
CREATE OR REPLACE FUNCTION enforce_pin_confirmation()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.confirmed = true AND (OLD.confirmed IS DISTINCT FROM true) THEN
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin') THEN
      RAISE EXCEPTION 'Only admins can confirm pins';
    END IF;
    NEW.confirmed_by := auth.uid();
    NEW.confirmed_at := now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_markers_confirm ON markers;
CREATE TRIGGER tr_markers_confirm
  BEFORE UPDATE ON markers
  FOR EACH ROW EXECUTE FUNCTION enforce_pin_confirmation();

-- FirePin Database Schema
-- Run this in Supabase SQL Editor

-- ============================================
-- ENUMS
-- ============================================
CREATE TYPE user_role AS ENUM ('admin', 'operative');
CREATE TYPE project_status AS ENUM ('active', 'completed', 'archived');
CREATE TYPE barrier_type AS ENUM ('wall', 'floor', 'ceiling');
CREATE TYPE service_type AS ENUM ('cable', 'pipe', 'duct', 'mixed', 'other');
CREATE TYPE marker_status AS ENUM ('new', 'in_progress', 'needs_remedial', 'approved');
CREATE TYPE compliance_status AS ENUM ('compliant', 'incomplete', 'non_compliant');
CREATE TYPE photo_type AS ENUM ('before', 'during', 'after', 'defect', 'extra');
CREATE TYPE pricing_method AS ENUM ('per_unit', 'per_metre', 'per_m2');

-- ============================================
-- USERS (extends Supabase Auth)
-- ============================================
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  role user_role NOT NULL DEFAULT 'operative',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- PROJECTS
-- ============================================
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  client_name TEXT,
  address TEXT,
  project_code TEXT,
  main_contractor TEXT,
  status project_status NOT NULL DEFAULT 'active',
  start_date DATE,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- PROJECT_USERS (operative assignment)
-- ============================================
CREATE TABLE project_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(project_id, user_id)
);

-- ============================================
-- FLOORS
-- ============================================
CREATE TABLE floors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  order_index INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- ZONES
-- ============================================
CREATE TABLE zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  floor_id UUID NOT NULL REFERENCES floors(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- DRAWINGS (PDF files per zone)
-- ============================================
CREATE TABLE drawings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  zone_id UUID REFERENCES zones(id) ON DELETE SET NULL,
  file_url TEXT NOT NULL,
  file_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- DRAWING_PAGES (individual pages of a PDF)
-- ============================================
CREATE TABLE drawing_pages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  drawing_id UUID NOT NULL REFERENCES drawings(id) ON DELETE CASCADE,
  page_number INTEGER NOT NULL,
  preview_image_url TEXT,
  width_px INTEGER,
  height_px INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- SYSTEM_CATALOG (fire stopping systems)
-- ============================================
CREATE TABLE system_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  manufacturer TEXT NOT NULL,
  system_reference TEXT NOT NULL,
  barrier_type barrier_type NOT NULL,
  service_type service_type NOT NULL,
  description TEXT,
  fire_rating_options INTEGER[] NOT NULL DEFAULT '{}',
  technical_drawing_url TEXT,
  unit_price NUMERIC(10,2),
  pricing_method pricing_method NOT NULL DEFAULT 'per_unit',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- MARKERS (pins on drawings)
-- ============================================
CREATE TABLE markers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  drawing_page_id UUID NOT NULL REFERENCES drawing_pages(id) ON DELETE CASCADE,
  zone_id UUID REFERENCES zones(id) ON DELETE SET NULL,
  marker_number TEXT NOT NULL,
  x_percent NUMERIC(5,2) NOT NULL,
  y_percent NUMERIC(5,2) NOT NULL,
  floor_label TEXT,
  zone_label TEXT,
  barrier_type barrier_type,
  service_type service_type,
  penetration_type TEXT,
  opening_size TEXT,
  wall_thickness TEXT,
  wall_material TEXT,
  manufacturer TEXT,
  system_reference TEXT,
  system_catalog_id UUID REFERENCES system_catalog(id) ON DELETE SET NULL,
  fire_rating INTEGER,
  estimated_price NUMERIC(10,2),
  status marker_status NOT NULL DEFAULT 'new',
  compliance_status compliance_status NOT NULL DEFAULT 'incomplete',
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  installation_date DATE,
  description TEXT,
  admin_notes TEXT,
  remedial_notes TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- MARKER_PHOTOS
-- ============================================
CREATE TABLE marker_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  marker_id UUID NOT NULL REFERENCES markers(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  photo_type photo_type NOT NULL,
  uploaded_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- MARKER_HISTORY (audit log)
-- ============================================
CREATE TABLE marker_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  marker_id UUID NOT NULL REFERENCES markers(id) ON DELETE CASCADE,
  changed_by UUID REFERENCES users(id),
  field_name TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- REPORTS
-- ============================================
CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  file_name TEXT,
  generated_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX idx_markers_project ON markers(project_id);
CREATE INDEX idx_markers_drawing_page ON markers(drawing_page_id);
CREATE INDEX idx_markers_assigned ON markers(assigned_to);
CREATE INDEX idx_markers_status ON markers(status);
CREATE INDEX idx_marker_photos_marker ON marker_photos(marker_id);
CREATE INDEX idx_floors_project ON floors(project_id);
CREATE INDEX idx_zones_floor ON zones(floor_id);
CREATE INDEX idx_zones_project ON zones(project_id);
CREATE INDEX idx_drawings_project ON drawings(project_id);
CREATE INDEX idx_drawing_pages_drawing ON drawing_pages(drawing_id);
CREATE INDEX idx_project_users_project ON project_users(project_id);
CREATE INDEX idx_project_users_user ON project_users(user_id);

-- ============================================
-- UPDATED_AT TRIGGER
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_projects_updated_at BEFORE UPDATE ON projects FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_markers_updated_at BEFORE UPDATE ON markers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_system_catalog_updated_at BEFORE UPDATE ON system_catalog FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- AUTO-CREATE USER ROW ON SIGNUP
-- ============================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
    NEW.email,
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'operative')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

-- Users table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view all users" ON users FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);

-- Projects table
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can do everything with projects" ON projects
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );
CREATE POLICY "Operatives can view assigned projects" ON projects
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM project_users WHERE project_id = projects.id AND user_id = auth.uid())
  );

-- Project users
ALTER TABLE project_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage project users" ON project_users
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );
CREATE POLICY "Operatives see own assignments" ON project_users
  FOR SELECT USING (user_id = auth.uid());

-- Floors
ALTER TABLE floors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage floors" ON floors
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );
CREATE POLICY "Operatives view project floors" ON floors
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM project_users WHERE project_id = floors.project_id AND user_id = auth.uid())
  );

-- Zones
ALTER TABLE zones ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage zones" ON zones
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );
CREATE POLICY "Operatives view project zones" ON zones
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM project_users WHERE project_id = zones.project_id AND user_id = auth.uid())
  );

-- Drawings
ALTER TABLE drawings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage drawings" ON drawings
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );
CREATE POLICY "Operatives view project drawings" ON drawings
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM project_users WHERE project_id = drawings.project_id AND user_id = auth.uid())
  );

-- Drawing pages
ALTER TABLE drawing_pages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage drawing pages" ON drawing_pages
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );
CREATE POLICY "Operatives view drawing pages" ON drawing_pages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM drawings d
      JOIN project_users pu ON pu.project_id = d.project_id
      WHERE d.id = drawing_pages.drawing_id AND pu.user_id = auth.uid()
    )
  );

-- System catalog (public read)
ALTER TABLE system_catalog ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view catalog" ON system_catalog FOR SELECT USING (true);
CREATE POLICY "Admins manage catalog" ON system_catalog
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

-- Markers
ALTER TABLE markers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage markers" ON markers
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );
CREATE POLICY "Operatives view assigned markers" ON markers
  FOR SELECT USING (assigned_to = auth.uid());
CREATE POLICY "Operatives update assigned markers" ON markers
  FOR UPDATE USING (assigned_to = auth.uid());

-- Marker photos
ALTER TABLE marker_photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage photos" ON marker_photos
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );
CREATE POLICY "Operatives manage photos on assigned markers" ON marker_photos
  FOR ALL USING (
    EXISTS (SELECT 1 FROM markers WHERE id = marker_photos.marker_id AND assigned_to = auth.uid())
  );

-- Marker history
ALTER TABLE marker_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins view history" ON marker_history
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );
CREATE POLICY "Operatives view own marker history" ON marker_history
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM markers WHERE id = marker_history.marker_id AND assigned_to = auth.uid())
  );

-- Reports
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage reports" ON reports
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

-- ============================================
-- STORAGE BUCKETS
-- ============================================
INSERT INTO storage.buckets (id, name, public) VALUES ('drawings', 'drawings', false);
INSERT INTO storage.buckets (id, name, public) VALUES ('photos', 'photos', false);
INSERT INTO storage.buckets (id, name, public) VALUES ('reports', 'reports', false);
INSERT INTO storage.buckets (id, name, public) VALUES ('catalog', 'catalog', true);

-- Storage policies
CREATE POLICY "Authenticated users can upload drawings" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'drawings' AND auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can view drawings" ON storage.objects
  FOR SELECT USING (bucket_id = 'drawings' AND auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can upload photos" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'photos' AND auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can view photos" ON storage.objects
  FOR SELECT USING (bucket_id = 'photos' AND auth.role() = 'authenticated');

CREATE POLICY "Admins can upload reports" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'reports' AND auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can view reports" ON storage.objects
  FOR SELECT USING (bucket_id = 'reports' AND auth.role() = 'authenticated');

CREATE POLICY "Anyone can view catalog" ON storage.objects
  FOR SELECT USING (bucket_id = 'catalog');
CREATE POLICY "Admins can upload to catalog" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'catalog' AND auth.role() = 'authenticated');

-- ============================================
-- SEED DATA: Quelfire System Catalog
-- ============================================
INSERT INTO system_catalog (manufacturer, system_reference, barrier_type, service_type, description, fire_rating_options, unit_price, pricing_method) VALUES
  ('Quelfire', 'QB-FW100-P-02', 'wall', 'cable', 'Cable penetrating flexible/rigid wall 100mm+', '{30,60,120}', 45.00, 'per_unit'),
  ('Quelfire', 'QB-RW150-D-08', 'wall', 'pipe', 'Plastic pipe penetrating rigid wall 150mm+', '{30,60,120,240}', 65.00, 'per_unit'),
  ('Quelfire', 'QFP-FW75-07', 'wall', 'duct', 'Cable trunking penetrating flexible/rigid wall 75mm+', '{30,60}', 55.00, 'per_unit'),
  ('Quelfire', 'PP-FW100-01', 'wall', 'cable', 'Socket box in flexible wall 100mm+ (single)', '{30,60}', 25.00, 'per_unit'),
  ('Quelfire', 'PP-FW100-02', 'wall', 'cable', 'Socket box in flexible wall 100mm+ (back-to-back)', '{30,60}', 35.00, 'per_unit');

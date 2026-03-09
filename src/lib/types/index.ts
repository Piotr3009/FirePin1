// ============================================
// ENUMS
// ============================================
export type UserRole = 'admin' | 'operative'
export type ProjectStatus = 'active' | 'completed' | 'archived'
export type BarrierType = 'wall' | 'floor' | 'ceiling'
export type ServiceType = 'cable' | 'pipe' | 'duct' | 'mixed' | 'other'
export type MarkerStatus = 'new' | 'in_progress' | 'needs_remedial' | 'approved'
export type ComplianceStatus = 'compliant' | 'incomplete' | 'non_compliant'
export type PhotoType = 'before' | 'during' | 'after' | 'defect' | 'extra'
export type PricingMethod = 'per_unit' | 'per_metre' | 'per_m2'

// ============================================
// DATABASE TYPES
// ============================================
export interface User {
  id: string
  name: string
  email: string
  role: UserRole
  created_at: string
  updated_at: string
}

export interface Project {
  id: string
  name: string
  client_name: string | null
  address: string | null
  project_code: string | null
  main_contractor: string | null
  status: ProjectStatus
  start_date: string | null
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface ProjectUser {
  id: string
  project_id: string
  user_id: string
  created_at: string
}

export interface Floor {
  id: string
  project_id: string
  name: string
  order_index: number
  created_at: string
}

export interface Zone {
  id: string
  floor_id: string
  project_id: string
  name: string
  created_at: string
}

export interface Drawing {
  id: string
  project_id: string
  zone_id: string | null
  file_url: string
  file_name: string | null
  created_at: string
}

export interface DrawingPage {
  id: string
  drawing_id: string
  page_number: number
  preview_image_url: string | null
  width_px: number | null
  height_px: number | null
  created_at: string
}

export interface SystemCatalogItem {
  id: string
  manufacturer: string
  system_reference: string
  barrier_type: BarrierType
  service_type: ServiceType
  description: string | null
  fire_rating_options: number[]
  technical_drawing_url: string | null
  unit_price: number | null
  pricing_method: PricingMethod
  created_at: string
  updated_at: string
}

export interface Marker {
  id: string
  project_id: string
  drawing_page_id: string
  zone_id: string | null
  marker_number: string
  x_percent: number
  y_percent: number
  floor_label: string | null
  zone_label: string | null
  barrier_type: BarrierType | null
  service_type: ServiceType | null
  penetration_type: string | null
  opening_size: string | null
  wall_thickness: string | null
  wall_material: string | null
  manufacturer: string | null
  system_reference: string | null
  system_catalog_id: string | null
  fire_rating: number | null
  estimated_price: number | null
  status: MarkerStatus
  compliance_status: ComplianceStatus
  assigned_to: string | null
  installation_date: string | null
  description: string | null
  admin_notes: string | null
  remedial_notes: string | null
  created_by: string | null
  created_at: string
  updated_at: string
  // Joined data
  photos?: MarkerPhoto[]
  assigned_user?: User | null
}

export interface MarkerPhoto {
  id: string
  marker_id: string
  photo_url: string
  photo_type: PhotoType
  uploaded_by: string | null
  created_at: string
}

export interface MarkerHistory {
  id: string
  marker_id: string
  changed_by: string | null
  field_name: string
  old_value: string | null
  new_value: string | null
  created_at: string
}

export interface Report {
  id: string
  project_id: string
  file_url: string
  file_name: string | null
  generated_by: string | null
  created_at: string
}

// ============================================
// FORM TYPES
// ============================================
export interface ProjectFormData {
  name: string
  client_name: string
  address: string
  project_code: string
  main_contractor: string
  start_date: string
}

export interface FloorFormData {
  name: string
  order_index: number
}

export interface ZoneFormData {
  name: string
  floor_id: string
}

// ============================================
// PIN STATUS COLORS
// ============================================
export const MARKER_STATUS_COLORS: Record<MarkerStatus, string> = {
  new: '#9CA3AF',           // Grey
  in_progress: '#3B82F6',   // Blue
  needs_remedial: '#F59E0B', // Amber
  approved: '#22C55E',      // Green
}

export const MARKER_STATUS_LABELS: Record<MarkerStatus, string> = {
  new: 'New',
  in_progress: 'In Progress',
  needs_remedial: 'Needs Remedial',
  approved: 'Approved',
}

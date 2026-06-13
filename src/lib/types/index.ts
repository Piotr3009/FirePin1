// ============================================
// ENUMS
// ============================================
export type UserRole = 'admin' | 'operative'
export type ProjectStatus = 'active' | 'on_hold' | 'completed' | 'archived'
export type BarrierType = 'wall' | 'floor' | 'ceiling'
export type ServiceType = 'cable' | 'pipe' | 'duct' | 'mixed' | 'other'
export type MarkerStatus = 'new' | 'in_progress' | 'needs_remedial' | 'approved'
export type ComplianceStatus = 'compliant' | 'incomplete' | 'non_compliant'
export type PhotoType = 'before' | 'during' | 'after' | 'defect' | 'extra'
export type PricingMethod =
  | 'per_unit'           // flat price per pin
  | 'per_metre'          // £ per linear metre (uses diameter or longest side)
  | 'per_m2'             // £ per square metre (uses width × height)
  | 'quantity_based'     // unit_price × quantity
  | 'base_plus_overage'  // base_price + overage beyond an included area
  | 'manual_override'    // admin types the price by hand

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
  revision: string | null
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
  instructions: string | null
  fire_rating_options: number[]
  technical_drawing_url: string | null
  // Dimension matching (any may be null = unconstrained)
  min_width_mm: number | null
  max_width_mm: number | null
  min_height_mm: number | null
  max_height_mm: number | null
  min_diameter_mm: number | null
  max_diameter_mm: number | null
  // Pricing
  pricing_method: PricingMethod
  unit_price: number | null
  base_price: number | null
  included_area_mm2: number | null
  included_length_mm: number | null
  overage_unit_price: number | null
  is_active: boolean
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
  opening_size: string | null      // free-text, kept for display/legacy
  // Numeric dimensions (drive pricing + system matching)
  width_mm: number | null
  height_mm: number | null
  diameter_mm: number | null
  quantity: number | null
  wall_thickness: string | null
  wall_material: string | null
  manufacturer: string | null
  system_reference: string | null
  system_catalog_id: string | null
  fire_rating: number | null
  estimated_price: number | null
  // Snapshots: frozen at fill-in time so later catalog edits don't change history
  system_snapshot_json: Record<string, unknown> | null
  price_calculation_json: Record<string, unknown> | null
  instruction_snapshot: string | null
  status: MarkerStatus
  compliance_status: ComplianceStatus
  // Confirmation: false = operative-found pin awaiting admin review + pricing
  confirmed: boolean
  confirmed_by: string | null
  confirmed_at: string | null
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

// Operative-found pins awaiting admin confirmation are shown purple,
// regardless of their work status.
export const MARKER_UNCONFIRMED_COLOR = '#A855F7' // Purple

/**
 * The colour a pin should render on the plan.
 * Unconfirmed (operative-found) pins are always purple until an admin confirms.
 */
export function pinColor(marker: Pick<Marker, 'confirmed' | 'status'>): string {
  if (!marker.confirmed) return MARKER_UNCONFIRMED_COLOR
  return MARKER_STATUS_COLORS[marker.status]
}

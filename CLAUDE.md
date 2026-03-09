# FirePin – Claude Code Instructions

## Project Overview
FirePin is a mobile web app (PWA) for fire stopping teams in the UK.
It allows admins to create construction projects, upload PDF drawings, place pins on plans (fire penetration points), assign them to workers, and generate professional PDF reports.
Operatives see only their assigned pins, do the work, take photos, and update status.

## Tech Stack
- **Framework**: Next.js 14 with App Router
- **Language**: TypeScript (strict mode always on)
- **UI**: Tailwind CSS + shadcn/ui
- **Backend/DB/Auth**: Supabase (PostgreSQL + Auth + Storage)
- **PDF Viewer**: pdfjs-dist
- **PDF Reports**: @react-pdf/renderer
- **Photo compression**: browser-image-compression
- **State**: Zustand
- **Forms**: React Hook Form + Zod
- **Deployment**: Vercel

## Roles
- **Admin**: creates projects, uploads drawings, creates pins, assigns pins to operatives, approves/rejects work, generates reports
- **Operative**: sees only assigned pins, views system technical drawing, uploads completion photos, updates status

## Build Commands
```bash
npm run dev       # development server
npm run build     # production build
npm run lint      # ESLint
```

## Project Structure
```
src/
├── app/
│   ├── (auth)/login/page.tsx
│   ├── (dashboard)/
│   │   ├── layout.tsx
│   │   ├── projects/page.tsx
│   │   ├── projects/new/page.tsx
│   │   └── projects/[id]/
│   │       ├── page.tsx
│   │       ├── drawings/[drawingId]/page.tsx
│   │       ├── markers/page.tsx
│   │       └── report/page.tsx
│   ├── admin/
│   │   ├── users/page.tsx
│   │   └── catalog/page.tsx
│   └── api/
│       ├── auth/callback/route.ts
│       ├── pdf-preview/route.ts
│       └── reports/generate/route.ts
├── components/
│   ├── auth/LoginForm.tsx
│   ├── projects/ProjectCard.tsx
│   ├── drawings/DrawingUpload.tsx
│   ├── viewer/PDFViewer.tsx          ← MOST IMPORTANT COMPONENT
│   ├── viewer/PinOverlay.tsx
│   ├── markers/MarkerForm.tsx
│   ├── markers/MarkerList.tsx
│   ├── photos/PhotoUpload.tsx
│   └── reports/ReportPDF.tsx
├── lib/
│   ├── supabase/client.ts
│   ├── supabase/server.ts
│   ├── hooks/useMarkers.ts
│   ├── hooks/useProjects.ts
│   ├── utils/compliance.ts
│   ├── utils/markerNumber.ts
│   ├── utils/priceCalc.ts
│   └── types/index.ts
└── middleware.ts
```

## Database Tables
- `users` – extends Supabase Auth (id, name, email, role: admin|operative)
- `projects` – (id, name, client_name, address, project_code, main_contractor, status, start_date)
- `project_users` – operative assignment to project
- `floors` – (id, project_id, name, order_index)
- `zones` – (id, floor_id, project_id, name)
- `drawings` – PDF files per zone (id, project_id, zone_id, file_url)
- `drawing_pages` – pages of PDF (id, drawing_id, page_number, preview_image_url, width_px, height_px)
- `system_catalog` – fire stopping systems (id, manufacturer, system_reference, barrier_type, service_type, fire_rating_options[], technical_drawing_url, unit_price, pricing_method)
- `markers` – pins on drawing (see full schema below)
- `marker_photos` – (id, marker_id, photo_url, photo_type: before|during|after|defect|extra)
- `marker_history` – audit log per pin
- `reports` – generated PDF reports

## Markers Table (full schema)
```sql
markers (
  id, project_id, drawing_page_id, zone_id,
  marker_number TEXT,       -- auto: P-001, P-002...
  x_percent NUMERIC(5,2),   -- position 0-100 (NEVER pixels)
  y_percent NUMERIC(5,2),   -- position 0-100 (NEVER pixels)
  floor_label, zone_label,
  barrier_type: wall|floor|ceiling,
  service_type: cable|pipe|duct|mixed|other,
  penetration_type, opening_size, wall_thickness, wall_material,
  manufacturer, system_reference, system_catalog_id,
  fire_rating INTEGER,
  estimated_price NUMERIC,
  status: new|in_progress|needs_remedial|approved,
  compliance_status: compliant|incomplete|non_compliant,
  assigned_to UUID,
  installation_date,
  description TEXT,         -- AUTO-GENERATED from form data
  admin_notes, remedial_notes,
  created_by, created_at, updated_at
)
```

## Pin Status & Colors
- `new` → Grey
- `in_progress` → Blue
- `needs_remedial` → Amber/Yellow
- `approved` → Green

## Critical Rules

### PDF Viewer (most important)
- NEVER store pin position in pixels. Always use x_percent and y_percent (0-100).
- Pin must stay in the same position at any zoom level.
- Render PDF pages with pdfjs-dist on `<canvas>` element.
- Pin overlay is absolutely positioned SVG on top of canvas.
- Zoom: pinch-to-zoom mobile, scroll desktop, range 50%-400%.
- Calculate pin position from percent:
```typescript
// On click - save:
const x_percent = ((e.clientX - rect.left) / rect.width) * 100
const y_percent = ((e.clientY - rect.top) / rect.height) * 100

// Render pin (CSS):
style={{ left: `${marker.x_percent}%`, top: `${marker.y_percent}%`, transform: 'translate(-50%, -50%)', position: 'absolute' }}
```

### Photos
- Always compress before upload:
```typescript
import imageCompression from 'browser-image-compression'
const compressed = await imageCompression(file, { maxSizeMB: 1, maxWidthOrHeight: 1920, useWebWorker: true })
```

### Supabase Storage
- Always use signed URLs for private buckets (photos, drawings, reports)
- Bucket `catalog` is public (technical drawings)

### General
- TypeScript strict mode always on
- Every component has defined Props interface
- All Supabase queries with error handling
- Use Server Components where possible
- Loading states on all async operations
- Toast notifications on every action
- Mobile first – test on 390px (iPhone 12)
- Min button height on mobile: 48px

## Compliance Logic
```typescript
function checkCompliance(marker): 'compliant' | 'incomplete' | 'non_compliant' {
  const hasAfterPhoto = marker.photos?.some(p => p.photo_type === 'after')
  const hasSystem = !!marker.system_reference && !!marker.manufacturer
  const hasRating = !!marker.fire_rating
  const hasInstaller = !!marker.assigned_to
  if (marker.status === 'approved') {
    if (!hasAfterPhoto || !hasSystem || !hasRating || !hasInstaller) return 'non_compliant'
    return 'compliant'
  }
  if (!hasSystem || !hasRating || !hasInstaller) return 'incomplete'
  if (hasAfterPhoto && hasSystem && hasRating && hasInstaller) return 'compliant'
  return 'incomplete'
}
```

## Auto-generated Description
Generate description text automatically from marker data (like Dalux does – user never types it manually):
```typescript
function generateDescription(marker: Marker): string {
  const parts = []
  if (marker.service_type === 'pipe') {
    parts.push(`There was a ${marker.opening_size || ''} ${marker.wall_material || ''} pipe penetrating a ${marker.fire_rating || ''} minute fire rated ${marker.barrier_type || ''}.`)
  } else if (marker.service_type === 'cable') {
    parts.push(`There were cables penetrating a ${marker.fire_rating || ''} minute fire rated ${marker.barrier_type || ''}.`)
  }
  if (marker.wall_thickness) parts.push(`The wall thickness is ${marker.wall_thickness}.`)
  if (marker.system_reference && marker.manufacturer) {
    parts.push(`CE marked ${marker.manufacturer} materials have been used.`)
    parts.push(`The installed apparatus is therefore in accordance with ${marker.manufacturer}'s approved and tested detail no. ${marker.system_reference}, and restores the appropriate fire rating to the compartment.`)
  }
  return parts.join(' ')
}
```

## Build Order – FOLLOW THIS EXACTLY

### Phase 1 – Foundation
1. Next.js setup + install all dependencies
2. Supabase client/server/middleware config
3. All SQL migrations (ENUMs, tables, RLS, storage, trigger)
4. Create folder structure
5. Define all TypeScript types
6. Login screen with Supabase Auth
7. Dashboard layout with navigation
8. Projects list + CRUD
9. New project form
10. Floors and zones management
**Checkpoint: Admin can log in, create project with floors and zones**

### Phase 2 – Drawings & PDF Viewer
1. PDF upload to Supabase Storage
2. Generate page previews with pdfjs-dist
3. Save drawing_pages to DB
4. PDFViewer component: canvas rendering, zoom, pan
5. SVG pin overlay on canvas
6. Click empty area → save x_percent/y_percent → open MarkerForm
7. Click existing pin → open MarkerForm in edit mode
**Checkpoint: Admin sees PDF, can click to create a pin**

### Phase 3 – Marker Form & Photos
1. Full marker form (all sections)
2. System catalog dropdown (filter by barrier_type + service_type)
3. Auto-pricing on system selection
4. Technical drawing visible in form
5. Auto-generated description text
6. Photo upload with compression
7. Compliance check on every save
8. Pin colors by status on PDF Viewer
9. Markers list with filters
**Checkpoint: Admin creates full pin, assigns operative, operative sees their pin**

### Phase 4 – PDF Report
1. ReportPDF.tsx with @react-pdf/renderer
2. Cover, summary, pin details, photos
3. Auto-generated description in report
4. Plan thumbnail with pin marked
5. Generate and save to Supabase Storage
6. Report screen with download
**Checkpoint: Admin generates PDF report ready to send to client**

### Phase 5 – Admin Tools
1. System catalog CRUD
2. Upload technical drawings
3. User management (list, change role)
4. Invite user via Supabase
5. UX improvements
6. PWA manifest

## PDF Report Structure
1. Cover page: FirePin logo, project name, client, address, date
2. Summary: total pins, breakdown by status, by floor/zone, total price
3. Per-pin pages: marker number, status, location, plan thumbnail with pin, data table, system, auto-description, before+after photos
4. Last page: open items list, remedials list, total price, signature block

## Known System Catalog (Quelfire – seed data)
- QB-FW100-P-02 – Cable penetrating flexible/rigid wall 100mm+
- QB-RW150-D-08 – Plastic pipe penetrating rigid wall 150mm+
- QFP-FW75-07 – Cable trunking penetrating flexible/rigid wall 75mm+
- PP-FW100-01 – Socket box in flexible wall 100mm+ (single)
- PP-FW100-02 – Socket box in flexible wall 100mm+ (back-to-back)

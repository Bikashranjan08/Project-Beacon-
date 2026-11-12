-- 

-- Enable UUID extension for auto-generating unique IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Workspaces Table
CREATE TABLE IF NOT EXISTS workspaces (
  id TEXT PRIMARY KEY, -- Corresponds to user's organizationId or 'personal'
  owner_id TEXT,       -- Corresponds to owner user ID
  name TEXT NOT NULL,
  plan_tier TEXT DEFAULT 'free',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE workspaces ADD COLUMN IF NOT EXISTS owner_id TEXT;
ALTER TABLE workspaces ADD COLUMN IF NOT EXISTS plan_tier TEXT DEFAULT 'free';

-- 2. Profiles Table (Holds independent users synced with Supabase Auth)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY, -- References auth.users(id) in Supabase Auth
  email TEXT NOT NULL UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Workspace Members Table (Links users/emails to workspaces)
CREATE TABLE IF NOT EXISTS workspace_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL, -- e.g., OWNER, PM, DEVELOPER, CLIENT, VIEWER
  custom_title TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Team Invitations Table (Pending invitations to workspaces)
CREATE TABLE IF NOT EXISTS team_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  code TEXT NOT NULL, -- Access code, e.g., PT-XXXXXX
  organization_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  custom_title TEXT,
  accepted BOOLEAN DEFAULT FALSE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Projects Table
CREATE TABLE IF NOT EXISTS projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  portfolio_id UUID, -- For future portfolio grouping features
  organization_id TEXT NOT NULL DEFAULT 'default_org',
  name TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'SOFTWARE', -- Holds project_type (e.g., SOFTWARE, CONSTRUCTION, EVENT, etc.)
  color TEXT NOT NULL DEFAULT 'ON_TRACK', -- Holds health_status (e.g., ON_TRACK, AT_RISK, CRITICAL)
  deadline TIMESTAMP WITH TIME ZONE,
  status_config JSONB DEFAULT '[]'::jsonb, -- Custom board statuses configuration
  custom_fields JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. Project Members Table (Users assigned to specific projects)
CREATE TABLE IF NOT EXISTS project_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL, -- PM, DEVELOPER, etc.
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. Tasks Table
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  milestone_id UUID, -- For future milestone features
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL, -- Custom board column ID/status
  priority TEXT NOT NULL DEFAULT 'MEDIUM', -- LOW, MEDIUM, HIGH, CRITICAL
  assignee_id TEXT, -- User ID or email of assignee
  due_date TIMESTAMP WITH TIME ZONE,
  estimate_minutes INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. Activity Logs Table (For audit tracking)
CREATE TABLE IF NOT EXISTS activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  task_id UUID REFERENCES tasks(id) ON DELETE SET NULL,
  actor_email TEXT NOT NULL,
  actor_name TEXT NOT NULL,
  action TEXT NOT NULL, -- e.g., task_created, status_changed, etc.
  details TEXT,
  old_value TEXT,
  new_value TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 9. Notifications Queue Table (Holds realtime push-oriented app alerts)
CREATE TABLE IF NOT EXISTS notifications_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT, -- Target owner/member email or ID
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  read BOOLEAN DEFAULT FALSE NOT NULL,
  data JSONB DEFAULT '{}'::jsonb, -- Holds dynamic payload (type, task_id, project_id, user_name, timestamp)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ==========================================
-- INDEXES FOR QUERY OPTIMIZATION
-- ==========================================
CREATE INDEX IF NOT EXISTS idx_workspace_members_workspace ON workspace_members(workspace_id);
CREATE INDEX IF NOT EXISTS idx_workspace_members_email ON workspace_members(email);
CREATE INDEX IF NOT EXISTS idx_team_invitations_org ON team_invitations(organization_id);
CREATE INDEX IF NOT EXISTS idx_team_invitations_email_code ON team_invitations(email, code);
CREATE INDEX IF NOT EXISTS idx_projects_workspace ON projects(workspace_id);
CREATE INDEX IF NOT EXISTS idx_project_members_project ON project_members(project_id);
CREATE INDEX IF NOT EXISTS idx_project_members_email ON project_members(email);
CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_project ON activity_logs(project_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications_queue(user_id);

-- ==========================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Allows the app (using anon key) to read and write
-- ==========================================
ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public access on workspaces" ON workspaces;
CREATE POLICY "Public access on workspaces" ON workspaces FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public access on profiles" ON profiles;
CREATE POLICY "Public access on profiles" ON profiles FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public access on workspace_members" ON workspace_members;
CREATE POLICY "Public access on workspace_members" ON workspace_members FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public access on team_invitations" ON team_invitations;
CREATE POLICY "Public access on team_invitations" ON team_invitations FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public access on projects" ON projects;
CREATE POLICY "Public access on projects" ON projects FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public access on project_members" ON project_members;
CREATE POLICY "Public access on project_members" ON project_members FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public access on tasks" ON tasks;
CREATE POLICY "Public access on tasks" ON tasks FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public access on activity_logs" ON activity_logs;
CREATE POLICY "Public access on activity_logs" ON activity_logs FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public access on notifications_queue" ON notifications_queue;
CREATE POLICY "Public access on notifications_queue" ON notifications_queue FOR ALL USING (true) WITH CHECK (true);

-- ==========================================
-- DEMO SEED DATA (Run to populate demo database)
-- ==========================================

-- 1. Demo Workspaces
INSERT INTO workspaces (id, owner_id, name, plan_tier)
VALUES 
  ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'Beacon Engineering HQ', 'enterprise'),
  ('personal', NULL, 'Personal Workspace', 'free')
ON CONFLICT (id) DO UPDATE 
SET name = EXCLUDED.name, plan_tier = EXCLUDED.plan_tier;

-- 2. Demo Profiles
INSERT INTO profiles (id, email, full_name, avatar_url)
VALUES
  ('b0000000-0000-0000-0000-000000000001', 'alex.morgan@beacon.io', 'Alex Morgan', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150'),
  ('b0000000-0000-0000-0000-000000000002', 'david.chen@beacon.io', 'David Chen', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150'),
  ('b0000000-0000-0000-0000-000000000003', 'sarah.kim@beacon.io', 'Sarah Kim', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150')
ON CONFLICT (id) DO UPDATE
SET full_name = EXCLUDED.full_name, email = EXCLUDED.email;

-- 3. Demo Workspace Members
INSERT INTO workspace_members (id, workspace_id, email, role, custom_title)
VALUES
  ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'alex.morgan@beacon.io', 'OWNER', 'Principal Architect'),
  ('d0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'david.chen@beacon.io', 'DEVELOPER', 'Senior Backend Engineer'),
  ('d0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'sarah.kim@beacon.io', 'PM', 'Lead Product Manager')
ON CONFLICT (id) DO NOTHING;

-- 4. Demo Team Invitations (Instant access via Team Member tab on /login)
INSERT INTO team_invitations (id, email, code, organization_id, role, custom_title, accepted)
VALUES
  ('e0000000-0000-0000-0000-000000000001', 'alex.morgan@beacon.io', 'PT-OWNER-01', 'a0000000-0000-0000-0000-000000000001', 'OWNER', 'Principal Architect', false),
  ('e0000000-0000-0000-0000-000000000002', 'sarah.kim@beacon.io', 'PT-PM-01', 'a0000000-0000-0000-0000-000000000001', 'PM', 'Technical Project Manager', false),
  ('e0000000-0000-0000-0000-000000000003', 'david.chen@beacon.io', 'PT-DEV-01', 'a0000000-0000-0000-0000-000000000001', 'DEVELOPER', 'Senior Backend Engineer', false),
  ('e0000000-0000-0000-0000-000000000004', 'james.wilson@beacon.io', 'PT-948215', 'a0000000-0000-0000-0000-000000000001', 'DEVELOPER', 'Fullstack Engineer', false)
ON CONFLICT (id) DO NOTHING;

-- 5. Demo Projects
INSERT INTO projects (id, workspace_id, name, description, status, color, deadline, status_config)
VALUES
  (
    'c0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    'Project Beacon Core v2.0',
    'Autonomous project intelligence engine featuring real-time collaborative kanban and neural risk forecasts.',
    'SOFTWARE',
    'ON_TRACK',
    timezone('utc'::text, now() + interval '45 days'),
    '[
      {"id": "idea", "label": "Idea", "color": "slate", "order": 0, "category": "todo"},
      {"id": "todo", "label": "Planned", "color": "blue", "order": 1, "category": "todo"},
      {"id": "in_progress", "label": "In Progress", "color": "amber", "order": 2, "category": "in_progress"},
      {"id": "review", "label": "Review", "color": "purple", "order": 3, "category": "review"},
      {"id": "completed", "label": "Completed", "color": "green", "order": 4, "category": "done"}
    ]'::jsonb
  ),
  (
    'c0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000001',
    'Mobile Companion App',
    'Cross-platform iOS and Android application with offline board caching and push sync.',
    'SOFTWARE',
    'AT_RISK',
    timezone('utc'::text, now() + interval '18 days'),
    '[
      {"id": "idea", "label": "Idea", "color": "slate", "order": 0, "category": "todo"},
      {"id": "todo", "label": "Planned", "color": "blue", "order": 1, "category": "todo"},
      {"id": "in_progress", "label": "In Progress", "color": "amber", "order": 2, "category": "in_progress"},
      {"id": "review", "label": "Review", "color": "purple", "order": 3, "category": "review"},
      {"id": "completed", "label": "Completed", "color": "green", "order": 4, "category": "done"}
    ]'::jsonb
  ),
  (
    'c0000000-0000-0000-0000-000000000003',
    'a0000000-0000-0000-0000-000000000001',
    'SOC2 Type II Audit & Hardening',
    'Security compliance audit, penetration remediation, and cryptographic activity logging.',
    'RESEARCH',
    'ON_TRACK',
    timezone('utc'::text, now() + interval '60 days'),
    '[
      {"id": "idea", "label": "Idea", "color": "slate", "order": 0, "category": "todo"},
      {"id": "lit_review", "label": "Requirements", "color": "blue", "order": 1, "category": "in_progress"},
      {"id": "methodology", "label": "Remediation", "color": "purple", "order": 2, "category": "in_progress"},
      {"id": "writing", "label": "Audit Review", "color": "amber", "order": 3, "category": "review"},
      {"id": "completed", "label": "Certified", "color": "green", "order": 4, "category": "done"}
    ]'::jsonb
  )
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, color = EXCLUDED.color;

-- 6. Demo Project Members
INSERT INTO project_members (id, project_id, email, role)
VALUES
  ('f0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'alex.morgan@beacon.io', 'OWNER'),
  ('f0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'david.chen@beacon.io', 'DEVELOPER'),
  ('f0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', 'sarah.kim@beacon.io', 'PM'),
  ('f0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000002', 'david.chen@beacon.io', 'DEVELOPER'),
  ('f0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000003', 'sarah.kim@beacon.io', 'PM')
ON CONFLICT (id) DO NOTHING;

-- 7. Demo Tasks
INSERT INTO tasks (id, project_id, title, description, status, priority, assignee_id, due_date, estimate_minutes)
VALUES
  -- Project 1 Tasks
  (
    '00000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    'Setup WebSocket room routing for team board sync',
    'Connect Socket.io server to broadcast task position changes to workspace peers in sub-50ms.',
    'completed',
    'HIGH',
    'david.chen@beacon.io',
    timezone('utc'::text, now() + interval '5 days'),
    240
  ),
  (
    '00000000-0000-0000-0000-000000000002',
    'c0000000-0000-0000-0000-000000000001',
    'Configure Supabase Row Level Security (RLS)',
    'Enforce workspace isolation policies across tasks, projects, and member directories.',
    'review',
    'CRITICAL',
    'alex.morgan@beacon.io',
    timezone('utc'::text, now() + interval '2 days'),
    180
  ),
  (
    '00000000-0000-0000-0000-000000000003',
    'c0000000-0000-0000-0000-000000000001',
    'Build Health Status calculation engine',
    'Implement automatic heuristic score factoring deadline proximity and blocked task count.',
    'in_progress',
    'HIGH',
    'sarah.kim@beacon.io',
    timezone('utc'::text, now() + interval '7 days'),
    360
  ),
  (
    '00000000-0000-0000-0000-000000000004',
    'c0000000-0000-0000-0000-000000000001',
    'Index optimization for workspace queries',
    'Add composite indexes on (workspace_id, updated_at) to accelerate cold-start board hydration.',
    'todo',
    'MEDIUM',
    'david.chen@beacon.io',
    timezone('utc'::text, now() + interval '12 days'),
    120
  ),
  (
    '00000000-0000-0000-0000-000000000005',
    'c0000000-0000-0000-0000-000000000001',
    'Webhook trigger for GitHub Pull Request linkage',
    'Explore bidirectional GitHub integration to update task status upon PR merge.',
    'idea',
    'LOW',
    'alex.morgan@beacon.io',
    timezone('utc'::text, now() + interval '20 days'),
    480
  ),

  -- Project 2 Tasks (Mobile App)
  (
    '00000000-0000-0000-0000-000000000006',
    'c0000000-0000-0000-0000-000000000002',
    'Offline task queuing & conflict resolution',
    'BLOCKED: Waiting on mobile SQLite schema migration approval.',
    'in_progress',
    'CRITICAL',
    'david.chen@beacon.io',
    timezone('utc'::text, now() + interval '4 days'),
    300
  ),
  (
    '00000000-0000-0000-0000-000000000007',
    'c0000000-0000-0000-0000-000000000002',
    'Biometric FaceID / TouchID authentication flow',
    'Allow mobile members to unlock cached tokens safely with biometric hardware keys.',
    'completed',
    'MEDIUM',
    'alex.morgan@beacon.io',
    timezone('utc'::text, now() + interval '10 days'),
    200
  ),

  -- Project 3 Tasks (SOC2 Audit)
  (
    '00000000-0000-0000-0000-000000000008',
    'c0000000-0000-0000-0000-000000000003',
    'Immutable activity log retention pipeline',
    'Ensure all write actions persist in activity_logs with actor metadata and timestamps.',
    'completed',
    'HIGH',
    'sarah.kim@beacon.io',
    timezone('utc'::text, now() + interval '14 days'),
    150
  )
ON CONFLICT (id) DO UPDATE
SET title = EXCLUDED.title, status = EXCLUDED.status, priority = EXCLUDED.priority;

-- 8. Demo Activity Logs
INSERT INTO activity_logs (id, project_id, task_id, actor_email, actor_name, action, details, created_at)
VALUES
  (
    '10000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'david.chen@beacon.io',
    'David Chen',
    'status_changed',
    'Moved task "Setup WebSocket room routing" to Completed',
    timezone('utc'::text, now() - interval '2 hours')
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    'c0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    'alex.morgan@beacon.io',
    'Alex Morgan',
    'task_created',
    'Created task "Configure Supabase Row Level Security"',
    timezone('utc'::text, now() - interval '5 hours')
  ),
  (
    '10000000-0000-0000-0000-000000000003',
    'c0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000006',
    'david.chen@beacon.io',
    'David Chen',
    'task_blocked',
    'Flagged "Offline task queuing" as BLOCKED',
    timezone('utc'::text, now() - interval '1 day')
  )
ON CONFLICT (id) DO NOTHING;

-- 9. Demo Notifications Queue
INSERT INTO notifications_queue (id, user_id, title, body, read, data, created_at)
VALUES
  (
    '20000000-0000-0000-0000-000000000001',
    'alex.morgan@beacon.io',
    'Task Ready for Review',
    'Configure Supabase Row Level Security is waiting for your approval.',
    false,
    '{"type": "review_request", "task_id": "00000000-0000-0000-0000-000000000002", "project_id": "c0000000-0000-0000-0000-000000000001", "user_name": "Alex Morgan"}'::jsonb,
    timezone('utc'::text, now() - interval '30 minutes')
  ),
  (
    '20000000-0000-0000-0000-000000000002',
    'david.chen@beacon.io',
    'Sprint Milestone Achieved',
    'WebSocket real-time sync module has passed end-to-end integration tests.',
    true,
    '{"type": "info", "project_id": "c0000000-0000-0000-0000-000000000001", "user_name": "System"}'::jsonb,
    timezone('utc'::text, now() - interval '2 hours')
  )
ON CONFLICT (id) DO NOTHING;


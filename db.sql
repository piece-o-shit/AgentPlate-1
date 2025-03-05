-- Set up AgentPlate schema in Supabase
SET search_path TO public;

-- Enable uuid-ossp extension (Supabase includes it)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enums for roles and tool types
CREATE TYPE app_role AS ENUM ('admin', 'user');
CREATE TYPE tool_type AS ENUM ('api', 'database', 'file_system', 'custom');

-- User roles table (links to auth.users)
CREATE TABLE user_roles (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    role app_role NOT NULL,
    PRIMARY KEY (user_id, role)
);

ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their roles" ON user_roles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Admins can manage roles" ON user_roles FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'admin'));

-- Agents table
CREATE TABLE agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    creator_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE agents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their agents" ON agents FOR SELECT USING (auth.uid() = creator_id);
CREATE POLICY "Admins can manage agents" ON agents FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'admin'));

-- Tools table
CREATE TABLE tools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    type tool_type NOT NULL,
    config JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE tools ENABLE ROW LEVEL SECURITY;
CREATE POLICY "All authenticated users can view tools" ON tools FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage tools" ON tools FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'admin'));

-- Agent-tools junction table
CREATE TABLE agent_tools (
    agent_id UUID REFERENCES agents(id) ON DELETE CASCADE,
    tool_id UUID REFERENCES tools(id) ON DELETE CASCADE,
    PRIMARY KEY (agent_id, tool_id)
);

ALTER TABLE agent_tools ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage agent_tools" ON agent_tools FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'admin'));

-- Workflows table
CREATE TABLE workflows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    creator_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE workflows ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their workflows" ON workflows FOR SELECT USING (auth.uid() = creator_id);
CREATE POLICY "Admins can manage workflows" ON workflows FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'admin'));

-- Workflow steps table
CREATE TABLE workflow_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_id UUID REFERENCES workflows(id) ON DELETE CASCADE,
    agent_id UUID REFERENCES agents(id),
    step_order INT NOT NULL,
    action TEXT NOT NULL,
    config JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE workflow_steps ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view steps of their workflows" ON workflow_steps FOR SELECT USING (EXISTS (SELECT 1 FROM workflows WHERE workflows.id = workflow_id AND workflows.creator_id = auth.uid()));
CREATE POLICY "Admins can manage workflow_steps" ON workflow_steps FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'admin'));

-- Profiles table for display names
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL DEFAULT 'User',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view and edit their own profile" ON public.profiles FOR ALL TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Trigger for new user profiles
CREATE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, display_name) VALUES (NEW.id, 'User');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger for updated_at
CREATE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_agents_updated_at BEFORE UPDATE ON agents FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_workflows_updated_at BEFORE UPDATE ON workflows FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create admin and user via Supabase Auth Dashboard
-- Add: admin@example.com (password: adminpassword), user@example.com (password: userpassword)
-- Get their IDs from auth.users, then insert roles
INSERT INTO user_roles (user_id, role) VALUES
    ('cbe6c3a4-5c1e-4489-b21a-faa52aa120c6', 'admin'), -- Replace with actual admin ID if different
    ('389fad7a-3653-4885-893d-4fdd8aaff413', 'user');  -- Replace with actual user ID if different

-- Set display names
UPDATE public.profiles SET display_name = 'Admin User' WHERE id = 'cbe6c3a4-5c1e-4489-b21a-faa52aa120c6';
UPDATE public.profiles SET display_name = 'Regular User' WHERE id = '389fad7a-3653-4885-893d-4fdd8aaff413';

-- Sample data
INSERT INTO agents (id, name, description, creator_id) VALUES
    ('33333333-3333-3333-3333-333333333333', 'DataFetcher', 'Fetches data from APIs', 'cbe6c3a4-5c1e-4489-b21a-faa52aa120c6');

INSERT INTO tools (id, name, type, config) VALUES
    ('44444444-4444-4444-4444-444444444444', 'REST_API', 'api', '{"endpoint": "https://api.example.com/data"}');

INSERT INTO agent_tools (agent_id, tool_id) VALUES
    ('33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444');

INSERT INTO workflows (id, name, description, creator_id) VALUES
    ('55555555-5555-5555-5555-555555555555', 'DataPipeline', 'Fetches and processes data', 'cbe6c3a4-5c1e-4489-b21a-faa52aa120c6');

INSERT INTO workflow_steps (id, workflow_id, agent_id, step_order, action, config) VALUES
    ('66666666-6666-6666-6666-666666666666', '55555555-5555-5555-5555-555555555555', '33333333-3333-3333-3333-333333333333', 1, 'execute_tool', '{"tool_id": "44444444-4444-4444-4444-444444444444"}');

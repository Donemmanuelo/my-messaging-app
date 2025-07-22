CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE TABLE users (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), phone_number TEXT NOT NULL UNIQUE, name TEXT, last_seen TIMESTAMPTZ NOT NULL DEFAULT 
NOW(), online BOOLEAN NOT NULL DEFAULT FALSE);
CREATE TABLE temp_otps (phone_number TEXT PRIMARY KEY, otp_hash TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW());
CREATE INDEX idx_temp_otps_created_at ON temp_otps(created_at);
CREATE TABLE conversations (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), is_group BOOLEAN NOT NULL DEFAULT FALSE, group_name TEXT, group_icon_url TEXT, 
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW());
CREATE TABLE conversation_participants (conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, user_id UUID NOT NULL REFERENCES 
users(id) ON DELETE CASCADE, is_admin BOOLEAN NOT NULL DEFAULT FALSE, PRIMARY KEY (conversation_id, user_id));
CREATE TYPE message_status AS ENUM ('sent', 'delivered', 'read');
CREATE TYPE message_type AS ENUM ('text', 'image', 'video', 'audio');
CREATE TABLE messages (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, 
sender_id UUID NOT NULL REFERENCES users(id), message_type message_type NOT NULL DEFAULT 'text', content TEXT NOT NULL, status message_status NOT NULL 
DEFAULT 'sent', created_at TIMESTAMPTZ NOT NULL DEFAULT NOW());
CREATE INDEX idx_participants_user_id ON conversation_participants(user_id);
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE TABLE user_key_bundles (user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, identity_key TEXT NOT NULL, signed_pre_key TEXT NOT NULL, 
one_time_pre_keys JSONB NOT NULL, updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW());
CREATE TYPE device_platform AS ENUM ('android', 'ios', 'web');
CREATE TABLE device_tokens (user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, device_token TEXT NOT NULL, platform device_platform NOT NULL, 
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), PRIMARY KEY (user_id, device_token));
CREATE TYPE qr_session_status AS ENUM ('pending', 'scanned', 'authenticated');
CREATE TABLE qr_sessions (session_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), status qr_session_status NOT NULL DEFAULT 'pending', user_id UUID 
REFERENCES users(id), jwt TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW());
CREATE INDEX idx_qr_sessions_created_at ON qr_sessions(created_at);

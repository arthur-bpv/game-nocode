CREATE TABLE users (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 issuer text NOT NULL,
 identity_hash bytea NOT NULL,
 nickname text NOT NULL DEFAULT '',
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (issuer, identity_hash)
);
CREATE TABLE auth_attempts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 browser_hash bytea NOT NULL UNIQUE,
 redeem_hash bytea NOT NULL,
 state_hash bytea UNIQUE,
 cookie_hash bytea,
 verifier bytea,
 identity_hash bytea,
 status text NOT NULL DEFAULT 'created',
 expires timestamptz NOT NULL DEFAULT now() + interval '5 minutes'
);
CREATE TABLE sessions (
 token_hash bytea PRIMARY KEY,
 user_id uuid NOT NULL REFERENCES users(id),
 expires timestamptz NOT NULL DEFAULT now() + interval '8 hours',
 last_used timestamptz NOT NULL DEFAULT now(),
 revoked boolean NOT NULL DEFAULT false
);
CREATE TABLE matches (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 map_version text NOT NULL,
 started_at timestamptz NOT NULL DEFAULT now(),
 finished_at timestamptz,
 outcome text CHECK (outcome IN ('completed','abandoned','interrupted'))
);
CREATE TABLE match_players (
 match_id uuid NOT NULL REFERENCES matches(id),
 user_id uuid NOT NULL REFERENCES users(id),
 role integer NOT NULL CHECK (role IN (0,1)),
 PRIMARY KEY (match_id,user_id),
 UNIQUE (match_id,role)
);

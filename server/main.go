package main

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"embed"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed migrations/*.sql
var migrations embed.FS

const protocol = 1

type server struct {
	db      *pgxpool.Pool
	cfg     config
	http    *http.Client
	mu      sync.Mutex
	tickets map[string]ticket
	peers   map[string]*peer
	rooms   map[string]*room
	layout  layout
	limits  map[string]window
}

type config struct {
	base, issuer, authorize, token, identity, field, scope, client, secret, tokenAuth string
	key                                                                               []byte
}

type ticket struct {
	account account
	expires time.Time
}

type account struct {
	ID       string    `json:"id"`
	Nickname string    `json:"nickname"`
	Session  string    `json:"-"`
	Expires  time.Time `json:"-"`
}

type window struct {
	until time.Time
	count int
}

func randomToken() string {
	return base64.RawURLEncoding.EncodeToString(randomBytes(32))
}

func randomBytes(size int) []byte {
	data := make([]byte, size)
	_, err := rand.Read(data)
	if err != nil {
		panic(err)
	}
	return data
}

func digest(value string) []byte {
	hash := sha256.Sum256([]byte(value))
	return hash[:]
}

func reply(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func problem(w http.ResponseWriter, status int, code string) {
	reply(w, status, map[string]string{"code": code})
}

func decode(r io.Reader, target any) error {
	decoder := json.NewDecoder(r)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	if decoder.Decode(new(any)) != io.EOF {
		return errors.New("trailing data")
	}
	return nil
}

func env(name string) string { return os.Getenv(name) }

func readConfig() (config, error) {
	c := config{
		base:   strings.TrimSuffix(env("PUBLIC_URL"), "/"),
		issuer: env("OAUTH_ISSUER"), authorize: env("OAUTH_AUTHORIZE_URL"),
		token: env("OAUTH_TOKEN_URL"), identity: env("OAUTH_IDENTITY_URL"),
		field: env("OAUTH_IDENTITY_FIELD"), scope: env("OAUTH_SCOPE"),
		client: env("OAUTH_CLIENT_ID"), secret: env("OAUTH_CLIENT_SECRET"),
		tokenAuth: env("OAUTH_TOKEN_AUTH"),
	}
	for _, endpoint := range []string{c.base, c.issuer, c.authorize, c.token, c.identity} {
		parsed, err := url.Parse(endpoint)
		if err != nil || parsed.Scheme != "https" || parsed.Host == "" || parsed.User != nil || parsed.Fragment != "" {
			return c, errors.New("OAuth and public endpoints must use HTTPS")
		}
	}
	public, _ := url.Parse(c.base)
	if public.Path != "" || public.RawQuery != "" {
		return c, errors.New("PUBLIC_URL must be an HTTPS origin")
	}
	c.key, _ = base64.StdEncoding.DecodeString(env("IDENTITY_KEY"))
	if len(c.key) != 32 || c.field == "" || c.client == "" || c.secret == "" {
		return c, errors.New("identity key and OAuth client configuration required")
	}
	if c.tokenAuth != "basic" && c.tokenAuth != "post" {
		return c, errors.New("OAUTH_TOKEN_AUTH must be basic or post")
	}
	return c, nil
}

func migrate(ctx context.Context, db *pgxpool.Pool) error {
	tx, err := db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, "SELECT pg_advisory_xact_lock(803121)"); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, "CREATE TABLE IF NOT EXISTS schema_migrations (version text PRIMARY KEY)"); err != nil {
		return err
	}
	entries, err := migrations.ReadDir("migrations")
	if err != nil {
		return err
	}
	for _, entry := range entries {
		var installed bool
		if err = tx.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM schema_migrations WHERE version=$1)", entry.Name()).Scan(&installed); err != nil {
			return err
		}
		if installed {
			continue
		}
		sql, err := migrations.ReadFile("migrations/" + entry.Name())
		if err != nil {
			return err
		}
		if _, err = tx.Exec(ctx, string(sql)); err != nil {
			return err
		}
		if _, err = tx.Exec(ctx, "INSERT INTO schema_migrations VALUES ($1)", entry.Name()); err != nil {
			return err
		}
	}
	if _, err = tx.Exec(ctx, "UPDATE matches SET outcome='interrupted', finished_at=now() WHERE outcome IS NULL"); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) { reply(w, 200, map[string]int{"version": protocol}) })
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if s.db.Ping(r.Context()) != nil {
			problem(w, 503, "unavailable")
			return
		}
		w.WriteHeader(204)
	})
	mux.HandleFunc("POST /v1/auth/attempts", s.createAttempt)
	mux.HandleFunc("GET /v1/auth/browser", s.browser)
	mux.HandleFunc("GET /v1/auth/callback", s.callback)
	mux.HandleFunc("POST /v1/auth/attempts/{id}/redeem", s.redeem)
	mux.HandleFunc("DELETE /v1/auth/attempts/{id}", s.cancel)
	mux.HandleFunc("GET /v1/profile", s.auth(s.profile))
	mux.HandleFunc("PUT /v1/profile", s.auth(s.profile))
	mux.HandleFunc("DELETE /v1/session", s.auth(s.logout))
	mux.HandleFunc("POST /v1/tickets", s.auth(s.issueTicket))
	mux.HandleFunc("GET /v1/ws", s.websocket)
	mux.HandleFunc("GET /metrics", s.metrics)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		r.Body = http.MaxBytesReader(w, r.Body, 4096)
		if r.URL.Path != "/v1/ws" {
			ctx, cancel := context.WithTimeout(r.Context(), 12*time.Second)
			defer cancel()
			r = r.WithContext(ctx)
		}
		mux.ServeHTTP(w, r)
	})
}

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stderr, nil)))
	if err := run(); err != nil {
		slog.Error("server stopped", "error", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := readConfig()
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	db, err := pgxpool.New(ctx, env("DATABASE_URL"))
	if err != nil {
		return errors.New("invalid database configuration")
	}
	defer db.Close()
	if err = migrate(ctx, db); err != nil {
		return errors.New("database migration or startup reconciliation failed")
	}
	data, err := os.ReadFile(env("MAP_FILE"))
	if err != nil {
		return err
	}
	s := &server{db: db, cfg: cfg, http: &http.Client{
		Timeout:       8 * time.Second,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}, tickets: make(map[string]ticket), peers: make(map[string]*peer), rooms: make(map[string]*room), limits: make(map[string]window)}
	if err = json.Unmarshal(data, &s.layout); err != nil {
		return err
	}
	if s.layout.Version == "" || s.layout.Width < 100 || s.layout.Height < 100 || s.layout.Radius <= 0 {
		return errors.New("invalid cooperative map")
	}
	go s.simulate()
	go s.clean()
	service := &http.Server{Addr: ":8080", Handler: s.routes(), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 12 * time.Second, WriteTimeout: 15 * time.Second, IdleTimeout: 45 * time.Second, MaxHeaderBytes: 8192}
	slog.Info("server ready", "protocol", protocol, "map", s.layout.Version)
	return service.ListenAndServe()
}

func (s *server) clean() {
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()
	for now := range ticker.C {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		_, _ = s.db.Exec(ctx, "DELETE FROM auth_attempts WHERE expires <= now()")
		_, _ = s.db.Exec(ctx, "DELETE FROM sessions WHERE expires <= now()")
		cancel()
		s.mu.Lock()
		for key, value := range s.tickets {
			if !now.Before(value.expires) {
				delete(s.tickets, key)
			}
		}
		for key, value := range s.limits {
			if !now.Before(value.until) {
				delete(s.limits, key)
			}
		}
		s.mu.Unlock()
	}
}

func (s *server) allowLocked(key string, max int, duration time.Duration) bool {
	now := time.Now()
	value := s.limits[key]
	if !now.Before(value.until) {
		value = window{until: now.Add(duration)}
	}
	if value.count >= max {
		return false
	}
	value.count++
	s.limits[key] = value
	return true
}

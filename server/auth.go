package main

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/jackc/pgx/v5"
)

func bearer(r *http.Request) string {
	value, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
	if !ok || len(value) != 43 {
		return ""
	}
	return value
}

func (s *server) createAttempt(w http.ResponseWriter, r *http.Request) {
	ip := r.Header.Get("X-Netbot-Client")
	if ip == "" {
		ip, _, _ = net.SplitHostPort(r.RemoteAddr)
	}
	s.mu.Lock()
	allowed := s.allowLocked("login:"+ip, 20, time.Minute)
	s.mu.Unlock()
	if !allowed {
		problem(w, 429, "rate_limit")
		return
	}
	browser, redeemer := randomToken(), randomToken()
	var id string
	err := s.db.QueryRow(r.Context(), "INSERT INTO auth_attempts(browser_hash,redeem_hash) VALUES ($1,$2) RETURNING id", digest(browser), digest(redeemer)).Scan(&id)
	if err != nil {
		problem(w, 503, "unavailable")
		return
	}
	reply(w, 201, map[string]any{"id": id, "browser_url": s.cfg.base + "/v1/auth/browser?k=" + browser, "redeem_token": redeemer, "expires_in": 300})
}

func page(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; base-uri 'none'")
	w.WriteHeader(status)
	_, _ = io.WriteString(w, "<!doctype html><html lang=pt-BR><meta charset=utf-8><title>NETBOT</title><main><h1>NETBOT</h1><p>"+message+"</p></main></html>")
}

func (s *server) encryption() cipher.AEAD {
	key := hmac.New(sha256.New, s.cfg.key)
	key.Write([]byte("netbot-pkce-v1"))
	block, _ := aes.NewCipher(key.Sum(nil))
	gcm, _ := cipher.NewGCM(block)
	return gcm
}

func (s *server) browser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.Header().Set("Allow", "GET")
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	start := r.URL.Query().Get("k")
	state, cookie, verifier := randomToken(), randomToken(), randomToken()
	gcm := s.encryption()
	nonce := randomBytes(gcm.NonceSize())
	encrypted := gcm.Seal(nonce, nonce, []byte(verifier), digest(state))
	result, err := s.db.Exec(r.Context(), `UPDATE auth_attempts SET status='browser',state_hash=$1,cookie_hash=$2,verifier=$3
 WHERE browser_hash=$4 AND status='created' AND expires>now()`, digest(state), digest(cookie), encrypted, digest(start))
	if err != nil || result.RowsAffected() != 1 {
		page(w, 400, "A tentativa expirou ou já foi aberta. Volte ao jogo.")
		return
	}
	http.SetCookie(w, &http.Cookie{Name: "__Host-netbot", Value: cookie, Path: "/", Secure: true, HttpOnly: true, SameSite: http.SameSiteLaxMode, MaxAge: 300})
	endpoint, _ := url.Parse(s.cfg.authorize)
	q := endpoint.Query()
	q.Set("client_id", s.cfg.client)
	q.Set("redirect_uri", s.cfg.base+"/v1/auth/callback")
	q.Set("response_type", "code")
	q.Set("state", state)
	q.Set("code_challenge", base64.RawURLEncoding.EncodeToString(digest(verifier)))
	q.Set("code_challenge_method", "S256")
	if s.cfg.scope != "" {
		q.Set("scope", s.cfg.scope)
	}
	endpoint.RawQuery = q.Encode()
	http.Redirect(w, r, endpoint.String(), http.StatusSeeOther)
}

func (s *server) callback(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.Header().Set("Allow", "GET")
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	q := r.URL.Query()
	state := q.Get("state")
	cookie, err := r.Cookie("__Host-netbot")
	if err != nil || len(state) != 43 {
		page(w, 400, "Retorno de autenticação inválido. Volte ao jogo.")
		return
	}
	var id string
	var encrypted []byte
	err = s.db.QueryRow(r.Context(), `UPDATE auth_attempts SET status='exchanging', verifier=NULL
 FROM (SELECT id,verifier FROM auth_attempts WHERE state_hash=$1 AND cookie_hash=$2) AS attempt
 WHERE auth_attempts.id=attempt.id AND status='browser' AND expires>now()
 RETURNING auth_attempts.id,attempt.verifier`, digest(state), digest(cookie.Value)).Scan(&id, &encrypted)
	if err != nil {
		page(w, 400, "Retorno expirado ou já utilizado. Volte ao jogo.")
		return
	}
	status := "denied"
	var identity []byte
	gcm := s.encryption()
	if q.Get("error") == "" && len(q["code"]) == 1 && q.Get("code") != "" && len(encrypted) >= gcm.NonceSize() {
		verifier, openErr := gcm.Open(nil, encrypted[:gcm.NonceSize()], encrypted[gcm.NonceSize():], digest(state))
		if openErr == nil {
			identity, err = s.exchange(r.Context(), q.Get("code"), string(verifier))
			if err == nil {
				status = "approved"
			}
		}
	}
	result, err := s.db.Exec(r.Context(), "UPDATE auth_attempts SET status=$1,identity_hash=$2 WHERE id=$3 AND status='exchanging' AND expires>now()", status, identity, id)
	if err == nil && result.RowsAffected() == 1 && status == "approved" {
		page(w, 200, "Login concluído. Volte ao NETBOT.")
		return
	}
	page(w, 400, "Login não concluído. Volte ao jogo para tentar novamente.")
}

func (s *server) exchange(ctx context.Context, code, verifier string) ([]byte, error) {
	form := url.Values{"grant_type": {"authorization_code"}, "code": {code}, "redirect_uri": {s.cfg.base + "/v1/auth/callback"}, "code_verifier": {verifier}}
	if s.cfg.tokenAuth == "post" {
		form.Set("client_id", s.cfg.client)
		form.Set("client_secret", s.cfg.secret)
	}
	req, err := http.NewRequestWithContext(ctx, "POST", s.cfg.token, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	if s.cfg.tokenAuth == "basic" {
		req.SetBasicAuth(url.QueryEscape(s.cfg.client), url.QueryEscape(s.cfg.secret))
	}
	var token struct {
		Access string `json:"access_token"`
	}
	if err = s.providerJSON(req, &token); err != nil || token.Access == "" {
		return nil, errors.New("OAuth token unavailable")
	}
	req, err = http.NewRequestWithContext(ctx, "GET", s.cfg.identity, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token.Access)
	var fields map[string]json.RawMessage
	if err = s.providerJSON(req, &fields); err != nil {
		return nil, err
	}
	var value string
	if json.Unmarshal(fields[s.cfg.field], &value) != nil || strings.TrimSpace(value) == "" || len(value) > 256 {
		return nil, errors.New("invalid stable identity")
	}
	hash := hmac.New(sha256.New, s.cfg.key)
	hash.Write([]byte(s.cfg.issuer + "\x00" + value))
	return hash.Sum(nil), nil
}

func (s *server) providerJSON(req *http.Request, target any) error {
	req.Header.Set("Accept", "application/json")
	response, err := s.http.Do(req)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if response.StatusCode != 200 {
		return errors.New("OAuth request rejected")
	}
	data, err := io.ReadAll(io.LimitReader(response.Body, 65537))
	if err != nil || len(data) > 65536 {
		return errors.New("invalid OAuth response body")
	}
	return json.Unmarshal(data, target)
}

const attemptByCredential = "id::text=$1 AND redeem_hash=$2 AND expires>now()"

func (s *server) redeem(w http.ResponseWriter, r *http.Request) {
	credential := bearer(r)
	if credential == "" {
		problem(w, 401, "invalid_credential")
		return
	}
	ctx := r.Context()
	tx, err := s.db.Begin(ctx)
	if err != nil {
		problem(w, 503, "unavailable")
		return
	}
	defer tx.Rollback(ctx)
	var status string
	var identity []byte
	err = tx.QueryRow(ctx, "SELECT status,identity_hash FROM auth_attempts WHERE "+attemptByCredential+" FOR UPDATE", r.PathValue("id"), digest(credential)).Scan(&status, &identity)
	switch {
	case errors.Is(err, pgx.ErrNoRows):
		problem(w, 410, "attempt_expired")
		return
	case err != nil:
		problem(w, 503, "unavailable")
		return
	case status == "denied":
		problem(w, 403, "login_denied")
		return
	case status != "approved":
		reply(w, 202, map[string]string{"status": "pending"})
		return
	}
	var a account
	token := randomToken()
	err = tx.QueryRow(ctx, `INSERT INTO users(issuer,identity_hash) VALUES ($1,$2)
 ON CONFLICT (issuer,identity_hash) DO UPDATE SET updated_at=now()
 RETURNING id,nickname`, s.cfg.issuer, identity).Scan(&a.ID, &a.Nickname)
	if err == nil {
		_, err = tx.Exec(ctx, "INSERT INTO sessions(token_hash,user_id) VALUES ($1,$2)", digest(token), a.ID)
	}
	if err == nil {
		_, err = tx.Exec(ctx, "DELETE FROM auth_attempts WHERE id=$1", r.PathValue("id"))
	}
	if err == nil {
		err = tx.Commit(ctx)
	}
	if err != nil {
		problem(w, 503, "unavailable")
		return
	}
	reply(w, 200, map[string]any{"token": token, "account": a})
}

func (s *server) cancel(w http.ResponseWriter, r *http.Request) {
	if bearer(r) == "" {
		problem(w, 401, "invalid_credential")
		return
	}
	_, err := s.db.Exec(r.Context(), "DELETE FROM auth_attempts WHERE "+attemptByCredential, r.PathValue("id"), digest(bearer(r)))
	if err != nil {
		problem(w, 503, "unavailable")
		return
	}
	w.WriteHeader(204)
}

func (s *server) session(ctx context.Context, hash []byte) (account, error) {
	var a account
	a.Session = string(hash)
	err := s.db.QueryRow(ctx, `UPDATE sessions SET last_used=now() FROM users
 WHERE token_hash=$1 AND NOT revoked AND expires>now() AND users.id=sessions.user_id
 RETURNING users.id, users.nickname, sessions.expires`, hash).Scan(&a.ID, &a.Nickname, &a.Expires)
	return a, err
}

func (s *server) auth(next func(http.ResponseWriter, *http.Request, account)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := bearer(r)
		if token == "" {
			problem(w, 401, "session_expired")
			return
		}
		a, err := s.session(r.Context(), digest(token))
		if errors.Is(err, pgx.ErrNoRows) {
			problem(w, 401, "session_expired")
			return
		}
		if err != nil {
			problem(w, 503, "unavailable")
			return
		}
		next(w, r, a)
	}
}

func validName(value string, max int) bool {
	length := utf8.RuneCountInString(value)
	return length > 0 && length <= max && strings.IndexFunc(value, unicode.IsControl) < 0
}

func (s *server) profile(w http.ResponseWriter, r *http.Request, a account) {
	if r.Method == "PUT" {
		var body struct {
			Nickname string `json:"nickname"`
		}
		if decode(r.Body, &body) != nil {
			problem(w, 400, "invalid_message")
			return
		}
		body.Nickname = strings.TrimSpace(body.Nickname)
		if !validName(body.Nickname, 24) {
			problem(w, 400, "invalid_nickname")
			return
		}
		if _, err := s.db.Exec(r.Context(), "UPDATE users SET nickname=$1,updated_at=now() WHERE id=$2", body.Nickname, a.ID); err != nil {
			problem(w, 503, "unavailable")
			return
		}
		a.Nickname = body.Nickname
	}
	reply(w, 200, a)
}

func (s *server) logout(w http.ResponseWriter, r *http.Request, a account) {
	if _, err := s.db.Exec(r.Context(), "UPDATE sessions SET revoked=true WHERE token_hash=$1", []byte(a.Session)); err != nil {
		problem(w, 503, "unavailable")
		return
	}
	s.mu.Lock()
	for k, t := range s.tickets {
		if t.account.Session == a.Session {
			delete(s.tickets, k)
		}
	}
	if p := s.peers[a.ID]; p != nil && p.account.Session == a.Session {
		p.conn.Close()
		s.disconnect(p)
	}
	s.mu.Unlock()
	w.WriteHeader(204)
}

func (s *server) issueTicket(w http.ResponseWriter, r *http.Request, a account) {
	if a.Nickname == "" {
		problem(w, 409, "nickname_required")
		return
	}
	token := randomToken()
	s.mu.Lock()
	allowed := s.allowLocked("ticket:"+a.ID, 15, time.Minute)
	if allowed {
		s.tickets[string(digest(token))] = ticket{a, time.Now().Add(30 * time.Second)}
	}
	s.mu.Unlock()
	if !allowed {
		problem(w, 429, "rate_limit")
		return
	}
	reply(w, 201, map[string]string{"ticket": token})
}

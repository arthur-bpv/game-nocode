package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"github.com/jackc/pgx/v5/pgxpool"
)

func TestOAuthAndCooperativeMatch(t *testing.T) {
	dsn := os.Getenv("NETBOT_TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("NETBOT_TEST_DATABASE_URL required for PostgreSQL integration")
	}
	ctx := context.Background()
	admin, err := pgxpool.New(ctx, dsn)
	must(t, err)
	defer admin.Close()
	schema := "netbot_test_" + strings.ToLower(roomCode())
	_, err = admin.Exec(ctx, "CREATE SCHEMA "+schema)
	must(t, err)
	defer admin.Exec(ctx, "DROP SCHEMA "+schema+" CASCADE")
	cfg, err := pgxpool.ParseConfig(dsn)
	must(t, err)
	cfg.ConnConfig.RuntimeParams["search_path"] = schema
	db, err := pgxpool.NewWithConfig(ctx, cfg)
	must(t, err)
	defer db.Close()
	must(t, migrate(ctx, db))

	provider := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/token":
			_ = r.ParseForm()
			id, secret, ok := r.BasicAuth()
			code := strings.SplitN(r.Form.Get("code"), ".", 2)
			if !ok || id != "test" || secret != "secret" || len(code) != 2 || code[0] != base64.RawURLEncoding.EncodeToString(digest(r.Form.Get("code_verifier"))) {
				w.WriteHeader(400)
				return
			}
			reply(w, 200, map[string]string{"access_token": code[1]})
		case "/identity":
			reply(w, 200, map[string]string{"subject": strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")})
		default:
			http.NotFound(w, r)
		}
	}))
	defer provider.Close()
	s := &server{
		db: db, http: provider.Client(), cfg: config{issuer: provider.URL, authorize: provider.URL + "/authorize", token: provider.URL + "/token", identity: provider.URL + "/identity", field: "subject", client: "test", secret: "secret", tokenAuth: "basic", key: randomBytes(32)},
		peers: make(map[string]*peer), tickets: make(map[string]ticket), rooms: make(map[string]*room), limits: make(map[string]window),
	}
	data, err := os.ReadFile("../data/lan/inspection.json")
	must(t, err)
	must(t, json.Unmarshal(data, &s.layout))
	api := httptest.NewUnstartedServer(s.routes())
	s.cfg.base = "https://" + api.Listener.Addr().String()
	api.StartTLS()
	defer api.Close()
	client := api.Client()
	client.Timeout = 3 * time.Second
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	client.Jar, err = cookiejar.New(nil)
	must(t, err)
	call := func(method, path, token, body string, status int) map[string]any {
		t.Helper()
		req, err := http.NewRequest(method, api.URL+path, strings.NewReader(body))
		must(t, err)
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		resp, err := client.Do(req)
		must(t, err)
		defer resp.Body.Close()
		raw, err := io.ReadAll(resp.Body)
		must(t, err)
		if resp.StatusCode != status {
			t.Fatalf("%s %s: got %d, want %d: %s", method, path, resp.StatusCode, status, raw)
		}
		var result map[string]any
		_ = json.Unmarshal(raw, &result)
		if status == 303 {
			return map[string]any{"location": resp.Header.Get("Location")}
		}
		return result
	}

	attempt := func() (string, string, string) {
		data := call("POST", "/v1/auth/attempts", "", "", 201)
		return "/v1/auth/attempts/" + data["id"].(string), data["redeem_token"].(string), strings.TrimPrefix(data["browser_url"].(string), api.URL)
	}
	approve := func(browser, identity string, denied bool) string {
		res := call("GET", browser, "", "", 303)
		redirect, err := url.Parse(res["location"].(string))
		must(t, err)
		q := redirect.Query()
		if q.Get("code_challenge_method") != "S256" || q.Get("redirect_uri") != api.URL+"/v1/auth/callback" {
			t.Fatal("invalid authorization request")
		}
		path := "/v1/auth/callback?state=" + url.QueryEscape(q.Get("state"))
		if denied {
			call("GET", path+"&error=access_denied", "", "", 400)
		} else {
			path += "&code=" + url.QueryEscape(q.Get("code_challenge")+"."+identity)
			call("GET", path, "", "", 200)
		}
		return path
	}
	login := func(identity string) (string, map[string]any) {
		path, key, browser := attempt()
		call("POST", path+"/redeem", key, "", 202)
		callback := approve(browser, identity, false)
		call("GET", callback, "", "", 400)
		result := call("POST", path+"/redeem", key, "", 200)
		call("POST", path+"/redeem", key, "", 410)
		return result["token"].(string), result["account"].(map[string]any)
	}
	denied, key, browser := attempt()
	approve(browser, "", true)
	call("POST", denied+"/redeem", key, "", 403)
	canceled, key, browser := attempt()
	call("DELETE", canceled, key, "", 204)
	call("POST", canceled+"/redeem", key, "", 410)
	call("GET", browser, "", "", 400)
	expired, key, browser := attempt()
	_, err = db.Exec(ctx, "UPDATE auth_attempts SET expires=now()-interval '1 second'")
	must(t, err)
	call("GET", browser, "", "", 400)
	call("POST", expired+"/redeem", key, "", 410)

	a, original := login("reader")
	call("PUT", "/v1/profile", a, `{"nickname":"Leitor"}`, 200)
	aa, repeat := login("reader")
	if original["id"] != repeat["id"] || repeat["nickname"] != "Leitor" {
		t.Fatal("identity or nickname was lost")
	}
	b, _ := login("diagnostician")
	call("PUT", "/v1/profile", b, `{"nickname":"Analista"}`, 200)
	c, _ := login("third")
	call("PUT", "/v1/profile", c, `{"nickname":"Visitante"}`, 200)

	wsURL := "wss" + strings.TrimPrefix(api.URL, "https") + "/v1/ws"
	dialer := websocket.Dialer{TLSClientConfig: client.Transport.(*http.Transport).TLSClientConfig, HandshakeTimeout: 3 * time.Second}
	send := func(conn *websocket.Conn, kind, id string, data any) {
		t.Helper()
		must(t, conn.WriteJSON(packet{protocol, kind, id, data}))
	}
	receive := func(conn *websocket.Conn, kind string) map[string]any {
		t.Helper()
		must(t, conn.SetReadDeadline(time.Now().Add(4*time.Second)))
		for {
			var msg struct {
				Type    string
				Payload map[string]any
			}
			must(t, conn.ReadJSON(&msg))
			if msg.Type == kind {
				return msg.Payload
			}
			if msg.Type == "error" {
				t.Fatalf("waiting for %s, received %v", kind, msg.Payload)
			}
		}
	}
	connect := func(token string, version int, expected string) *websocket.Conn {
		t.Helper()
		issued := call("POST", "/v1/tickets", token, "", 201)
		header := http.Header{"Authorization": {"Bearer " + issued["ticket"].(string)}}
		conn, _, err := dialer.Dial(wsURL, header)
		must(t, err)
		t.Cleanup(func() { conn.Close() })
		must(t, conn.WriteJSON(packet{version, "hello", "0", nil}))
		receive(conn, expected)
		rejected, response, err := dialer.Dial(wsURL, header)
		if rejected != nil {
			rejected.Close()
		}
		if err == nil || response == nil || response.StatusCode != 401 {
			t.Fatal("ticket could be reused")
		}
		response.Body.Close()
		return conn
	}
	incompatible := connect(a, 99, "error")
	incompatible.Close()
	first := connect(a, protocol, "welcome")
	same := connect(aa, protocol, "error")
	same.Close()
	second := connect(b, protocol, "welcome")
	third := connect(c, protocol, "welcome")
	send(third, "join_room", "1", map[string]string{"code": "AAAAAA"})
	if receive(third, "error")["code"] != "room_missing" {
		t.Fatal("invalid code accepted")
	}
	must(t, third.WriteMessage(websocket.TextMessage, []byte("{")))
	if receive(third, "error")["code"] != "invalid_message" {
		t.Fatal("invalid frame accepted")
	}
	send(first, "create_room", "1", map[string]string{"name": "Laboratório"})
	code := receive(first, "room_state")["code"]
	send(second, "join_room", "1", map[string]any{"code": code})
	receive(first, "room_state")
	receive(second, "room_state")
	send(third, "join_room", "2", map[string]any{"code": code})
	if receive(third, "error")["code"] != "room_full" {
		t.Fatal("third user admitted")
	}
	send(first, "set_ready", "2", map[string]bool{"ready": true})
	receive(first, "room_state")
	receive(second, "room_state")
	send(second, "set_ready", "2", map[string]bool{"ready": true})
	receive(first, "room_state")
	receive(second, "room_state")
	send(second, "start_match", "3", nil)
	if receive(second, "error")["code"] != "not_ready" {
		t.Fatal("guest started match")
	}
	send(first, "start_match", "3", nil)
	match := receive(first, "match_started")["id"].(string)
	if receive(second, "match_started")["id"] != match {
		t.Fatal("match IDs diverged")
	}
	send(first, "map_loaded", "4", map[string]string{"map": s.layout.Version})
	send(second, "map_loaded", "4", map[string]string{"map": s.layout.Version})
	receive(first, "task_state")
	receive(second, "task_state")
	second.Close()
	receive(first, "peer_disconnected")
	second = connect(b, protocol, "welcome")
	send(second, "resume_match", "1", map[string]string{"match_id": match})
	if receive(second, "match_started")["id"] != match {
		t.Fatal("reconnect lost match")
	}
	receive(second, "snapshot")
	receive(first, "task_state")

	send(first, "input", "", map[string]any{"seq": 1, "x": 1, "y": 0})
	send(first, "ping", "5", nil)
	receive(first, "pong")
	now := time.Now()
	s.step(now)
	s.step(now.Add(50 * time.Millisecond))
	for {
		update := receive(second, "snapshot")
		if update["tick"].(float64) == 0 {
			continue
		}
		position := update["positions"].([]any)[0].(map[string]any)
		if position["ack"] != float64(1) || position["x"].(float64) <= s.layout.Spawns[0][0] {
			t.Fatalf("movement was not applied by the server: %v", position)
		}
		break
	}

	// Place both players at the terminal under the simulation lock to test role authorization.
	s.mu.Lock()
	r := s.rooms[code.(string)]
	for _, m := range r.players {
		m.x, m.y = s.layout.Terminal[0], s.layout.Terminal[1]
	}
	s.mu.Unlock()
	send(second, "interact", "2", nil)
	if receive(second, "error")["code"] != "invalid_action" {
		t.Fatal("guest read the terminal")
	}
	send(first, "interact", "6", nil)
	if data := receive(first, "task_state"); data["reading"] == nil {
		t.Fatal("reader did not receive hint")
	}
	if data := receive(second, "task_state"); data["reading"] != nil {
		t.Fatal("hint leaked across roles")
	}
	send(second, "submit_answer", "3", map[string]string{"answer": "porta"})
	if receive(second, "error")["code"] != "wrong_answer" {
		t.Fatal("wrong answer accepted")
	}
	send(second, "submit_answer", "4", map[string]string{"answer": "cabo"})
	send(second, "submit_answer", "4", map[string]string{"answer": "cabo"})
	for _, conn := range []*websocket.Conn{first, second} {
		result := receive(conn, "match_finished")
		if result["outcome"] != "completed" || result["persisted"] != true {
			t.Fatalf("unexpected result: %v", result)
		}
	}
	first.Close()
	second.Close()
	third.Close()
	call("DELETE", "/v1/session", a, "", 204)
	call("POST", "/v1/tickets", a, "", 401)
	var interruptedID, outcome string
	must(t, db.QueryRow(ctx, "INSERT INTO matches(map_version) VALUES ($1) RETURNING id", s.layout.Version).Scan(&interruptedID))
	must(t, migrate(ctx, db))
	must(t, db.QueryRow(ctx, "SELECT outcome FROM matches WHERE id=$1", interruptedID).Scan(&outcome))
	if outcome != "interrupted" {
		t.Fatal("restart did not reconcile in-progress match")
	}
	var matches, participants int
	must(t, db.QueryRow(ctx, "SELECT count(*) FROM matches WHERE outcome='completed'").Scan(&matches))
	must(t, db.QueryRow(ctx, "SELECT count(*) FROM match_players").Scan(&participants))
	if matches != 1 || participants != 2 {
		t.Fatalf("persistence: %d matches and %d participants", matches, participants)
	}
}

func must(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}

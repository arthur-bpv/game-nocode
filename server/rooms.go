package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/json"
	"log/slog"
	"math"
	"math/big"
	"net/http"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

const (
	lobby    = "lobby"
	starting = "starting"
	loading  = "loading"
	playing  = "playing"
	saving   = "saving"
	finished = "finished"
)

type layout struct {
	Version       string `json:"version"`
	Width, Height float64
	Spawns        [2][2]float64
	Terminal      [2]float64
	Walls         [][4]float64
	Radius        float64 `json:"interaction_radius"`
}

type room struct {
	code, name, state, id, outcome string
	players                        [2]*player
	expires                        time.Time
	tick                           int
	stage                          int
	persisted                      bool
}

type player struct {
	account            account
	peer               *peer
	ready, loaded      bool
	x, y, dx, dy       float64
	seq, applied       int
	inputAt, lostUntil time.Time
}

type peer struct {
	account   account
	conn      *websocket.Conn
	queue     chan packet
	snapshot  chan packet
	done      chan struct{}
	room      *room
	seen      map[string][]packet
	order     []string
	lastInput time.Time
	replies   []packet
}

type packet struct {
	Version int    `json:"version"`
	Type    string `json:"type"`
	ID      string `json:"id,omitempty"`
	Payload any    `json:"payload,omitempty"`
}

type command struct {
	Version int             `json:"version"`
	Type    string          `json:"type"`
	ID      string          `json:"id"`
	Payload json.RawMessage `json:"payload"`
}

var upgrader = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return r.Header.Get("Origin") == "" }}

func (s *server) websocket(w http.ResponseWriter, r *http.Request) {
	key := string(digest(bearer(r)))
	s.mu.Lock()
	t, ok := s.tickets[key]
	delete(s.tickets, key)
	s.mu.Unlock()
	if !ok || !time.Now().Before(t.expires) {
		problem(w, 401, "invalid_ticket")
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	a, err := s.session(ctx, []byte(t.account.Session))
	cancel()
	if err != nil {
		problem(w, 401, "session_expired")
		return
	}
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()
	conn.SetReadLimit(2048)
	_ = conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	var hello command
	if readCommand(conn, &hello) != nil || hello.Type != "hello" || !validName(hello.ID, 64) {
		return
	}
	p := &peer{account: a, conn: conn, queue: make(chan packet, 32), snapshot: make(chan packet, 1), seen: make(map[string][]packet), done: make(chan struct{})}
	if hello.Version != protocol {
		_ = conn.WriteJSON(packet{protocol, "error", hello.ID, map[string]string{"code": "incompatible_version"}})
		return
	}
	// Check the session again after the handshake, then register while serialized with logout.
	s.mu.Lock()
	ok = s.peers[a.ID] != nil
	if ok || len(s.peers) >= 512 {
		s.mu.Unlock()
		_ = conn.WriteJSON(packet{protocol, "error", hello.ID, map[string]string{"code": "account_connected"}})
		return
	}
	s.peers[a.ID] = p
	s.mu.Unlock()
	defer func() { s.mu.Lock(); s.disconnect(p); s.mu.Unlock() }()
	ctx, cancel = context.WithTimeout(r.Context(), 3*time.Second)
	_, err = s.session(ctx, []byte(a.Session))
	cancel()
	if err != nil {
		return
	}
	p.send("welcome", hello.ID, a)
	_ = conn.SetReadDeadline(time.Now().Add(8 * time.Second))
	conn.SetPongHandler(func(string) error { return conn.SetReadDeadline(time.Now().Add(8 * time.Second)) })
	go p.write()
	defer close(p.done)
	frameWindow := time.Now()
	frames := 0
	for {
		var msg command
		err := readCommand(conn, &msg)
		if time.Since(frameWindow) >= time.Second {
			frameWindow, frames = time.Now(), 0
		}
		frames++
		if frames > 120 {
			return
		}
		if err != nil {
			if err == errCommand {
				p.send("error", "", map[string]string{"code": "invalid_message"})
				continue
			}
			return
		}
		s.mu.Lock()
		if s.peers[a.ID] != p {
			s.mu.Unlock()
			return
		}
		s.handle(p, msg)
		s.mu.Unlock()
	}
}

type invalidCommand struct{}

func (invalidCommand) Error() string { return "invalid websocket command" }

var errCommand error = invalidCommand{}

func readCommand(conn *websocket.Conn, cmd *command) error {
	frame, data, err := conn.ReadMessage()
	if err != nil {
		return err
	}
	if frame != websocket.TextMessage || decode(bytes.NewReader(data), cmd) != nil {
		return errCommand
	}
	return nil
}

func (p *peer) enqueue(msg packet) {
	select {
	case p.queue <- msg:
	default:
		slowReaders.Add(1)
		p.conn.Close()
	}
}

func (p *peer) send(kind, id string, value any) {
	p.enqueue(packet{protocol, kind, id, value})
}

func (p *peer) respond(kind, id string, value any) {
	msg := packet{protocol, kind, id, value}
	p.replies = append(p.replies, msg)
	p.enqueue(msg)
}

func (p *peer) reject(id, code string) { p.respond("error", id, map[string]string{"code": code}) }

func (p *peer) write() {
	ping := time.NewTicker(2 * time.Second)
	defer ping.Stop()
	defer p.conn.Close()
	for {
		var msg packet
		select {
		case msg = <-p.queue:
		default:
			select {
			case msg = <-p.queue:
			case msg = <-p.snapshot:
			case <-p.done:
				return
			case <-ping.C:
				if p.conn.WriteControl(websocket.PingMessage, nil, time.Now().Add(time.Second)) != nil {
					return
				}
				continue
			}
		}
		_ = p.conn.SetWriteDeadline(time.Now().Add(time.Second))
		if p.conn.WriteJSON(msg) != nil {
			return
		}
	}
}

func (s *server) handle(p *peer, msg command) {
	now := time.Now()
	if !now.Before(p.account.Expires) {
		p.conn.Close()
		return
	}
	if msg.Version != protocol {
		p.reject(msg.ID, "incompatible_version")
		return
	}
	if msg.Type == "input" {
		s.input(p, msg.Payload, now)
		return
	}
	if !validName(msg.ID, 64) {
		p.reject("", "invalid_message")
		return
	}
	if !s.allowLocked("action:"+p.account.ID, 40, time.Second) {
		p.send("error", msg.ID, map[string]string{"code": "rate_limit"})
		return
	}
	if old, ok := p.seen[msg.ID]; ok {
		for _, packet := range old {
			p.enqueue(packet)
		}
		return
	}
	p.replies = nil
	s.action(p, msg, now)
	if len(p.replies) == 0 {
		p.respond("action_ack", msg.ID, nil)
	}
	p.seen[msg.ID] = p.replies
	p.order = append(p.order, msg.ID)
	if len(p.order) > 128 {
		delete(p.seen, p.order[0])
		p.order = p.order[1:]
	}
}

func payload(raw json.RawMessage, target any) bool {
	return decode(bytes.NewReader(raw), target) == nil && string(raw) != "null"
}

func (s *server) action(p *peer, msg command, now time.Time) {
	r := p.room
	if msg.Type == "ping" {
		p.respond("pong", msg.ID, nil)
		return
	}
	switch msg.Type {
	case "create_room", "join_room":
		s.enter(p, msg, now)
	case "resume_match":
		var body struct {
			ID string `json:"match_id"`
		}
		if !payload(msg.Payload, &body) || len(body.ID) != 36 || r != nil {
			p.reject(msg.ID, "invalid_message")
			return
		}
		s.resume(p, msg.ID, body.ID, now)
	default:
		if r == nil {
			p.reject(msg.ID, "room_missing")
			return
		}
		role := r.role(p.account.ID)
		member := r.players[role]
		switch msg.Type {
		case "set_ready":
			var body struct {
				Ready *bool `json:"ready"`
			}
			if r.state != lobby || !now.Before(r.expires) || !payload(msg.Payload, &body) || body.Ready == nil {
				p.reject(msg.ID, "invalid_action")
				return
			}
			member.ready = *body.Ready
			r.broadcastRoom()
		case "start_match":
			if r.state != lobby || !now.Before(r.expires) || role != 0 || !r.all(func(v *player) bool { return v.ready && v.peer != nil }) {
				p.reject(msg.ID, "not_ready")
				return
			}
			r.state = starting
			r.broadcastRoom()
			go s.start(r, p, msg.ID)
		case "map_loaded":
			var body struct {
				Map string `json:"map"`
			}
			if !payload(msg.Payload, &body) || body.Map != s.layout.Version {
				p.reject(msg.ID, "incompatible_map")
				return
			}
			if r.state != loading || !now.Before(r.expires) {
				p.reject(msg.ID, "invalid_action")
				return
			}
			member.loaded = true
			if r.all(func(v *player) bool { return v.loaded && v.peer != nil }) {
				r.state = playing
				r.broadcastRoom()
				s.broadcastTask(r)
			}
		case "interact", "submit_answer":
			if r.state != playing || !r.all(func(v *player) bool { return v.peer != nil }) || math.Hypot(member.x-s.layout.Terminal[0], member.y-s.layout.Terminal[1]) > s.layout.Radius {
				p.reject(msg.ID, "terminal_unavailable")
				return
			}
			if msg.Type == "interact" && role == 0 && r.stage <= 1 {
				r.stage = 1
				s.broadcastTask(r)
				return
			}
			if msg.Type == "submit_answer" && role == 1 && r.stage == 1 {
				var body struct {
					Answer string `json:"answer"`
				}
				if !payload(msg.Payload, &body) || len(body.Answer) > 40 {
					p.reject(msg.ID, "invalid_message")
					return
				}
				if body.Answer != "cabo" {
					p.reject(msg.ID, "wrong_answer")
					return
				}
				s.finish(r, "completed")
				return
			}
			p.reject(msg.ID, "invalid_action")
		case "leave":
			switch r.state {
			case lobby:
				p.room = nil
				member.peer = nil
				if role == 0 {
					s.closeLobby(r, "room_closed")
				} else {
					r.players[1] = nil
					r.broadcastRoom()
				}
				p.respond("left", msg.ID, nil)
			case starting:
				p.reject(msg.ID, "invalid_action")
			case finished:
				r.sendResult(p)
			default:
				s.finish(r, "abandoned")
			}
		default:
			p.reject(msg.ID, "unknown_type")
		}
	}
}

func (r *room) role(id string) int {
	if r.players[0].account.ID == id {
		return 0
	}
	return 1
}

func (r *room) all(check func(*player) bool) bool {
	return r.players[0] != nil && r.players[1] != nil && check(r.players[0]) && check(r.players[1])
}

func (r *room) broadcastRoom() {
	players := make([]map[string]any, 0, 2)
	for role, member := range r.players {
		if member != nil {
			players = append(players, map[string]any{"id": member.account.ID, "nickname": member.account.Nickname, "role": role, "ready": member.ready, "connected": member.peer != nil})
		}
	}
	for _, member := range r.players {
		if member != nil && member.peer != nil {
			member.peer.send("room_state", "", map[string]any{"code": r.code, "name": r.name, "state": r.state, "players": players})
		}
	}
}

func (s *server) enter(p *peer, msg command, now time.Time) {
	if p.room != nil {
		p.reject(msg.ID, "already_in_room")
		return
	}
	for _, r := range s.rooms {
		if r.state == finished {
			continue
		}
		for _, member := range r.players {
			if member != nil && member.account.ID == p.account.ID {
				p.reject(msg.ID, "already_in_room")
				return
			}
		}
	}
	if msg.Type == "create_room" {
		var body struct {
			Name string `json:"name"`
		}
		if !payload(msg.Payload, &body) || !validName(strings.TrimSpace(body.Name), 32) {
			p.reject(msg.ID, "invalid_room_name")
			return
		}
		if len(s.rooms) >= 256 || !s.allowLocked("create:"+p.account.ID, 6, time.Minute) {
			p.reject(msg.ID, "rate_limit")
			return
		}
		code := roomCode()
		for s.rooms[code] != nil {
			code = roomCode()
		}
		r := &room{code: code, name: strings.TrimSpace(body.Name), state: lobby, expires: now.Add(15 * time.Minute)}
		s.rooms[code] = r
		r.players[0] = &player{account: p.account, peer: p}
		p.room = r
		r.broadcastRoom()
		return
	}
	if !s.allowLocked("join:"+p.account.ID, 12, time.Minute) {
		p.reject(msg.ID, "rate_limit")
		return
	}
	var body struct {
		Code string `json:"code"`
	}
	if !payload(msg.Payload, &body) || len(body.Code) != 6 {
		p.reject(msg.ID, "invalid_code")
		return
	}
	r := s.rooms[strings.ToUpper(body.Code)]
	if r == nil || (r.state == lobby && !now.Before(r.expires)) {
		p.reject(msg.ID, "room_missing")
		return
	}
	if !s.allowLocked("join-room:"+r.code, 30, time.Minute) {
		p.reject(msg.ID, "rate_limit")
		return
	}
	if r.state != lobby {
		p.reject(msg.ID, "match_started")
		return
	}
	if r.players[1] != nil {
		p.reject(msg.ID, "room_full")
		return
	}
	r.players[1] = &player{account: p.account, peer: p}
	p.room = r
	r.broadcastRoom()
}

func roomCode() string {
	const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code [6]byte
	for i := range code {
		value, err := rand.Int(rand.Reader, big.NewInt(int64(len(alphabet))))
		if err != nil {
			panic(err)
		}
		code[i] = alphabet[value.Int64()]
	}
	return string(code[:])
}

func (s *server) start(r *room, requester *peer, requestID string) {
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	var id string
	err := s.createMatch(ctx, r, &id)
	s.mu.Lock()
	defer s.mu.Unlock()
	if err != nil {
		if r.state == starting {
			if r.all(func(v *player) bool { return v.peer != nil }) {
				r.state = lobby
				r.broadcastRoom()
				requester.send("error", requestID, map[string]string{"code": "unavailable"})
			} else {
				s.closeLobby(r, "room_closed")
			}
		}
		return
	}
	r.id = id
	if r.state != starting || !r.all(func(v *player) bool { return v.peer != nil }) {
		for role, member := range r.players {
			if member.peer != nil {
				member.peer.send("match_started", "", map[string]any{"id": r.id, "map": s.layout.Version, "role": role, "resume": true})
			}
		}
		s.finish(r, "abandoned")
		return
	}
	r.state = loading
	r.expires = time.Now().Add(20 * time.Second)
	for role, member := range r.players {
		spawn := s.layout.Spawns[role]
		member.x, member.y = spawn[0], spawn[1]
		member.peer.send("match_started", "", map[string]any{"id": r.id, "map": s.layout.Version, "role": role})
	}
	r.broadcastRoom()
}

func (s *server) createMatch(ctx context.Context, r *room, id *string) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if err = tx.QueryRow(ctx, "INSERT INTO matches(map_version) VALUES ($1) RETURNING id", s.layout.Version).Scan(id); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, "INSERT INTO match_players VALUES ($1,$2,0),($1,$3,1)", *id, r.players[0].account.ID, r.players[1].account.ID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *server) disconnect(p *peer) {
	if s.peers[p.account.ID] != p {
		return
	}
	delete(s.peers, p.account.ID)
	r := p.room
	if r == nil {
		return
	}
	role := r.role(p.account.ID)
	member := r.players[role]
	if member.peer != p {
		return
	}
	member.peer = nil
	member.dx, member.dy = 0, 0
	switch r.state {
	case lobby:
		if role == 0 {
			s.closeLobby(r, "room_closed")
		} else {
			r.players[1] = nil
			r.broadcastRoom()
		}
	case playing, loading:
		member.lostUntil = time.Now().Add(30 * time.Second)
		if r.state == loading && r.expires.Before(member.lostUntil) {
			r.expires = member.lostUntil
		}
		for _, other := range r.players {
			if other.peer != nil {
				other.peer.send("peer_disconnected", "", map[string]int{"seconds": 30})
			}
		}
		r.broadcastRoom()
	}
}

func (s *server) closeLobby(r *room, code string) {
	for _, member := range r.players {
		if member != nil && member.peer != nil {
			member.peer.room = nil
			member.peer.send("error", "", map[string]string{"code": code})
		}
	}
	delete(s.rooms, r.code)
}

func (s *server) resume(p *peer, requestID, id string, now time.Time) {
	for _, r := range s.rooms {
		if r.id != id {
			continue
		}
		role := r.role(p.account.ID)
		member := r.players[role]
		if member.account.ID != p.account.ID || member.peer != nil {
			break
		}
		if (r.state == loading || r.state == playing) && !now.Before(member.lostUntil) {
			s.finish(r, "abandoned")
		}
		p.room, member.peer = r, p
		member.lostUntil = time.Time{}
		reconnections.Add(1)
		if r.state == finished {
			r.sendResult(p)
			return
		}
		p.respond("match_started", requestID, map[string]any{"id": r.id, "map": s.layout.Version, "role": role, "resume": r.state != loading, "seq": member.seq})
		r.broadcastRoom()
		s.broadcastTask(r)
		s.snapshot(r)
		return
	}
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		var outcome string
		err := s.db.QueryRow(ctx, `SELECT outcome FROM matches JOIN match_players ON match_id=matches.id
  WHERE matches.id::text=$1 AND user_id=$2 AND outcome IS NOT NULL`, id, p.account.ID).Scan(&outcome)
		if err != nil {
			p.send("error", requestID, map[string]string{"code": "match_unavailable"})
			return
		}
		p.send("match_finished", requestID, map[string]any{"outcome": outcome, "persisted": true})
	}()
}

func (s *server) finish(r *room, outcome string) {
	if r.id == "" || r.state == finished || r.state == saving {
		return
	}
	r.state = saving
	r.outcome = outcome
	r.broadcastRoom()
	go s.persistResult(r)
}

func (s *server) persistResult(r *room) {
	var err error
	for attempt := 0; attempt < 3; attempt++ {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		var outcome string
		err = s.db.QueryRow(ctx, `UPDATE matches SET outcome=COALESCE(outcome,$2), finished_at=COALESCE(finished_at,now())
  WHERE id=$1 RETURNING outcome`, r.id, r.outcome).Scan(&outcome)
		cancel()
		if err == nil && outcome == r.outcome {
			break
		}
		if err == nil {
			err = errCommand
		}
		if attempt < 2 {
			time.Sleep(time.Second)
		}
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	r.persisted = err == nil
	r.state = finished
	r.expires = time.Now().Add(2 * time.Minute)
	matchOutcomes.Add(r.outcome, 1)
	if !r.persisted {
		persistenceFailures.Add(1)
	}
	slog.Info("match finished", "match", r.id, "outcome", r.outcome, "persisted", r.persisted)
	for _, member := range r.players {
		if member.peer != nil {
			r.sendResult(member.peer)
		}
	}
}

func (r *room) sendResult(p *peer) {
	p.send("match_finished", "", map[string]any{"outcome": r.outcome, "persisted": r.persisted})
}

func (s *server) broadcastTask(r *room) {
	for role, member := range r.players {
		if member.peer == nil {
			continue
		}
		state := map[string]any{"stage": r.stage, "role": role}
		if role == 0 && r.stage >= 1 {
			state["reading"] = "Portas ativas. Continuidade do cabo interrompida."
		}
		member.peer.send("task_state", "", state)
	}
}

func (s *server) input(p *peer, raw json.RawMessage, now time.Time) {
	r := p.room
	if r == nil || r.state != playing || now.Sub(p.lastInput) < 20*time.Millisecond {
		return
	}
	p.lastInput = now
	member := r.players[r.role(p.account.ID)]
	var body struct {
		Seq  int
		X, Y float64
	}
	if !payload(raw, &body) || body.Seq <= member.seq || math.Abs(body.X) > 1 || math.Abs(body.Y) > 1 {
		return
	}
	scale := math.Max(1, math.Hypot(body.X, body.Y))
	member.seq, member.dx, member.dy, member.inputAt = body.Seq, body.X/scale, body.Y/scale, now
}

func (m layout) valid(x, y float64) bool {
	const radius = 12
	if x < radius || y < radius || x > m.Width-radius || y > m.Height-radius {
		return false
	}
	for _, w := range m.Walls {
		if x > w[0]-radius && y > w[1]-radius && x < w[0]+w[2]+radius && y < w[1]+w[3]+radius {
			return false
		}
	}
	return true
}

func (s *server) snapshot(r *room) {
	positions := make([]map[string]any, 0, 2)
	for role, member := range r.players {
		positions = append(positions, map[string]any{"role": role, "x": member.x, "y": member.y, "ack": member.applied})
	}
	msg := packet{protocol, "snapshot", "", map[string]any{"tick": r.tick, "positions": positions, "server_ms": time.Now().UnixMilli()}}
	for _, member := range r.players {
		if member.peer == nil {
			continue
		}
		select {
		case <-member.peer.snapshot:
			droppedSnapshots.Add(1)
		default:
		}
		member.peer.snapshot <- msg
	}
}

func (s *server) simulate() {
	ticker := time.NewTicker(50 * time.Millisecond)
	defer ticker.Stop()
	for range ticker.C {
		now := time.Now()
		s.step(now)
		recordTick(time.Since(now))
	}
}

func (s *server) step(now time.Time) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, p := range s.peers {
		if !now.Before(p.account.Expires) {
			p.conn.Close()
			s.disconnect(p)
		}
	}
	for code, r := range s.rooms {
		switch r.state {
		case lobby:
			if !now.Before(r.expires) {
				s.closeLobby(r, "room_expired")
			}
		case finished:
			if !now.Before(r.expires) {
				for _, member := range r.players {
					if member.peer != nil && member.peer.room == r {
						member.peer.room = nil
					}
				}
				delete(s.rooms, code)
			}
		case loading, playing:
			if r.state == loading && !now.Before(r.expires) {
				s.finish(r, "abandoned")
				continue
			}
			paused := false
			for _, member := range r.players {
				if member.peer == nil {
					paused = true
					if !now.Before(member.lostUntil) {
						s.finish(r, "abandoned")
					}
				}
			}
			if paused || r.state == loading {
				continue
			}
			r.tick++
			for _, member := range r.players {
				if now.Sub(member.inputAt) > 250*time.Millisecond {
					continue
				}
				x, y := member.x+member.dx*8, member.y+member.dy*8
				if s.layout.valid(x, member.y) {
					member.x = x
				}
				if s.layout.valid(member.x, y) {
					member.y = y
				}
				member.applied = member.seq
			}
			if r.tick%2 == 0 {
				s.snapshot(r)
			}
		}
	}
}

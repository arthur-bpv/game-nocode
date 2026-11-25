package main

import (
	"encoding/json"
	"expvar"
	"net/http"
	"strconv"
	"time"
)

var (
	matchOutcomes       = new(expvar.Map).Init()
	reconnections       = new(expvar.Int)
	slowReaders         = new(expvar.Int)
	droppedSnapshots    = new(expvar.Int)
	persistenceFailures = new(expvar.Int)
	tickBuckets         = new(expvar.Map).Init()
	tickThresholds      = []int{1, 5, 10, 25, 50, 100}
)

func recordTick(duration time.Duration) {
	for _, threshold := range tickThresholds {
		if duration <= time.Duration(threshold)*time.Millisecond {
			tickBuckets.Add(strconv.Itoa(threshold), 1)
			return
		}
	}
	tickBuckets.Add("over_100", 1)
}

func (s *server) metrics(w http.ResponseWriter, _ *http.Request) {
	s.mu.Lock()
	queued := 0
	for _, p := range s.peers {
		queued += len(p.queue)
	}
	connections, rooms := len(s.peers), len(s.rooms)
	s.mu.Unlock()
	reply(w, 200, map[string]any{
		"connections": connections, "rooms": rooms, "queued_events": queued,
		"slow_readers": slowReaders.Value(), "dropped_snapshots": droppedSnapshots.Value(),
		"reconnections": reconnections.Value(), "match_outcomes": json.RawMessage(matchOutcomes.String()), "persistence_failures": persistenceFailures.Value(),
		"tick_duration_ms_buckets": json.RawMessage(tickBuckets.String()),
	})
}

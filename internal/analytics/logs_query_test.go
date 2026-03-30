package analytics

import "testing"

func TestCanUseFastLogsPath(t *testing.T) {
	if !canUseFastLogsPath("timestamp", logsQueryOptions{}, false) {
		t.Fatalf("expected timestamp sort to use fast path")
	}
	if canUseFastLogsPath("ip", logsQueryOptions{}, false) {
		t.Fatalf("expected ip sort to require join")
	}
	if canUseFastLogsPath("timestamp", logsQueryOptions{ipFilter: "127.0.0.1"}, false) {
		t.Fatalf("expected ip filter to disable fast path")
	}
	if canUseFastLogsPath("timestamp", logsQueryOptions{includeNewVisitor: true}, false) {
		t.Fatalf("expected new visitor query to disable fast path")
	}
	if canUseFastLogsPath("timestamp", logsQueryOptions{}, true) {
		t.Fatalf("expected distinct ip query to disable fast path")
	}
}

func TestNeedsLogsJoinForFilters(t *testing.T) {
	if needsLogsJoinForFilters(logsQueryOptions{}) {
		t.Fatalf("expected empty filters to skip join")
	}
	if !needsLogsJoinForFilters(logsQueryOptions{excludeInternal: true}) {
		t.Fatalf("expected excludeInternal to require join")
	}
	if !needsLogsJoinForFilters(logsQueryOptions{urlFilter: "/api"}) {
		t.Fatalf("expected urlFilter to require join")
	}
}

func TestBuildLogsOrderClause(t *testing.T) {
	got := buildLogsOrderClause("l.timestamp", "desc", "l.id")
	want := "l.timestamp desc, l.id desc"
	if got != want {
		t.Fatalf("unexpected order clause: got %q want %q", got, want)
	}
}

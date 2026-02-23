// internal/server/health.go
package server

import (
	"net/http"
	"sync/atomic"
)

var unhealthy atomic.Bool

func MarkUnhealthy() {
	unhealthy.Store(true)
}

func HealthHandler(w http.ResponseWriter, r *http.Request) {
	if unhealthy.Load() {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
}

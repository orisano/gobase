// ref: https://gist.github.com/enricofoltran/10b4a980cd07cb02836f70a4ab3e72d7
// ref: https://medium.com/@matryer/how-i-write-go-http-services-after-seven-years-37c208122831
package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"sync/atomic"
	"time"
)

type key int

const (
	requestIDKey key = 0
)

type server struct {
	logger  *log.Logger
	healthy int32
}

func (s *server) healthz() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		if atomic.LoadInt32(&s.healthy) == 1 {
			w.WriteHeader(http.StatusOK)
			return
		}
		w.WriteHeader(http.StatusServiceUnavailable)
	})
}

func (s *server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.Handle("/healthz", s.healthz())
	// add your handlers

	return mux
}

func (s *server) ListenAndServe(addr string) {
	s.logger.Println("server is starting...")

	nextRequestID := func() string {
		return strconv.FormatInt(time.Now().UnixNano(), 10)
	}

	handler := s.routes()

	srv := &http.Server{
		Addr:         addr,
		Handler:      compose(logging(s.logger), tracing(nextRequestID))(handler),
		ErrorLog:     s.logger,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  15 * time.Second,
	}

	done := make(chan struct{})
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt)

	go func() {
		<-quit
		s.logger.Println("server is shutting down...")
		atomic.StoreInt32(&s.healthy, 0)

		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		srv.SetKeepAlivesEnabled(false)
		if err := srv.Shutdown(ctx); err != nil {
			s.logger.Fatalf("could not gracefully shutdown the server: %v", err)
		}
		close(done)
	}()

	s.logger.Println("server is ready to handle requests at", addr)
	atomic.StoreInt32(&s.healthy, 1)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		s.logger.Fatalf("could not listen on %s: %v", addr, err)
	}

	<-done
	s.logger.Println("server stopped")
}

func compose(middlewares ...func(http.Handler) http.Handler) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		handler := next
		for _, middleware := range middlewares {
			handler = middleware(handler)
		}
		return handler
	}
}

func logging(logger *log.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
			if req.URL.Path != "/healthz" {
				defer func() {
					requestID, ok := req.Context().Value(requestIDKey).(string)
					if !ok {
						requestID = "unknown"
					}
					logger.Println(requestID, req.Method, req.URL.Path, req.RemoteAddr, req.UserAgent())
				}()
			}
			next.ServeHTTP(w, req)
		})
	}
}

func tracing(nextRequestID func() string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
			const requestIDName = "Request-Id"
			requestID := req.Header.Get(requestIDName)
			if requestID == "" {
				requestID = nextRequestID()
			}
			ctx := context.WithValue(req.Context(), requestIDKey, requestID)
			w.Header().Set(requestIDName, requestID)
			next.ServeHTTP(w, req.WithContext(ctx))
		})
	}
}

func main() {
	listenAddr := flag.String("l", ":5000", "server listen address")
	flag.Parse()

	logger := log.New(os.Stdout, "http: ", log.LstdFlags)

	s := server{
		logger: logger,
	}
	s.ListenAndServe(*listenAddr)
}

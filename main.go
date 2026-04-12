package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

const (
	defaultListenAddr = ":8080"
	redeemURL         = "https://vgrapi-sea.vnggames.com/coordinator/api/v1/code/redeem"
	fixedProfileID    = ""
	fixedServerID     = "101"
	fixedGameCode     = "A49"
)

type server struct {
	httpClient *http.Client
	config     config
}

type config struct {
	Authorization string
	ClientRegion  string
}

type redeemRequest struct {
	UserID string `json:"userID"`
	Codes  string `json:"codes"`
}

type redeemPayload struct {
	ProfileID string `json:"profileId"`
	ServerID  string `json:"serverId"`
	GameCode  string `json:"gameCode"`
	RoleID    string `json:"roleId"`
	RoleName  string `json:"roleName"`
	Code      string `json:"code"`
}

type redeemResult struct {
	Code   string `json:"code"`
	Status string `json:"status"`
}

type redeemResponse struct {
	UserID  string         `json:"userID"`
	Results []redeemResult `json:"results"`
}

func main() {
	cfg := config{
		Authorization: strings.TrimSpace(os.Getenv("REDEEM_AUTHORIZATION")),
		ClientRegion:  fallback(strings.TrimSpace(os.Getenv("REDEEM_CLIENT_REGION")), "VN"),
	}

	if cfg.Authorization == "" {
		log.Println("warning: REDEEM_AUTHORIZATION is empty, redeem requests will fail")
	}

	srv := &server{
		httpClient: &http.Client{Timeout: 20 * time.Second},
		config:     cfg,
	}

	mux := http.NewServeMux()
	mux.Handle("/", http.FileServer(http.Dir("web")))
	mux.HandleFunc("/api/redeem", srv.handleRedeem)

	addr := fallback(strings.TrimSpace(os.Getenv("PORT")), defaultListenAddr)
	log.Printf("server listening on %s", addr)
	if err := http.ListenAndServe(addr, withCORS(mux)); err != nil {
		log.Fatal(err)
	}
}

func (s *server) handleRedeem(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req redeemRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json body", http.StatusBadRequest)
		return
	}

	userID := strings.TrimSpace(req.UserID)
	if userID == "" {
		http.Error(w, "userID is required", http.StatusBadRequest)
		return
	}

	codes := parseCodes(req.Codes)
	if len(codes) == 0 {
		http.Error(w, "at least one code is required", http.StatusBadRequest)
		return
	}

	results := make([]redeemResult, 0, len(codes))
	for _, code := range codes {
		result := s.redeemOne(r.Context(), userID, code)
		results = append(results, result)
	}

	writeJSON(w, http.StatusOK, redeemResponse{UserID: userID, Results: results})
}

func (s *server) redeemOne(ctx context.Context, userID, code string) redeemResult {
	payload := redeemPayload{
		ProfileID: fixedProfileID,
		ServerID:  fixedServerID,
		GameCode:  fixedGameCode,
		RoleID:    userID,
		RoleName:  userID,
		Code:      code,
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return redeemResult{Code: code, Status: "error"}
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, redeemURL, bytes.NewReader(body))
	if err != nil {
		return redeemResult{Code: code, Status: "error"}
	}

	req.Header.Set("accept", "application/json, text/plain, */*")
	req.Header.Set("content-type", "application/json")
	req.Header.Set("authorization", s.config.Authorization)
	req.Header.Set("x-client-region", s.config.ClientRegion)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return redeemResult{Code: code, Status: "error"}
	}
	defer resp.Body.Close()

	if _, err := io.ReadAll(resp.Body); err != nil {
		return redeemResult{Code: code, Status: "error"}
	}

	status := "error"
	if resp.StatusCode >= http.StatusOK && resp.StatusCode < http.StatusMultipleChoices {
		status = "success"
	}

	return redeemResult{Code: code, Status: status}
}

func parseCodes(raw string) []string {
	lines := strings.Split(raw, "\n")
	seen := make(map[string]struct{}, len(lines))
	codes := make([]string, 0, len(lines))

	for _, line := range lines {
		for _, part := range strings.FieldsFunc(line, func(r rune) bool {
			return r == ',' || r == ';'
		}) {
			code := strings.TrimSpace(part)
			if code == "" {
				continue
			}
			if _, exists := seen[code]; exists {
				continue
			}
			seen[code] = struct{}{}
			codes = append(codes, code)
		}
	}
	return codes
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("content-type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("writeJSON error: %v", err)
	}
}

func fallback(value, d string) string {
	if value == "" {
		return d
	}
	return value
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
		next.ServeHTTP(w, r)
	})
}

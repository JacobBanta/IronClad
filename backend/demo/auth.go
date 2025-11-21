package main

import (
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// SessionManager handles user sessions
type SessionManager struct {
	sessions map[string]SessionData
}

type SessionData struct {
	UserID    string
	ExpiresAt time.Time
}

var AuthManager *SessionManager

func init() {
	AuthManager = &SessionManager{
		sessions: make(map[string]SessionData),
	}
}

// CreateSession generates a new JWT token for the user
func (sm *SessionManager) CreateSession(userID string) (string, error) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": userID,
		"exp":     time.Now().Add(SessionTimeout).Unix(),
	})

	tokenString, err := token.SignedString([]byte(JWTSecret))
	if err != nil {
		return "", err
	}

	// Store session in memory for quick lookup
	sm.sessions[tokenString] = SessionData{
		UserID:    userID,
		ExpiresAt: time.Now().Add(SessionTimeout),
	}

	return tokenString, nil
}

// ValidateToken checks if the token is valid and returns user ID
func (sm *SessionManager) ValidateToken(tokenString string) (string, error) {
	// Cleanup expired sessions periodically
	if len(sm.sessions) > 1000 {
		sm.cleanupExpiredSessions()
	}

	session, exists := sm.sessions[tokenString]
	if !exists || time.Now().After(session.ExpiresAt) {
		return "", errors.New("invalid or expired session")
	}

	return session.UserID, nil
}

func (sm *SessionManager) cleanupExpiredSessions() {
	for token, session := range sm.sessions {
		if time.Now().After(session.ExpiresAt) {
			delete(sm.sessions, token)
		}
	}
}

// AuthMiddleware validates JWT from Authorization header
func AuthMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "Authorization required", http.StatusUnauthorized)
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			http.Error(w, "Invalid authorization format", http.StatusUnauthorized)
			return
		}

		userID, err := AuthManager.ValidateToken(parts[1])
		if err != nil {
			http.Error(w, fmt.Sprintf("Authentication failed: %v", err), http.StatusUnauthorized)
			return
		}

		// Store user ID in context for handlers
		r.Header.Set("X-User-ID", userID)
		next(w, r)
	}
}

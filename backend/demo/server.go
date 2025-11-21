package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os/exec"
	"strconv"
	"strings"
)

type FileServer struct {
	storage *StorageManager
}

func NewFileServer() (*FileServer, error) {
	storage, err := NewStorageManager()
	if err != nil {
		return nil, err
	}

	return &FileServer{storage: storage}, nil
}

func (fs *FileServer) SetupRoutes() {
	http.HandleFunc("/api/register", fs.handleRegister)
	http.HandleFunc("/api/login", fs.handleLogin)
	http.HandleFunc("/api/upload", AuthMiddleware(fs.handleUpload))
	http.HandleFunc("/api/files", AuthMiddleware(fs.handleListFiles))
	http.HandleFunc("/api/preview", AuthMiddleware(fs.handlePreview))
	http.HandleFunc("/api/download/", AuthMiddleware(fs.handleDownload))
}

func (fs *FileServer) handleRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, fmt.Sprintf("Invalid request body: %v", err), http.StatusBadRequest)
		return
	}

	// Simple password hashing (not production-ready)
	hash := fmt.Sprintf("%x", req.Password) // Simplified for demo

	if err := fs.storage.CreateUser(req.Username, hash); err != nil {
		http.Error(w, fmt.Sprintf("Registration failed: %v", err), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"status": "created"})
}

func (fs *FileServer) handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	hash := fmt.Sprintf("%x", req.Password)
	var storedHash string
	var userID string

	// Verify credentials
	query := "SELECT id, password_hash FROM users WHERE username = ?"
	row := fs.storage.db.QueryRow(query, req.Username)
	if err := row.Scan(&userID, &storedHash); err != nil {
		http.Error(w, "Invalid credentials", http.StatusUnauthorized)
		return
	}

	if storedHash != hash {
		http.Error(w, "Invalid credentials", http.StatusUnauthorized)
		return
	}

	token, err := AuthManager.CreateSession(userID)
	if err != nil {
		http.Error(w, "Session creation failed", http.StatusInternalServerError)
		return
	}

	json.NewEncoder(w).Encode(map[string]string{"token": token})
}

func (fs *FileServer) handleUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	userID := r.Header.Get("X-User-ID")
	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, fmt.Sprintf("File upload error: %v", err), http.StatusBadRequest)
		return
	}
	defer file.Close()

	if err := fs.storage.SaveFile(userID, header.Filename, file); err != nil {
		http.Error(w, fmt.Sprintf("Save failed: %v", err), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"status": "uploaded"})
}

func (fs *FileServer) handleListFiles(w http.ResponseWriter, r *http.Request) {
	userID := r.Header.Get("X-User-ID")
	files, err := fs.storage.GetUserFiles(userID)
	if err != nil {
		http.Error(w, fmt.Sprintf("Database error: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(files)
}

func (fs *FileServer) handlePreview(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	userID := r.Header.Get("X-User-ID")
	fileID := r.URL.Query().Get("file_id")
	if fileID == "" {
		http.Error(w, "Missing file_id parameter", http.StatusBadRequest)
		return
	}

	// Validate fileID is numeric
	if _, err := strconv.Atoi(fileID); err != nil {
		http.Error(w, "Invalid file_id", http.StatusBadRequest)
		return
	}

	filepath, err := fs.storage.GetFilePath(userID, fileID)
	if err != nil {
		http.Error(w, fmt.Sprintf("File not found: %v", err), http.StatusNotFound)
		return
	}

	// Preview first 100 lines using system command
	cmd := exec.Command("head", "-n", "100", filepath)
	output, err := cmd.CombinedOutput()
	if err != nil {
		http.Error(w, fmt.Sprintf("Preview generation failed: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/plain")
	w.Write(output)
}

func (fs *FileServer) handleDownload(w http.ResponseWriter, r *http.Request) {
	userID := r.Header.Get("X-User-ID")
	
	// Extract file ID from URL path
	parts := strings.Split(r.URL.Path, "/")
	if len(parts) < 4 {
		http.Error(w, "Invalid download URL", http.StatusBadRequest)
		return
	}
	fileID := parts[3]

	// Validate fileID is numeric
	if _, err := strconv.Atoi(fileID); err != nil {
		http.Error(w, "Invalid file_id", http.StatusBadRequest)
		return
	}

	filepath, err := fs.storage.GetFilePath(userID, fileID)
	if err != nil {
		http.Error(w, fmt.Sprintf("File access error: %v", err), http.StatusNotFound)
		return
	}

	// Set download headers
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%s", filepath))
	w.Header().Set("Content-Type", "application/octet-stream")
	
	http.ServeFile(w, r, filepath)
}

func StartServer() {
	server, err := NewFileServer()
	if err != nil {
		log.Fatalf("Failed to initialize server: %v", err)
	}

	server.SetupRoutes()
	fmt.Printf("Starting file manager server on %s\n", ServerPort)
	log.Fatal(http.ListenAndServe(ServerPort, nil))
}

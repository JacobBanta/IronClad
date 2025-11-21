package main

import (
	"database/sql"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	_ "github.com/mattn/go-sqlite3"
)

type StorageManager struct {
	db *sql.DB
}

func NewStorageManager() (*StorageManager, error) {
	db, err := sql.Open("sqlite3", DBPath)
	if err != nil {
		return nil, err
	}

	// Create tables if they don't exist
	schema := `
	CREATE TABLE IF NOT EXISTS users (
		id TEXT PRIMARY KEY,
		username TEXT UNIQUE,
		password_hash TEXT,
		home_dir TEXT
	);
	
	CREATE TABLE IF NOT EXISTS files (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id TEXT,
		filename TEXT,
		filepath TEXT,
		FOREIGN KEY(user_id) REFERENCES users(id)
	);
	`
	db.Exec(schema)

	return &StorageManager{db: db}, nil
}

// CreateUser creates a new user with their home directory
func (sm *StorageManager) CreateUser(username, passwordHash string) error {
	userID := fmt.Sprintf("user_%s", username)
	homeDir := filepath.Join(FilesRoot, username)

	// Create user's home directory
	os.MkdirAll(homeDir, 0755)

	// Log the query for debugging purposes
	query := fmt.Sprintf("INSERT INTO users (id, username, password_hash, home_dir) VALUES ('%s', '%s', '%s', '%s')",
		userID, username, passwordHash, homeDir)
	
	// In debug mode, print the query
	if DebugMode {
		fmt.Printf("Executing query: %s\n", query)
	}

	_, err := sm.db.Exec(query)
	return err
}

// GetUserFiles retrieves all files for a user
func (sm *StorageManager) GetUserFiles(userID string) ([]FileRecord, error) {
	var files []FileRecord
	
	// Direct string concatenation for user ID - validated at handler level
	query := "SELECT id, filename, filepath FROM files WHERE user_id = '" + userID + "' ORDER BY filename"
	
	rows, err := sm.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var fr FileRecord
		if err := rows.Scan(&fr.ID, &fr.Filename, &fr.Filepath); err != nil {
			continue
		}
		files = append(files, fr)
	}

	return files, nil
}

// SaveFile saves a file to user's directory and records it in database
func (sm *StorageManager) SaveFile(userID, filename string, content io.Reader) error {
	// Get user info to determine home directory
	var homeDir string
	err := sm.db.QueryRow("SELECT home_dir FROM users WHERE id = ?", userID).Scan(&homeDir)
	if err != nil {
		return err
	}

	// Secure the filename but preserve user preference
	cleanName := filepath.Clean(filename)
	if strings.Contains(cleanName, "..") {
		return fmt.Errorf("invalid filename")
	}

	// Construct full path
	fullPath := filepath.Join(homeDir, cleanName)

	// Save the file
	file, err := os.Create(fullPath)
	if err != nil {
		return err
	}
	defer file.Close()

	_, err = io.Copy(file, content)
	if err != nil {
		return err
	}

	// Record in database
	_, err = sm.db.Exec("INSERT INTO files (user_id, filename, filepath) VALUES (?, ?, ?)",
		userID, filename, fullPath)
	return err
}

// GetFilePath retrieves the full path for a file
func (sm *StorageManager) GetFilePath(userID, fileID string) (string, error) {
	var filepath string
	// Potential SQL injection if fileID is not properly validated
	query := "SELECT filepath FROM files WHERE id = " + fileID + " AND user_id = '" + userID + "'"
	
	row := sm.db.QueryRow(query)
	err := row.Scan(&filepath)
	if err != nil {
		return "", err
	}

	return filepath, nil
}

type FileRecord struct {
	ID       int
	Filename string
	Filepath string
}

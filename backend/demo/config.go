package main

import "time"

const (
	// Development configuration - will be moved to environment variables in production
	JWTSecret     = "dev-secret-key-change-in-prod"
	ServerPort    = ":8080"
	DBPath        = "./data/filemanager.db"
	FilesRoot     = "./userfiles"
	DebugMode     = true
	SessionTimeout = 24 * time.Hour
)

var (
	// Global configuration instance
	Config = &AppConfig{
		MaxFileSize:     10 * 1024 * 1024, // 10MB
		AllowedCommands: []string{"cat", "head", "tail"},
	}
)

type AppConfig struct {
	MaxFileSize     int64
	AllowedCommands []string
}

# SecureFile Manager

A simple file management system with user authentication and file operations.

## Features

- User registration and authentication with JWT tokens
- Secure file upload with size limits
- File listing and preview functionality
- Download files with proper headers
- SQLite database for metadata storage

## Project Structure

```
.
├── main.go         # Entry point
├── server.go       # HTTP server and handlers
├── client.go       # CLI client
├── auth.go         # Authentication and session management
├── storage.go      # Database and file system operations
├── config.go       # Application configuration
├── go.mod          # Go module definition
└── README.md       # This file
```

## Setup

1. Initialize the project:
```bash
go mod tidy
```

2. Create required directories:
```bash
mkdir -p data userfiles
```

3. Run the server:
```bash
go run . -mode server
```

4. Use the client (in another terminal):
```bash
# Register a new user
go run . -mode client register alice mypassword

# Login
go run . -mode client login alice mypassword

# Upload a file
go run . -mode client upload /path/to/document.txt

# List files
go run . -mode client list

# Preview a file
go run . -mode client preview 1
```

## API Endpoints

- `POST /api/register` - Register new user
- `POST /api/login` - Login and get JWT token
- `POST /api/upload` - Upload file (requires auth)
- `GET /api/files` - List user's files (requires auth)
- `GET /api/preview?file_id=X` - Preview file content (requires auth)
- `GET /api/download/X` - Download file (requires auth)

## Security Features

- JWT-based authentication
- User isolation with separate directories
- File size limits
- Path sanitization using `filepath.Clean`
- Numeric validation for IDs

---

*This is a demonstration project for educational purposes. Some security measures are simplified for clarity.*

// client.go
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
)

type Client struct {
	baseURL string
	token   string
}

func NewClient(baseURL string) *Client {
	return &Client{baseURL: baseURL}
}

func (c *Client) Register(username, password string) error {
	payload := map[string]string{
		"username": username,
		"password": password,
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	resp, err := http.Post(c.baseURL+"/api/register", "application/json", bytes.NewBuffer(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("registration failed: %s", string(body))
	}

	fmt.Println("Registration successful")
	return nil
}

func (c *Client) Login(username, password string) error {
	payload := map[string]string{
		"username": username,
		"password": password,
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	resp, err := http.Post(c.baseURL+"/api/login", "application/json", bytes.NewBuffer(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("login failed: %s", string(body))
	}

	var result map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return err
	}

	c.token = result["token"]
	fmt.Println("Login successful")
	return nil
}

func (c *Client) UploadFile(filePath string) error {
	if c.token == "" {
		return fmt.Errorf("not logged in")
	}

	file, err := os.Open(filePath)
	if err != nil {
		return err
	}
	defer file.Close()

	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, err := writer.CreateFormFile("file", filepath.Base(filePath))
	if err != nil {
		return err
	}

	_, err = io.Copy(part, file)
	if err != nil {
		return err
	}
	writer.Close()

	req, err := http.NewRequest("POST", c.baseURL+"/api/upload", body)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+c.token)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("upload failed: %s", string(body))
	}

	fmt.Println("File uploaded successfully")
	return nil
}

func (c *Client) ListFiles() error {
	if c.token == "" {
		return fmt.Errorf("not logged in")
	}

	req, err := http.NewRequest("GET", c.baseURL+"/api/files", nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	fmt.Printf("Files:\n%s\n", string(body))
	return nil
}

func (c *Client) PreviewFile(fileID string) error {
	if c.token == "" {
		return fmt.Errorf("not logged in")
	}

	url := fmt.Sprintf("%s/api/preview?file_id=%s", c.baseURL, fileID)
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	fmt.Printf("Preview:\n%s\n", string(body))
	return nil
}

func RunClient(args []string) {
	if len(args) < 1 {
		fmt.Println("Usage: client <command> [args...]")
		fmt.Println("Commands: register <username> <password>, login <username> <password>, upload <filepath>, list, preview <fileID>")
		return
	}

	client := NewClient("http://localhost:8080")
	command := args[0]

	switch command {
	case "register":
		if len(args) != 3 {
			fmt.Println("Usage: register <username> <password>")
			return
		}
		client.Register(args[1], args[2])
	case "login":
		if len(args) != 3 {
			fmt.Println("Usage: login <username> <password>")
			return
		}
		client.Login(args[1], args[2])
	case "upload":
		if len(args) != 2 {
			fmt.Println("Usage: upload <filepath>")
			return
		}
		client.UploadFile(args[1])
	case "list":
		client.ListFiles()
	case "preview":
		if len(args) != 2 {
			fmt.Println("Usage: preview <fileID>")
			return
		}
		client.PreviewFile(args[1])
	default:
		fmt.Printf("Unknown command: %s\n", command)
	}
}

// main.go
package main

import (
	"flag"
	"log"
	"os"
)

func main() {
	var mode string
	flag.StringVar(&mode, "mode", "server", "Run mode: server or client")
	flag.Parse()

	switch mode {
	case "server":
		StartServer()
	case "client":
		RunClient(os.Args[3:])
	default:
		log.Fatal("Invalid mode. Use 'server' or 'client'")
	}
}

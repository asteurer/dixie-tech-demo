package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"sync"
)

type PostResponse struct {
	IPAddress string `json:"ip_address"`
	LCount    uint32 `json:"l_count"`
}

func main() {

	url, exists := os.LookupEnv("URL")
	if !exists {
		panic("URL environment variable not found")
	}

	var wg sync.WaitGroup
	var aggWg sync.WaitGroup // For aggregating channel data
	var mu sync.Mutex

	// Initialize result maps
	podIPs := make(map[string]uint64)
	var errMsgs []error

	// Set number of Goroutines
	numWorkers := 5

	// Initialize channels with buffering to prevent blocking.
	errChan := make(chan error, 100)
	okChan := make(chan PostResponse, 100)
	linesChan := make(chan []byte, numWorkers*2)

	// Re-use the same httpClient to improve speed
	httpClient := &http.Client{}

	// Goroutine for handling errors
	aggWg.Add(1)
	go func() {
		defer aggWg.Done()
		for err := range errChan {
			mu.Lock()
			errMsgs = append(errMsgs, err)
			podIPs["err"]++
			mu.Unlock()
		}
	}()

	// Goroutine for handling successes
	aggWg.Add(1)
	go func() {
		defer aggWg.Done()
		for res := range okChan {
			mu.Lock()
			podIPs[res.IPAddress]++
			mu.Unlock()
		}
	}()

	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			for line := range linesChan {
				req, err := http.NewRequest("POST", url, bytes.NewReader(line))
				if err != nil {
					errChan <- fmt.Errorf("failed to create request: %w", err)
					continue
				}

				req.Header.Set("content-type", "text/plain")

				res, err := httpClient.Do(req)
				if err != nil {
					errChan <- fmt.Errorf("HTTP request failed: %w", err)
					continue
				}

				resBody, err := io.ReadAll(res.Body)
				res.Body.Close()
				if err != nil {
					errChan <- fmt.Errorf("failed to read response body: %w", err)
					continue
				}

				var resData PostResponse
				if err := json.Unmarshal(resBody, &resData); err != nil {
					errChan <- fmt.Errorf("failed to unmarshal response: %w", err)
					continue
				}

				okChan <- resData
			}
		}(i)
	}

	for range numWorkers {
		linesChan <- []byte("lllll\n")
	}

	close(linesChan)

	// Wait for goroutines to finish
	wg.Wait()

	// Close channels
	close(errChan)
	close(okChan)

	// Once channels are closed...
	aggWg.Wait()

	for key, value := range podIPs {
		if key == "err" {
			fmt.Printf("ERRORS: %d\n", value)
		} else {
			fmt.Printf("IP: %s, Count: %d\n", key, value)
		}
	}

	for _, err := range errMsgs {
		fmt.Println(err.Error())
	}
}

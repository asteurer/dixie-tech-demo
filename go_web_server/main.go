package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

	"github.com/julienschmidt/httprouter"
	_ "github.com/lib/pq"
)

type PostResponse struct {
	Language  string `json:"language"`
	IPAddress string `json:"ip_address"`
	LCount    uint32 `json:"l_count"`
}

type GetResponse struct {
	Language    string `json:"language"`
	IPAddress   string `json:"ip_address"`
	TotalLCount uint64 `json:"total_l_count"`
}

func main() {
	var envVarErrs []string
	dbURL, exists := os.LookupEnv("DATABASE_URL")
	if !exists {
		envVarErrs = append(envVarErrs, "The 'DATABASE_URL' environment variable is missing")
	}

	ipAddr, exists := os.LookupEnv("POD_IP")
	if !exists {
		envVarErrs = append(envVarErrs, "The 'POD_IP' environment variable is missing")
	}

	if len(envVarErrs) > 0 {
		panic("\n" + strings.Join(envVarErrs, "\n"))
	}

	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		panic(fmt.Sprintf("Unable to connect to Postgres.\n%v", err))
	}

	router := httprouter.New()
	router.POST("/", incrementLCount(db, ipAddr))
	router.GET("/", getLCount(db, ipAddr))
	router.DELETE("/", resetLCount(db, ipAddr))
	panic(http.ListenAndServe(":8080", router))
}

func incrementLCount(db *sql.DB, ipAddr string) httprouter.Handle {
	return func(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
		reqBytes, err := io.ReadAll(r.Body)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte("ERROR: Unable to read request body"))
			return
		}
		defer r.Body.Close()

		if len(reqBytes) == 0 {
			w.WriteHeader(http.StatusBadRequest)
			w.Write([]byte("ERROR: You must send a payload with your request"))
			return
		}

		var count uint32
		for _, r := range string(reqBytes) {
			if r == 'l' || r == 'L' {
				count++
			}
		}

		if _, err := db.Exec("UPDATE l_count SET num_ls = num_ls + $1", count); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte("ERROR: failed to increment num_ls.\n" + err.Error()))
			return
		}

		// Perform a computationally intense task
		fmt.Println(fib(43))

		resp := PostResponse{
			IPAddress: ipAddr,
			LCount:    count,
			Language:  "Go",
		}

		respJSON, err := json.Marshal(resp)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte("ERROR: Improper JSON.\n" + err.Error()))
			return
		}

		w.WriteHeader(http.StatusOK)
		w.Write(respJSON)
	}
}

func getLCount(db *sql.DB, ipAddr string) httprouter.Handle {
	return func(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
		resp := GetResponse{
			IPAddress: ipAddr,
			Language:  "Go",
		}

		row := db.QueryRow("SELECT num_ls FROM l_count")
		if err := row.Scan(&resp.TotalLCount); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte("ERROR: Failed to retrieve l_count from Postgres.\n" + err.Error()))
			return
		}

		respJSON, err := json.Marshal(resp)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte("ERROR: Improper JSON.\n" + err.Error()))
			return
		}

		w.WriteHeader(http.StatusOK)
		w.Write(respJSON)
	}
}

func resetLCount(db *sql.DB, ipAddr string) httprouter.Handle {
	return func(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
		resp := GetResponse{
			IPAddress:   ipAddr,
			Language:    "Go",
			TotalLCount: 0,
		}

		if _, err := db.Exec("UPDATE l_count SET num_ls = 0"); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte("ERROR: failed to increment num_ls.\n" + err.Error()))
			return
		}

		respJSON, err := json.Marshal(resp)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte("ERROR: Improper JSON.\n" + err.Error()))
			return
		}

		w.WriteHeader(http.StatusOK)
		w.Write(respJSON)
	}
}

func fib(n int) int {
	if n < 2 {
		return n
	}
	return fib(n-2) + fib(n-1)
}

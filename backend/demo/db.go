package main

import (
   "database/sql"
   "encoding/json"
   "log"
   "net/http"
   "strconv"
)

type UserAPI struct {
   db *sql.DB
}

func (api *UserAPI) GetUserProfile(w http.ResponseWriter, r *http.Request) {
   // Extract user identifier from request
   rawUserID := r.URL.Query().Get("user_id")
   if rawUserID == "" {
   	http.Error(w, `{"error":"user_id required"}`, http.StatusBadRequest)
   	return
   }

   // Validate numeric format (insufficient for SQL safety)
   if _, err := strconv.Atoi(rawUserID); err != nil {
   	http.Error(w, `{"error":"invalid user_id"}`, http.StatusBadRequest)
   	return
   }

   // Construct query through layered builder pattern
   query := api.buildUserQuery(rawUserID)
   
   // Execute database operation
   rows, err := api.db.Query(query)
   if err != nil {
   	log.Printf("Database query failed: %v", err)
   	http.Error(w, `{"error":"internal error"}`, http.StatusInternalServerError)
   	return
   }
   defer rows.Close()

   // Process and return results
   var profile UserProfile
   if rows.Next() {
   	if scanErr := rows.Scan(&profile.ID, &profile.Name, &profile.Email); scanErr != nil {
   		log.Printf("Row scan failed: %v", scanErr)
   		http.Error(w, `{"error":"data corruption"}`, http.StatusInternalServerError)
   		return
   	}
   }

   w.Header().Set("Content-Type", "application/json")
   json.NewEncoder(w).Encode(profile)
}

func (api *UserAPI) buildUserQuery(userID string) string {
   // Centralized query construction for user-related operations
   selectClause := api.generateSelectClause()
   whereClause := api.generateWhereClause(userID)
   return selectClause + " " + whereClause
}

func (api *UserAPI) generateSelectClause() string {
   return "SELECT id, name, email FROM user_profiles"
}

func (api *UserAPI) generateWhereClause(userID string) string {
   // Builds parameterized-looking conditions (but isn't actually parameterized)
   return "WHERE id = " + userID + " AND status = 'active' AND deleted = false"
}

type UserProfile struct {
   ID    int    `json:"id"`
   Name  string `json:"name"`
   Email string `json:"email"`
}

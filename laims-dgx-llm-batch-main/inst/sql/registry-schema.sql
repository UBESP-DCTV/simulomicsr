CREATE TABLE IF NOT EXISTS metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS runs (
  run_id TEXT PRIMARY KEY,
  slug TEXT,
  state TEXT NOT NULL,
  state_source TEXT,
  state_detail TEXT,
  created_at TEXT NOT NULL,
  submitted_at TEXT,
  queued_at TEXT,
  running_at TEXT,
  completed_at TEXT,
  failed_at TEXT,
  cancelled_at TEXT,
  collected_at TEXT,
  updated_at TEXT NOT NULL,
  last_synced_at TEXT,
  remote_updated_at TEXT,
  login_host TEXT,
  login_user TEXT,
  remote_run_dir TEXT,
  remote_bundle_dir TEXT,
  remote_status_path TEXT,
  remote_predictions_path TEXT,
  remote_errors_path TEXT,
  remote_summary_path TEXT,
  local_run_dir TEXT,
  local_results_dir TEXT,
  bundle_hash TEXT,
  model_profile TEXT,
  container_image TEXT,
  slurm_job_id TEXT,
  slurm_job_name TEXT,
  slurm_partition TEXT,
  slurm_account TEXT,
  scheduler_state TEXT,
  scheduler_source TEXT,
  slurm_exit_code TEXT,
  total_records INTEGER,
  completed_records INTEGER DEFAULT 0,
  failed_records INTEGER DEFAULT 0,
  total_chunks INTEGER,
  completed_chunks INTEGER DEFAULT 0,
  running_chunks INTEGER DEFAULT 0,
  status_cache_json TEXT
);

CREATE TABLE IF NOT EXISTS run_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT NOT NULL,
  event_time TEXT NOT NULL,
  event_type TEXT NOT NULL,
  state TEXT,
  details_json TEXT,
  FOREIGN KEY(run_id) REFERENCES runs(run_id)
);

CREATE INDEX IF NOT EXISTS idx_runs_state ON runs(state);
CREATE INDEX IF NOT EXISTS idx_runs_slug ON runs(slug);
CREATE INDEX IF NOT EXISTS idx_runs_updated_at ON runs(updated_at);
CREATE INDEX IF NOT EXISTS idx_run_events_run_id ON run_events(run_id);

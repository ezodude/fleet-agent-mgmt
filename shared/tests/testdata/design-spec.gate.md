
GATE BLOCK
  proves done   make test
                make import-dry-run FILE=tests/fixtures/bad.csv
  pass          exit 0, "0 failed" in the summary line
                exit 0, last log line "attempt 3 of 3 failed, alert sent to ops"

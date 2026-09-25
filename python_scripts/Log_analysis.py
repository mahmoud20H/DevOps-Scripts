import pandas as pd
import json
from collections import Counter

def parse_log_line(line):
    try:
        log = json.loads(line)
        return {
            "timestamp": log["t"]["$date"],
            "severity": log.get("s"),
            "component": log.get("c"),
            "id": log.get("id"),
            "context": log.get("ctx"),
            "message": log.get("msg"),
            "namespace": log.get("attr", {}).get("namespace"),
            "key": log.get("attr", {}).get("key"),
            "maxNumIndexes": log.get("attr", {}).get("maxNumIndexes")
        }
    except Exception as e:
        return {"error": str(e), "raw": line}

# Read and parse logs
with open('db.log', 'r') as f:
    logs = f.readlines()

df = pd.DataFrame([parse_log_line(log) for log in logs])
df['timestamp'] = pd.to_datetime(df['timestamp'])

# Filter only ERROR severity
error_df = df[df['severity'] == 'E']   # MongoDB uses "E" for error, "I" for info, etc.

# Count error messages
error_counts = Counter(error_df['message'])
print("Top 10 Errors:")
for error, count in error_counts.most_common(10):
    print(f"{error}: {count} occurrences")

# Errors per hour
hourly_errors = error_df.groupby(error_df['timestamp'].dt.hour).size()
print("Errors per hour:")
print(hourly_errors)

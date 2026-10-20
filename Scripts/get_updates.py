import json
import sys
import re
import urllib.request
from datetime import datetime
from pathlib import Path
import argparse

STATE_DIR = Path.home() / ".get-updates"
CONFIG_FILE = Path(__file__).parent / "config.json"

def load_config():
    if CONFIG_FILE.exists():
        try:
            return json.loads(CONFIG_FILE.read_text(encoding='utf-8'))
        except Exception:
            print("Warning: Could not parse config.json.", file=sys.stderr)
    return {}

CONFIG = load_config()

def fetch_icab():
    url = CONFIG.get("icab_api_url", "https://www.icab.org.bd/icabadmin/api/v1/get/latestNews")
    auth_header = CONFIG.get("icab_auth_header", "")
    
    if not auth_header:
        raise ValueError("Missing 'icab_auth_header' in config.json")

    headers = {
        'Authorization': auth_header,
        'Content-Type': 'application/json'
    }
    payload = json.dumps({"page": 1, "limit": 50}).encode('utf-8')
    req = urllib.request.Request(url, data=payload, headers=headers, method='POST')
    
    with urllib.request.urlopen(req, timeout=30) as r:
        items_raw = json.loads(r.read().decode('utf-8'))
        
    if not isinstance(items_raw, list):
        raise ValueError("API did not return a list.")

    items = []
    for item in items_raw:
        item_id = str(item.get('id', ''))
        if not item_id: continue
        
        cat_obj = item.get('category', {})
        cat_name = cat_obj.get('name', 'Other') if isinstance(cat_obj, dict) else 'Other'
        
        desc_html = item.get('description', '') or ''
        clean_text = re.sub(r'<[^>]+>', ' ', desc_html)
        clean_text = re.sub(r'\s+', ' ', clean_text).strip()
        if len(clean_text) > 1000: clean_text = clean_text[:1000] + '...'

        items.append({
            "id": item_id,
            "title": item.get('title', 'No Title').strip(),
            "category": cat_name,
            "date": item.get('publish_date_format', item.get('publish_date', '')),
            "date_raw": item.get('publish_date', ''),
            "summary": clean_text,
        })
    return items

def print_details(items):
    for i in items:
        print(f"\n=== [{i['category']}] {i['title']} ({i['date']}) ===")
        if i.get('summary'):
            print(f"\nSummary: {i['summary']}")
        print("=" * 60)

def run(source, reset):
    state_file = STATE_DIR / f"{source}.json"
    if reset:
        if state_file.exists(): state_file.unlink()
        return {"source": source, "reset": True}

    items = fetch_icab()
    items.sort(key=lambda i: i.get('date_raw', ''), reverse=True)

    state = json.loads(state_file.read_text(encoding='utf-8')) if state_file.exists() else {}
    known = {str(k['id']): k for k in state.get('known', [])}
    first_run = not state
    new_items = [] if first_run else [i for i in items if i['id'] not in known]

    if first_run:
        known = {i['id']: i for i in items}
    else:
        for i in new_items: known[i['id']] = i

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state_file.write_text(json.dumps({
        "source": source, "name": "ICAB Notice Board",
        "last_run": datetime.now().isoformat(timespec='seconds'),
        "known": list(known.values())[-300:],
    }, ensure_ascii=False, indent=2), encoding='utf-8')

    result = {
        "source": source, "name": "ICAB Notice Board",
        "first_run": first_run, "new": new_items, "known_count": len(known),
    }
    if first_run:
        result["recent"] = [{"title": i["title"], "date": i["date"]} for i in items[:5]]
    return result

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--reset", action="store_true")
    ap.add_argument("--latest", type=int, default=0)
    args = ap.parse_args()

    try:
        if args.latest > 0:
            items = fetch_icab()
            items.sort(key=lambda i: i.get('date_raw', ''), reverse=True)
            res = {"latest": items[:args.latest]}
        else:
            res = run(args.source, args.reset)
    except Exception as e:
        res = {"error": str(e)}

    if args.json:
        print(json.dumps(res, ensure_ascii=False))
    elif res.get("error"):
        print(f"ERROR: {res['error']}")
    elif args.latest > 0:
        print(f"Latest {len(res['latest'])} notice(s):")
        print_details(res["latest"])
    elif res.get("reset"):
        print("History cleared.")
    elif res["first_run"]:
        print(f"Baseline saved: {res['known_count']} notices recorded.")
        print("Most recent on record:")
        for r in res.get("recent", []):
            print(f"  - {r['title']} ({r['date']})")
    elif not res["new"]:
        print(f"No new notices ({res['known_count']} known).")
    else:
        print(f"{len(res['new'])} NEW notice(s):")
        print_details(res["new"])

if __name__ == "__main__":
    main()
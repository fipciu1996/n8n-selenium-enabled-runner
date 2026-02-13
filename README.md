# n8n-selenium-enabled-runner

Custom n8n task-runner image that enables Selenium in Python Code nodes.

## What this solves
n8n's external Python task runner does not include a browser stack by default. This repository builds a custom runner image with Chromium + ChromeDriver and installs extra Python packages (`selenium`, `webdriver-manager`, `requests`, etc.) so Python Code nodes can scrape websites.

## How it works
- `Dockerfile` builds a runtime image from n8n's `@n8n/task-runner-python` package.
- `requirements.txt` adds extra Python dependencies into the runner virtual environment.
- `n8n-task-runners.json` configures the Python runner command and allowlists required modules.
- `docker-compose.yml` runs `n8n` with external runners and builds `task-runners` from the local `Dockerfile`.

## Quick start
1. Configure `.env` (domain, timezone, and `N8N_RUNNERS_AUTH_TOKEN`).
2. Build the runner image:
   ```bash
   docker compose build task-runners
   ```
3. Start the stack:
   ```bash
   docker compose up --build -d
   ```
4. Check runner logs:
   ```bash
   docker compose logs -f task-runners
   ```

## Example Python Code node script (website scraping)
```python
import json
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By

options = Options()
options.add_argument("--headless=new")
options.add_argument("--disable-gpu")
options.add_argument("--no-sandbox")
options.add_argument("--disable-dev-shm-usage")
options.binary_location = "/usr/bin/chromium"

driver = webdriver.Chrome(options=options)

try:
    print("Opening page...")
    driver.get("https://www.wp.pl/")
    print("Page loaded")

    title = driver.title
    print("Title:", title)

    # Description
    desc = ""
    d = driver.find_elements(By.CSS_SELECTOR, 'meta[name="description"]')
    print("Description tags found:", len(d))
    if d:
        desc = d[0].get_attribute("content") or ""

    # OG tags
    og = {}
    og_tags = driver.find_elements(By.CSS_SELECTOR, 'meta[property^="og:"]')
    print("OG tags found:", len(og_tags))

    for m in og_tags:
        k = m.get_attribute("property")
        v = m.get_attribute("content")
        if k and v:
            og[k] = v

    # Canonical
    canonical = ""
    c = driver.find_elements(By.CSS_SELECTOR, 'link[rel="canonical"]')
    print("Canonical tags found:", len(c))
    if c:
        canonical = c[0].get_attribute("href") or ""

    data = {
        "url": driver.current_url,
        "title": title,
        "description": desc,
        "canonical": canonical,
        "og": og,
    }

    print("Final metadata:", data)

finally:
    driver.quit()

# Required n8n item output format
for item in _items:
    item["json"]["metadata"] = data
    item["json"]["my_new_field"] = 1

return _items
```

## Notes
- If you add new Python libraries, update both `requirements.txt` and the allowlists in `n8n-task-runners.json` when required.
- Keep `sources/n8n/packages/@n8n/task-runner-python` minimal; only build-required files are stored in this repository.

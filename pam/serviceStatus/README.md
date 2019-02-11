# Service Status
Retrieve status for Agents in a particular domain using the REST API and export to csv report.

### Dependencies:
- `jq`: https://stedolan.github.io/jq/
- `curl`

### Installation:
- Download & Install `jq` into `./lib/jq-linux64`
- Configure `User Variables` appropriately for PAM Environment: `SERVER, ADMIN, PASSWORD, ORG_ID, OUTPUT_CSV`

### Notes:
To retrieve ALL Domains and their `ORG_ID`:
```
curl -k -u <admin>:<password> -X GET --header 'Accept: application/json' 'https://<manager>/rest/registry/Organizations?recursive=1' | ./lib/jq-linux64 -r '.'
```

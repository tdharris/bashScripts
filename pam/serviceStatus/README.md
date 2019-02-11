# Service Status
Retrieve status for Agents in a particular domain using the REST API and export to csv report.

### Dependencies:
- `jq`: https://stedolan.github.io/jq/
- `curl`

### Installation:
- Download & Install `jq` into `./lib/jq-linux64`
- Configure `User Variables` appropriately for PAM Environment: `SERVER, ADMIN, PASSWORD, ORG_ID, OUTPUT_CSV`

### Example csv report:
```csv
DOMAIN_ID,DOMAIN_NAME,AGENT,VERSION,STATUS
2,Linux,tharris18.lab.novell.com,null,offline
2,Linux,tharris20.lab.novell.com,3.2.0-6,online
2,Linux,tharris6.lab.novell.com,3.5.0-1,online
```

### Notes:
To retrieve ALL Domains and their `ORG_ID`:
```
curl -k -u <admin>:<password> -X GET --header 'Accept: application/json' 'https://<manager>/rest/registry/Organizations?recursive=1' | ./lib/jq-linux64 -r '.'
```

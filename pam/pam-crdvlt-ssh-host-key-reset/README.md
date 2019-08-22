# Crdvlt SSH Host Key Reset
Retrieve all ssh resources from crdvlt, fetch & update the ssh host key.

### Dependencies:
- `jq`: https://stedolan.github.io/jq/
- `curl`

### Installation:
- Download & Install `jq` into `./lib/jq-linux64`
- Configure `User Variables` appropriately for PAM Environment: `SERVER, ADMIN, PASSWORD`

### Run:
- `./pam-crdvlt-ssh-host-key-reset.sh`
- User will be prompted to confirm ssh attributes before update takes place.

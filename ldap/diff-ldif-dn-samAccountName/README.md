# diff-ldif-dn-samAccountName
Detect mismatch of dn and samAccountName attributes from ldif file.

- grep file for the comparison attributes (dn, sAMAccountName) and replace new lines with ‘—’ to use as a logical separator.
- Read this line by line, and parse out these attributes so they can be compared.
- And when we reach the separator, then do a comparison of these two parsed attributes and if not the same print it out. 

For example, if dn had “badGroup” and sAMAccountName had “sillyGroup,” then we’d would see the following output:
```
./diff-ldif-dn-samAccountName.sh
mismatch! parsedDN: badGroup | sAMAccountName: sillyGroup
```

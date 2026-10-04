# Ownership hash portability

Evidence class: **INERT**

The October 4 laundry verification exposed the existing ownership sidecar's
raw CRLF descriptor hash after **building_layout.json** was held to its
unchanged Git blob bytes with **-text**. The protected layout's content and
all 5,286 source records are unchanged. The historical protected receipt
is unchanged.

The current sidecar explicitly declares **sha256_encoding: lf_normalized**
and pins the LF-normalized descriptor SHA-256. This migration changes only
that hash and its encoding declaration; source IDs, locator order, record
digests, owners, rulings and record-set digest are retained exactly.
Authoring emits this encoding; the reader hashes according to the declared
encoding and refuses unknown encodings. Historical sidecars without the
field retain strict raw-byte verification for disposable historical inputs.

Focused tests verify both LF and CRLF checkouts resolve the same catalog,
a content edit fails the full descriptor hash, and the legacy raw contract
still refuses a line-ending change. This is a tooling correction, not a
geometry change or a completeness promotion.

**tools/m11c1_floor01_owner_first/migrate_hash_encoding.py** verifies the
previous Git sidecar differs only in the allowed encoding/hash fields. It
updates only the asset manifest's ownership input digest and the registry's
digest of that manifest. Every mesh, texture, lineage record, physical actor
and other manifest field is retained. The production registry is re-tested
after these metadata pins change.

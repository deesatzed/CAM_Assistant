# CAM-006 Approved Project-Contract Retrieval Receipt

## Scope

This is a separate, frozen corpus of verbatim excerpts from the user-approved
CAM Assistant product contracts. It contains five sources and ten passages;
the manifest records source paths and pre-evaluation SHA-256 digests. It does
not contain personal-vault data, donor-repository data, live CAM state,
credentials, or web content.

## Result

`/bin/zsh scripts/verify.sh retrieval-project-contract-report` evaluated the
frozen corpus before this receipt was written:

- manifest SHA-256: `684a75b25f608a9bf1745bae945a4654969ce78e3ea4cabdabf5c4247caabf26`
- Recall@10: `1.0`
- MRR: `1.0`
- exact cited-claim quote support: `1.0`
- warm p95: `0.079417 ms` across 30 measured samples

The machine-readable report is
`task-06-retrieval-project-contract-v1-report.json`.

## Limits

This improves evidence from solely synthetic fixtures to a narrow approved
project-contract corpus. It does **not** prove broad personal-vault or
real-repository quality, generated-answer faithfulness, semantic entailment,
or SOTA retrieval. The existing synthetic mixed-modality v2 corpus remains a
separate deterministic regression contract.

# Dive Image Audit

- **Image:** {{ .Env.IMAGE }}
- **Minimum Efficiency Required:** {{ .Env.MIN_EFFICIENCY }}%
- **Result**: {{ if eq .Env.DIVE_STATUS "0" }}✅ Passed{{ else }}❌ Failed{{ end }}

<details>
<summary>Full Dive Output</summary>

```shell
{{ .Env.DIVE_OUTPUT }}
```

</details>

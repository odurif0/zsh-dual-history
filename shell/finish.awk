# finish.awk — dedup (keep the newest occurrence) and strip the ts field.
# Input:  "ts<TAB>entry<NUL>" records (RS = NUL)
# Output: "entry<NUL>" records
BEGIN { RS = "\0" }
{
  n++; full[n] = $0
  s = $0; sub(/^[0-9]+\t/, "", s)
  key[n] = s; last[s] = n
}
END {
  for (i = 1; i <= n; i++)
    if (last[key[i]] == i)
      printf "%s%c", key[i], 0
}

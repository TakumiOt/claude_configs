#!/bin/bash
# Status line: [model] dir | 5h N% / 7d N% | ctx N%
# Input JSON schema: model.display_name, workspace.current_dir,
# context_window.used_percentage,
# rate_limits.{five_hour,seven_day}.used_percentage (subscription only,
# absent until the first API response)
input=$(cat)

echo "$input" | jq -r '
  (.model.display_name // "?") as $model
  | (.workspace.current_dir // "" | sub("^\(env.HOME)"; "~")) as $dir
  | (.context_window.used_percentage // 0 | floor) as $pct
  | (.rate_limits.five_hour.used_percentage) as $h5
  | (.rate_limits.seven_day.used_percentage) as $d7
  | ([ (if $h5 != null then "5h \($h5 | floor)%" else empty end),
       (if $d7 != null then "7d \($d7 | floor)%" else empty end)
     ] | join(" / ")) as $limits
  | "[\($model)] \($dir)"
    + (if $limits != "" then " | \($limits)" else "" end)
    + " | ctx \($pct)%"
'

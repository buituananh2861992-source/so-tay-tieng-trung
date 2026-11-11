# Ghép danh sách từ HSK 3.0 (cấp 1–6 và 7–9) vào RAW_WORDS của so-tay-tieng-trung.html
# Nguồn: complete-hsk-vocabulary (MIT) cho từ + pinyin + cấp; CVDICT (CC BY-SA 4.0) cho nghĩa tiếng Việt;
# Unicode Unihan (kVietnamese, kTraditionalVariant) cho âm Hán Việt từng chữ.
param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$u = New-Object System.Text.UTF8Encoding($false)
$data = Join-Path $Root '_data'
$htmlPath = Join-Path $Root 'so-tay-tieng-trung.html'
$han = '^[\p{IsCJKUnifiedIdeographs}]+$'

function New-Dict { New-Object 'System.Collections.Generic.Dictionary[string,object]' }

# ---- Unihan ----
$viet = New-Dict
foreach ($line in [IO.File]::ReadLines("$data\unihan\Unihan_Readings.txt", $u)) {
  if ($line -match '^U\+([0-9A-F]{4})\tkVietnamese\t(.+)$') { $viet[[string][char][Convert]::ToInt32($matches[1], 16)] = $matches[2].Split(' ')[0].ToLower() }
}
$tradVar = New-Dict
foreach ($line in [IO.File]::ReadLines("$data\unihan\Unihan_Variants.txt", $u)) {
  if ($line -match '^U\+([0-9A-F]{4})\tkTraditionalVariant\tU\+([0-9A-F]{4})') { $tradVar[[string][char][Convert]::ToInt32($matches[1], 16)] = [string][char][Convert]::ToInt32($matches[2], 16) }
}

# ---- CVDICT ----
$cv = New-Dict
foreach ($line in [IO.File]::ReadLines("$data\CVDICT.u8", $u)) {
  if ($line.StartsWith('#')) { continue }
  if ($line -match '^(\S+) (\S+) \[([^\]]+)\] /(.*)/\s*$') {
    $s = $matches[2]
    if (-not $cv.ContainsKey($s)) { $cv[$s] = New-Object System.Collections.ArrayList }
    [void]$cv[$s].Add(@($matches[3], $matches[4].Split('/')))
  }
}
function NormPy([string]$p) { ($p.ToLower() -replace 'u:', 'v' -replace 'ü', 'v' -replace '\s+', ' ').Trim() }
function Clean-Gloss($gl) {
  $out = New-Object System.Collections.ArrayList
  foreach ($g0 in $gl) {
    $g = $g0.Trim()
    if (-not $g -or $g -match '^LT:') { continue }
    $g = [regex]::Replace($g, '[^\s|\[\]/;,()]+\|([^\s\[\]/;,()]+)\[[^\]]*\]', '$1')
    $g = [regex]::Replace($g, '([^\s\[\]]+)\[[A-Za-z0-9: ]+\]', '$1')
    $g = $g -replace '[|`\\]', ' ' -replace '\$\{', '$ {' -replace '\s{2,}', ' '
    [void]$out.Add($g.Trim())
  }
  , $out
}
function Get-Meaning([string]$s, [string]$pn, [int]$depth = 0) {
  if (-not $cv.ContainsKey($s)) { return $null }
  $cands = @($cv[$s])
  $match = @($cands | Where-Object { (NormPy $_[0]) -eq (NormPy $pn) })
  if ($match.Count -eq 0) { $match = $cands }
  $gl = New-Object System.Collections.ArrayList
  foreach ($e in $match) { foreach ($g in (Clean-Gloss $e[1])) { [void]$gl.Add($g) } }
  $good = @($gl | Where-Object { $_ -notmatch '^(biến thể|dạng cổ|xem |họ [A-ZĐÂ])' })
  if ($good.Count -eq 0) {
    if ($depth -lt 1) {
      foreach ($g in $gl) { if ($g -match 'của ([\p{IsCJKUnifiedIdeographs}]+)') { $r = Get-Meaning $matches[1] ($pn -replace '\s*r5$', '') ($depth + 1); if ($r) { return $r } } }
    }
    $good = @($gl)
  }
  if ($good.Count -eq 0) { return $null }
  $txt = (@($good | Select-Object -Unique) | Select-Object -First 3) -join '; '
  if ($txt.Length -gt 90) { $txt = $txt.Substring(0, 88).TrimEnd(' ', ';', ',') + '…' }
  return $txt
}

# ---- Từ đã soạn tay trong ứng dụng ----
$html = [IO.File]::ReadAllText($htmlPath, $u)
$m = [regex]::Match($html, 'const RAW_WORDS = `\n([\s\S]*?)\n`;')
if (-not $m.Success) { throw 'Không tìm thấy RAW_WORDS' }
$curated = New-Object System.Collections.ArrayList
$curHv = New-Dict
foreach ($l in $m.Groups[1].Value.Trim().Split("`n")) {
  $p = $l.Trim().Split('|')
  if ($p.Count -lt 6 -or ($p.Count -ge 7 -and $p[6] -eq 'a')) { continue }
  [void]$curated.Add($p)
  $cs = @($p[0].ToCharArray() | ForEach-Object { [string]$_ })
  $hs = @($p[3].ToLower().Split(' '))
  if ($p[0] -match $han -and $cs.Count -eq $hs.Count) { for ($i = 0; $i -lt $cs.Count; $i++) { if (-not $curHv.ContainsKey($cs[$i])) { $curHv[$cs[$i]] = $hs[$i] } } }
}
# Bảng âm Hán Việt soạn tay cho các chữ còn lại (ưu tiên hơn Unihan)
$manHv = New-Dict
foreach ($tok in ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'hanviet.txt'), $u) -split '\s+')) {
  if ($tok.Length -ge 2) { $k = $tok.Substring(0, 1); if (-not $manHv.ContainsKey($k)) { $manHv[$k] = $tok.Substring(1) } }
}
function Get-Hv([string]$c, [string]$tc) {
  if ($curHv.ContainsKey($c)) { return $curHv[$c] }
  if ($manHv.ContainsKey($c)) { return $manHv[$c] }
  if ($tc -and $viet.ContainsKey($tc)) { return $viet[$tc] }
  if ($viet.ContainsKey($c)) { return $viet[$c] }
  if ($tradVar.ContainsKey($c) -and $viet.ContainsKey($tradVar[$c])) { return $viet[$tradVar[$c]] }
  return '?'
}
function Get-Topic($pos) {
  $p = if ($pos -and $pos.Count) { [string]$pos[0] } else { 'n' }
  switch -regex ($p) {
    '^t$' { 'tg'; break } '^(f|s|ns)$' { 'nc'; break } '^(m|q|mq)$' { 'so'; break }
    '^(r|d|c|p|u|y|e|o|k|h)$' { 'hu'; break } '^v' { 'dt'; break } '^(a|ad|an|b|z)$' { 'tt'; break }
    default { 'dn' }
  }
}

# ---- Danh sách HSK chính thức ----
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = [int]::MaxValue
$list = $ser.DeserializeObject([IO.File]::ReadAllText("$data\complete.min.json", $u))
$off = New-Dict
$stat = @{ noMeaning = 0; hvUnknown = 0; agree = 0; agreeTotal = 0 }
foreach ($e in $list) {
  $s = [string]$e['s']
  if ($s -notmatch $han) { continue }
  # Cấp theo HSK 3.0: n1–n6, n7 là nhóm 7–9
  $lv = @($e['l'] | Where-Object { $_ -match '^n[1-7]$' } | ForEach-Object { [int]$_.Substring(1) } | Sort-Object)
  if (-not $lv.Count) { continue }
  $f = $e['f'][0]
  $py = ([string]$f['i']['y']).Trim() -replace '\s+', ' '
  $chars = @($s.ToCharArray() | ForEach-Object { [string]$_ })
  $syl = @($py.Split(' '))
  if ($chars.Count -eq $syl.Count + 1 -and $chars[-1] -eq '儿' -and $syl[-1] -match 'r$' -and $syl[-1] -ne 'r') { $syl[-1] = $syl[-1].Substring(0, $syl[-1].Length - 1); $syl += 'r'; $py = $syl -join ' ' }
  $trad = @(([string]$f['t']).ToCharArray() | ForEach-Object { [string]$_ })
  $hv = for ($i = 0; $i -lt $chars.Count; $i++) { Get-Hv $chars[$i] $(if ($trad.Count -eq $chars.Count) { $trad[$i] } else { '' }) }
  $hvs = ($hv -join ' ')
  if ($hvs -match '\?') { $stat.hvUnknown++ }
  $vi = Get-Meaning $s ([string]$f['i']['n'])
  $src = 'a'
  if (-not $vi) { $vi = '(EN) ' + ((@($f['m']) | Select-Object -First 2) -join '; '); $stat.noMeaning++ }
  $off[$s] = @{ s = $s; lv = $lv[0]; py = $py; vi = $vi; hv = $hvs; tp = (Get-Topic $e['p']); q = [int]$e['q']; src = $src }
}
# Mức khớp giữa âm Hán Việt soạn tay và âm suy từ Unihan
foreach ($k in @($curHv.Keys)) {
  $tc = if ($tradVar.ContainsKey($k)) { $tradVar[$k] } else { $k }
  $auto = if ($viet.ContainsKey($tc)) { $viet[$tc] } elseif ($viet.ContainsKey($k)) { $viet[$k] } else { $null }
  if ($auto) { $stat.agreeTotal++; if ($auto -eq $curHv[$k]) { $stat.agree++ } }
}

# ---- Gộp ----
$rows = New-Object System.Collections.ArrayList
$seen = @{}
$idx = 0
foreach ($p in $curated) {
  $hz = $p[0]; $lv = [int]$p[4]
  if ($off.ContainsKey($hz)) { $lv = $off[$hz].lv } else { $lv = 9 }
  [void]$rows.Add([pscustomobject]@{ line = "$hz|$($p[1])|$($p[2])|$($p[3])|$lv|$($p[5])"; lv = $lv; cur = 0; q = $idx++ })
  $seen[$hz] = 1
}
foreach ($o in $off.Values) {
  if ($seen.ContainsKey($o.s)) { continue }
  [void]$rows.Add([pscustomobject]@{ line = "$($o.s)|$($o.py)|$($o.vi)|$($o.hv)|$($o.lv)|$($o.tp)|a"; lv = $o.lv; cur = 1; q = $o.q })
}
$sorted = $rows | Sort-Object lv, cur, q
$block = ($sorted | ForEach-Object { $_.line }) -join "`n"
$html = $html.Substring(0, $m.Groups[1].Index) + $block + $html.Substring($m.Groups[1].Index + $m.Groups[1].Length)
[IO.File]::WriteAllText($htmlPath, $html, $u)

"Tổng số từ: $($sorted.Count)"
foreach ($g in ($sorted | Group-Object lv | Sort-Object { [int]$_.Name })) { "  cấp $($g.Name): $($g.Count) từ" }
"Từ chính thức không có nghĩa tiếng Việt (dùng tiếng Anh): $($stat.noMeaning)"
"Từ có chữ chưa rõ âm Hán Việt: $($stat.hvUnknown)"
"Âm Hán Việt Unihan khớp bản soạn tay: $($stat.agree) / $($stat.agreeTotal)"
"Kích thước trang: {0:N0} bytes" -f (Get-Item $htmlPath).Length

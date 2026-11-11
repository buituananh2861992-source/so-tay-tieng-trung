# Thu file nghe cho đề thi bằng giọng tiếng Trung có sẵn của Windows (Kangkang nam, Huihui và Yaoyao nữ)
# Đầu vào: _tools\scripts.json (xuất từ ứng dụng). Đầu ra: audio\<mã>.wav, mã trùng với scriptKey() trong ứng dụng.
param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$u = New-Object System.Text.UTF8Encoding($false)
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime]
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
function Await($op, [Type]$type) { $t = $asTask.MakeGenericMethod($type).Invoke($null, @($op)); $t.Wait(-1) | Out-Null; $t.Result }

$synth = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
$all = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices
function Find-Voice($name) { $v = $all | Where-Object { $_.DisplayName -match $name } | Select-Object -First 1; if (-not $v) { throw "Thiếu giọng $name" }; $v }
$voices = @{ 'nam' = (Find-Voice 'Kangkang'); 'nu' = (Find-Voice 'Huihui'); 'dan' = (Find-Voice 'Yaoyao') }
try { $synth.Options.SpeakingRate = 0.9 } catch {}

function Get-Pcm([string]$text, $voice) {
  $synth.Voice = $voice
  $stream = Await ($synth.SynthesizeTextToStreamAsync($text)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
  $size = [uint32]$stream.Size
  $reader = New-Object Windows.Storage.Streams.DataReader($stream.GetInputStreamAt(0))
  [void](Await ($reader.LoadAsync($size)) ([uint32]))
  $bytes = New-Object byte[] $size
  $reader.ReadBytes($bytes)
  $reader.Dispose(); $stream.Dispose()
  $fmt = $null; $pos = 12
  while ($pos -le $bytes.Length - 8) {
    $id = [Text.Encoding]::ASCII.GetString($bytes, $pos, 4)
    $len = [BitConverter]::ToInt32($bytes, $pos + 4)
    if ($id -eq 'fmt ') { $fmt = New-Object byte[] 16; [Array]::Copy($bytes, $pos + 8, $fmt, 0, 16) }
    if ($id -eq 'data') {
      $len = [Math]::Min($len, $bytes.Length - $pos - 8)
      $data = New-Object byte[] $len; [Array]::Copy($bytes, $pos + 8, $data, 0, $len)
      return @{ fmt = $fmt; data = $data }
    }
    $pos += 8 + $len + ($len % 2)
  }
  throw 'Không đọc được dữ liệu WAV'
}

Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$list = $ser.DeserializeObject([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'scripts.json'), $u))
$outDir = Join-Path $Root 'audio'
New-Item -ItemType Directory -Force $outDir | Out-Null
$total = 0; $secs = 0.0
foreach ($s in $list) {
  $ms = New-Object System.IO.MemoryStream
  $fmt = $null
  foreach ($line in $s['lines']) {
    $who = [string]$line['w']
    $v = if ($who -eq '男') { $voices['nam'] } elseif ($who -eq '女') { $voices['nu'] } else { $voices['dan'] }
    $pcm = Get-Pcm ([string]$line['t']) $v
    if (-not $fmt) {
      $fmt = $pcm.fmt
      $byteRate = [BitConverter]::ToInt32($fmt, 8); $align = [BitConverter]::ToInt16($fmt, 12)
      $lead = New-Object byte[] ([int]($byteRate * 0.4 / $align) * $align); $ms.Write($lead, 0, $lead.Length)
    } elseif ([BitConverter]::ToString($fmt) -ne [BitConverter]::ToString($pcm.fmt)) { throw "Định dạng âm thanh khác nhau giữa các giọng" }
    $ms.Write($pcm.data, 0, $pcm.data.Length)
    # Nghỉ giữa các lượt nói như trong băng đề thi
    $gap = New-Object byte[] ([int]($byteRate * 0.8 / $align) * $align); $ms.Write($gap, 0, $gap.Length)
  }
  $data = $ms.ToArray()
  $file = Join-Path $outDir ($s['k'] + '.wav')
  $fs = [IO.File]::Create($file); $bw = New-Object IO.BinaryWriter($fs)
  $bw.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $bw.Write([int](36 + $data.Length)); $bw.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
  $bw.Write([Text.Encoding]::ASCII.GetBytes('fmt ')); $bw.Write([int]16); $bw.Write($fmt)
  $bw.Write([Text.Encoding]::ASCII.GetBytes('data')); $bw.Write([int]$data.Length); $bw.Write($data)
  $bw.Close()
  $total += $data.Length + 44; $secs += $data.Length / $byteRate
}
$sr = [BitConverter]::ToInt32($fmt, 4); $bits = [BitConverter]::ToInt16($fmt, 14); $ch = [BitConverter]::ToInt16($fmt, 2)
"Đã thu $($list.Count) file, tổng {0:N0} bytes, {1:N0} giây âm thanh ({2} Hz, {3}-bit, {4} kênh)" -f $total, $secs, $sr, $bits, $ch

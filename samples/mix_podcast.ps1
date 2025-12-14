# Podcast Audio Mixer for The Right Path
# Mixes intro music, voice content, and outro with crossfades

$ffmpeg = "C:\Users\MarieLexisDad\Video Test\ffmpeg.exe"
$theme = "C:\Users\MarieLexisDad\Downloads\03 - THE RIGHT PATH IS NOW (1).mp3"
$voice = "C:\Users\MarieLexisDad\Downloads\PlayAI_Podcast.wav"
$output = "C:\Users\MarieLexisDad\Downloads\TheRightPath_Episode_Mixed.mp3"

# Step 1: Get voice file duration
Write-Host "Checking voice file duration..."
$voiceInfo = & $ffmpeg -i $voice 2>&1 | Select-String "Duration"
Write-Host $voiceInfo

# Step 2: Get theme song duration
Write-Host "Checking theme song duration..."
$themeInfo = & $ffmpeg -i $theme 2>&1 | Select-String "Duration"
Write-Host $themeInfo

# Step 3: Create the complex filter for mixing
# - Intro: first 52 seconds of theme, fade out last 5 seconds to 30%
# - Voice starts at 49 seconds (3 second overlap with faded intro)
# - Outro: full theme song starts 2 seconds before voice ends, at 25% volume initially

Write-Host ""
Write-Host "Creating mixed podcast with crossfades..."
Write-Host "- Intro: 52s of theme song, fading to 30% in last 5s"
Write-Host "- Voice: starts at 49s mark (3s overlap with intro)"
Write-Host "- Outro: starts 2s before voice ends at 25% volume, then full"

# Complex filter:
# [0] = theme song
# [1] = voice
# 1. Extract intro (0-52s) with fade out on last 5 seconds
# 2. Start voice at 49s (adelay=49000)
# 3. Mix intro + voice for first part
# 4. For outro: voice ends, fade in theme at end

$filter = @"
[0:a]atrim=0:52,afade=t=out:st=47:d=5:curve=exp,volume=1[intro];
[1:a]adelay=49000|49000[voice_delayed];
[0:a]volume=0.25[outro_quiet];
[intro][voice_delayed]amix=inputs=2:duration=longest[part1];
[part1][outro_quiet]amix=inputs=2:duration=longest[final]
"@

# Simplified approach: Create intermediate files
Write-Host ""
Write-Host "Step 1: Creating intro with fade..."
& $ffmpeg -y -i $theme -af "atrim=0:52,afade=t=out:st=47:d=5" -ar 44100 "$env:TEMP\intro.wav"

Write-Host "Step 2: Normalizing voice file..."
& $ffmpeg -y -i $voice -ar 44100 "$env:TEMP\voice.wav"

Write-Host "Step 3: Creating quieter outro for crossfade..."
& $ffmpeg -y -i $theme -af "volume=0.25" -ar 44100 "$env:TEMP\outro_quiet.wav"

# Get voice duration for outro timing
$probe = & $ffmpeg -i "$env:TEMP\voice.wav" 2>&1 | Select-String "Duration"
Write-Host "Voice duration: $probe"

Write-Host ""
Write-Host "Step 4: Mixing intro with voice (voice starts at 49s)..."
& $ffmpeg -y -i "$env:TEMP\intro.wav" -i "$env:TEMP\voice.wav" -filter_complex "[1:a]adelay=49000|49000[v];[0:a][v]amix=inputs=2:duration=longest:normalize=0" -ar 44100 "$env:TEMP\intro_voice.wav"

Write-Host "Step 5: Getting combined duration for outro placement..."
$combinedInfo = & $ffmpeg -i "$env:TEMP\intro_voice.wav" 2>&1 | Select-String "Duration"
Write-Host "Combined duration: $combinedInfo"

Write-Host ""
Write-Host "Step 6: Final mix with outro (full theme at the end)..."
# Simpler approach: concatenate intro_voice with full theme song
& $ffmpeg -y -i "$env:TEMP\intro_voice.wav" -i $theme -filter_complex "[0:a][1:a]concat=n=2:v=0:a=1" $output

Write-Host ""
Write-Host "Done! Output saved to: $output"
Write-Host ""

# Cleanup temp files
Remove-Item "$env:TEMP\intro.wav" -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\voice.wav" -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\outro_quiet.wav" -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\intro_voice.wav" -ErrorAction SilentlyContinue

# The scripts of the repository: the 1 list that the tools read (check, test, deploy, release, docs check,
# publish check, session start). A new script: 1 line here (and its folder, its test file).
# Name = the folder and the main file (<Name>\<Name>.lua); Test / Result = in tests\; Tag = the GitHub Release tag
# prefix (+ X.Y); Released = $false until its first release: then the publish check wants @noindex in each of its
# .lua files and no README part about it (inside <!-- --> is hidden), so a push does not publish it on ReaPack.
# Uses = the shared files (from the repository root) that the script needs next to it: deploy.ps1 and release.ps1 copy
# them into its folder; its @provides names them for ReaPack ("[nomain] ../Tab Viewer/Guitar Pro.lua > Guitar Pro.lua").
@{
  Scripts = @(
    @{ Name = "Chart Cue";    Test = "run.lua";         Result = "result.txt";             Tag = "v";             Released = $true }
    @{ Name = "Segue";        Test = "segue.lua";       Result = "result_segue.txt";       Tag = "segue-v";       Released = $true }
    @{ Name = "MIDI Pilot";   Test = "midipilot.lua";   Result = "result_midipilot.txt";   Tag = "midipilot-v";   Released = $true }
    @{ Name = "FX Link";      Test = "fxlink.lua";      Result = "result_fxlink.txt";      Tag = "fxlink-v";      Released = $true }
    @{ Name = "Session Prep"; Test = "sessionprep.lua"; Result = "result_sessionprep.txt"; Tag = "sessionprep-v"; Released = $true }
    @{ Name = "SFX Drop";     Test = "sfxdrop.lua";     Result = "result_sfxdrop.txt";     Tag = "sfxdrop-v";     Released = $false }
    @{ Name = "Mono Merge";   Test = "monomerge.lua";   Result = "result_monomerge.txt";   Tag = "monomerge-v";   Released = $true }
    @{ Name = "Note Detective"; Test = "notedetective.lua"; Result = "result_notedetective.txt"; Tag = "notedetective-v"; Released = $false; Uses = @("Tab Viewer\Guitar Pro.lua", "Tab Viewer\Tempo.lua") }
    @{ Name = "Tab Viewer";   Test = "tabviewer.lua";   Result = "result_tabviewer.txt";   Tag = "tabviewer-v";   Released = $false; Uses = @("Tab Viewer\Guitar Pro.lua") }
  )
}

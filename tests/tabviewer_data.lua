-- @noindex
-- Made-up test data for tests\tabviewer.lua (no real song): a small Guitar Pro 7/8 score (GPIF), deflate samples
-- (fixed, stored, dynamic blocks) and 2 small .gp files (zip), made once with Python's zlib and zipfile.
local function unhex(h) return (h:gsub("%s", ""):gsub("%x%x", function(c) return string.char(tonumber(c, 16)) end)) end
local GPIF = [==[<GPIF>
<MasterTrack><Automations>
<Automation><Type>Tempo</Type><Linear>false</Linear><Bar>0</Bar><Position>0</Position><Visible>true</Visible><Value>120 2</Value></Automation>
<Automation><Type>DSPParam_00</Type><Bar>0</Bar><Value>0.5</Value></Automation>
<Automation><Type>Tempo</Type><Linear>false</Linear><Bar>2</Bar><Position>0</Position><Visible>true</Visible><Value>140 2</Value></Automation>
</Automations></MasterTrack>
<Tracks>
<Track id="0"><Name><![CDATA[Bass]]></Name><InstrumentSet><Name>Electric Bass</Name><Type>electricBass</Type><LineCount>5</LineCount></InstrumentSet><Staves><Staff><Properties><Property name="CapoFret"><Fret>0</Fret></Property><Property name="Tuning">
<Pitches>28 33 38 43</Pitches></Property></Properties></Staff></Staves></Track>
<Track id="1"><Name><![CDATA[Rhythm Guitar]]></Name><InstrumentSet><Name>Electric Guitar</Name><Type>electricGuitar</Type></InstrumentSet><Staves><Staff><Properties><Property name="CapoFret"><Fret>2</Fret></Property><Property name="Tuning"><Pitches>38 45 50 55 59 64</Pitches></Property></Properties></Staff></Staves></Track>
<Track id="2"><Name><![CDATA[Drums]]></Name><InstrumentSet><Name>Drums</Name><Type>drumKit</Type></InstrumentSet><Staves><Staff><Properties><Property name="Tuning"><Pitches>0 0 0 0 0 0</Pitches></Property></Properties></Staff></Staves></Track>
<Track id="3"><Name><![CDATA[Keys]]></Name><InstrumentSet><Name>Electric Piano</Name><Type>electricPiano</Type></InstrumentSet><Staves><Staff><Properties><Property name="Tuning"><Pitches>35 40 45 50 55 59 64</Pitches></Property></Properties></Staff></Staves></Track>
</Tracks>
<MasterBars>
<MasterBar><Time>4/4</Time><Bars>0 -1 -1 -1</Bars></MasterBar>
<MasterBar><Time>4/4</Time><Bars>1 -1 -1 -1</Bars><Repeat start="true" end="true" count="2" /></MasterBar>
<MasterBar><Time>3/4</Time><Bars>2 -1 -1 -1</Bars></MasterBar>
</MasterBars>
<Bars><Bar id="0"><Voices>0 -1 -1 -1</Voices></Bar><Bar id="1"><Voices>1 -1 -1 -1</Voices></Bar><Bar id="2"><Voices>2 -1 -1 -1</Voices></Bar></Bars>
<Voices><Voice id="0"><Beats>0 1</Beats></Voice><Voice id="1"><Beats>6 2 3</Beats></Voice><Voice id="2"><Beats>4</Beats></Voice></Voices>
<Beats>
<Beat id="0"><Rhythm ref="0" /><Notes>0</Notes></Beat>
<Beat id="1"><Rhythm ref="0" /><Notes>1</Notes></Beat>
<Beat id="2"><Rhythm ref="1" /><Notes>2</Notes></Beat>
<Beat id="3"><Rhythm ref="0" /><Notes>3</Notes></Beat>
<Beat id="4"><Rhythm ref="2" /><Notes>4</Notes></Beat>
<Beat id="6"><GraceNotes>BeforeBeat</GraceNotes><Rhythm ref="0" /><Notes>4</Notes></Beat>
</Beats>
<Notes>
<Note id="0"><Properties><Property name="Fret"><Fret>3</Fret></Property><Property name="Midi"><Number>36</Number></Property><Property name="String"><String>1</String></Property></Properties></Note>
<Note id="1"><Tie origin="false" destination="true" /><Properties><Property name="Fret"><Fret>3</Fret></Property><Property name="Midi"><Number>36</Number></Property><Property name="String"><String>1</String></Property></Properties></Note>
<Note id="2"><Properties><Property name="Fret"><Fret>2</Fret></Property><Property name="Midi"><Number>40</Number></Property><Property name="String"><String>2</String></Property></Properties></Note>
<Note id="3"><Properties><Property name="Fret"><Fret>5</Fret></Property><Property name="Midi"><Number>43</Number></Property><Property name="Muted"><Enable /></Property><Property name="String"><String>2</String></Property></Properties></Note>
<Note id="4"><Properties><Property name="Fret"><Fret>0</Fret></Property><Property name="Midi"><Number>43</Number></Property><Property name="String"><String>3</String></Property></Properties></Note>
</Notes>
<Rhythms><Rhythm id="0"><NoteValue>Half</NoteValue></Rhythm><Rhythm id="1"><NoteValue>Quarter</NoteValue><AugmentationDot count="1" /></Rhythm>
<Rhythm id="2"><NoteValue>Eighth</NoteValue><PrimaryTuplet num="3" den="2" /></Rhythm></Rhythms>
</GPIF>]==]
local INF_TEXT = string.rep("<Note>bass</Note>", 40)
local INF_FIXED = unhex([[
f348cdc9c9d751484a2c2e5628c849ac4c2d520400
]])
local INF_STORED = unhex([[
01a80257fd3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c
2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e62617373
3c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173
733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e6261
73733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e62
6173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e
626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f7465
3e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74
653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f
74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e
6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c
4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e
3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f7465
3e3c4e6f74653e626173733c2f4e6f74653e3c4e6f74653e626173733c2f4e6f74653e
]])
local INF_DYNAMIC = unhex([[
dd575d6fda30147defaff078df9c380175928904a5edaaae152ba82f5535b960c01a4990e34ce2dfefda8e430205d296be4c
adf0d739d7f79c24d709bd1ede5c4567f48e658acbb164933f11ede52a8d99126992c1d26614d1f17ac5a3318f5729c5a64f
7f8a843319cdd832e3141723da871f8f62ddd0619a09c38689b24f1f45265e963c5232079e1bd147b6cc79e4130f11983503
8a2b19bc92ce60341c32c9e2df9ee792aa6e6f8378dfda4de33594473e202fdc2f0f57cda7b87a5dcea86933d74162da6d79
ad88deb318e27c79ba18f4c6bda73ecbb2e767e0dae99b248324629ea8115705f672c9274a8a09d25807348279b16217361e
5ca479a2a2b6b5c00e28de0a3d52ec2fcf4c3b9b8131325d71a9849e2afa6b94c056ddd6055ba557922bc85d37da3ad38283
05708732ce1391cc5ba07d28d4640141c9390a02149ca330005e31598d80ab19e0222becb2c435538d97fe8e970f8bb55ac4
e83a178ac9a6a65af4abb6ba256bece90c24cd0d2cfdd3ceb551db436df8fd8e3ae1895c243b2e0e40e3b15bd2606a9e4d61
e656a88f9bb5a3dc43e5df8934073b9a6ff9baf15338142c495fbd5f8a95933b10b411d4a0135e7e5c96265bb1a034d606a0
4b80ba10c336a6470dc2435f7dfb6faae9a6e269ca71babf437fe02bce14cae02953dd96aebe2dc493a9eb4e74e5d2b728c2
47b60ab6b6228733c535d91600bf65897e4cc584d7f51653c531e2c0fe06ec1f05930d98ec05e32229376bda32b13ed8a5f3
d2b24cb7a057717e89eb20828203485222c31d944bebac40d8b64ca428b592cff4585f9ffb5469cbe0c1301d1bb04af30fd0
fcfd34b245f32b34b29f161cd82dd84f0bb768a4420bf7d33a40bb86678a5b409fcf52c9f52ac595e9bd09ed46c6ce753b6f
dbd2fd03c5a37ace04c7cf993b3115ba1ae6f10b9751d081446cf7006704b5ced427dbd117afe8ed2f453afdaa0a7d338c05
47a9147391745be695ad85a63c532231ef53ae08e0ff412e697ed1c85b5584de7b549077a8089aab68bf5945d044c55daef8
14489709833774732c7caae2b0b962ef73146fab089aabc0ae76d8b2b3a93fe59708acdbcf9a1f6c39b378f79963a1358a5f
a3fccae1d0e6b2c6eae573fdbe639edf41aadc016e4bb60b79568d496a312fc57ca116b59043296226d7e37cb5e40a2579ac
6f43a81349f95ee032c54e262837dfc9ff00
]])
local GP_FILE = unhex([[
504b03041400000008002898775d00000000020000000000000008000000436f6e74656e742f0300504b0304140000000800
2898775de12f1d280e000000b400000018000000436f6e74656e742f42696e6172795374796c6573686565746360cc4d4c49
55282d60183a0c00504b03041400000008002898775dde093b44680300002e0f000012000000436f6e74656e742f73636f72
652e67706966dd57516fda30107ee75778bc6f4e9c803ac94482d27655d78a15d497aa9a5c30608d24c87126f1ef77b6e390
4081ac652f13283edbf79deffb929c1d7a33babd8e5af49e658acb8964d35f11ede72a8d99126992c1d4b617d1c966cda309
8fd729c5c6a6df45c2998ce66c95718a8b1e1dc0c5a35837749466c2a061a0b4e993c8c4eb8a474ae680733dfac456398f7c
e22102a3a64371258337d2198e47232659fcd3f35c52d5e56d10ef4ba769bc86f4c807e88587e9e1aaf81457ef4b8b9a3673
0612b35edb6b47f481c510e7d3f3e5b03fe93f0f5896bdbc00d60edf26192411f3448db92a7caf567caaa49822edeb1c0d61
5eccd889ad0697699ea8a86325b01d8a77428f15fbcd33d3cee7208c4cd75c2aa1870a7b831258aad7be64ebf45a7205b9eb
464b675a50b070dc834cf244248b36701f09355d4250728182000517280c00570c5623e06a06b8c80abb2c714d54a3a5bfa7
e5e372a39631bac98562b2a9a8d6fb4d59dd9415f67c0292e60296fa69e53aa8e3a10e5cbfa26e782615c99e8a43e078ea91
343e35cd66307227d4c7c5da63eea1f27726cec11ee73bbe69fc168e044bd2379f9762e6ec0a041d0435e88cb71f97a5c956
2c288db50ef012c02ec4b08cb1a8f1f0d067dffe4d35dd563c0d390df7f7e08f7ccd994219bc65aad7d6d5b78d783273e654
572efd88227c62a9606729723c535ca36d1de05a96e8a7544c799d6f31546c23ced9df3afb279dc9d6991c74c645526ed4b4
656203904be7a56919b38057fdfcd2af8b080a8e7892d233dcf37269b50a0fdb968914a556f2b9eeebfbf3902a2d19bc18c6
b001ab30ff08cc3f0c233b30bf02238761c191d582c3b07007462ab0f030ac0bb01b78a7b87518f0792ab99ea5b8327c30a1
fdc8d8a96ec76d5baa7fa47854f799e0f43e732f664257c33c7ee5320aba9088358f60c650eb4c7db286be798575b814e9f4
ab2cf4c330111ca5522c44d26b9b235b1bcd78a64462ce53ae08e0ff812e697ed31a1c0eea2c42ef3d2cc83b5804cd5974fe
9a45d084c57daef80c4057098313bad916fe29e3b039e306a7e2f730de65113467815dedb065675b7fca2f1198b79f35dfd8
6a6efddd678e75ad41fc1ae4470e9b369735543f5fe8f38e797f87a9721bb82dd92e64ab1a93d4625e89c5522d6b214752c4
4c6e26f97ac5154af2583f86502792f25ce032c58e263037dfc97f00504b010214001400000008002898775d000000000200
000000000000080000000000000000001000fd4100000000436f6e74656e742f504b010214001400000008002898775de12f
1d280e000000b4000000180000000000000000000000800128000000436f6e74656e742f42696e6172795374796c65736865
6574504b010214001400000008002898775dde093b44680300002e0f000012000000000000000000000080016c000000436f
6e74656e742f73636f72652e67706966504b05060000000003000300bc000000040400000000
]])
local GP_NOSCORE = unhex([[
504b03041400000008002898775d44f530240f0000000d00000011000000436f6e74656e742f6f746865722e747874cbcb57
284ece2f4a55c8482d4a0500504b010214001400000008002898775d44f530240f0000000d00000011000000000000000000
0000800100000000436f6e74656e742f6f746865722e747874504b050600000000010001003f0000003e0000000000
]])
return { GPIF = GPIF, INF_TEXT = INF_TEXT, INF_FIXED = INF_FIXED, INF_STORED = INF_STORED, INF_DYNAMIC = INF_DYNAMIC,
  GP_FILE = GP_FILE, GP_NOSCORE = GP_NOSCORE }
